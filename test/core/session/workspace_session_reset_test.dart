import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/core/session/workspace_session_guard.dart';
import 'package:school_app/core/storage/secure_storage_service.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/domain/repositories/admin_repository.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/features/admin_workspace/presentation/screens/admin_screens.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/domain/entities/login_result.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';
import 'package:school_app/features/teacher_workspace/domain/repositories/teacher_workspace_repository.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_bloc.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_event.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_state.dart';

void main() {
  group('workspaceStateMustReset', () {
    test('resets when the session ends or the account changes directly', () {
      final a = AuthAuthenticated(profile: _profile(1, 'school-a'));
      final b = AuthAuthenticated(profile: _profile(2, 'school-b'));
      const out = AuthUnauthenticated();

      expect(workspaceStateMustReset(a, out), isTrue);
      expect(workspaceStateMustReset(a, const AuthLoading()), isTrue);
      expect(workspaceStateMustReset(a, b), isTrue);
      expect(
        workspaceStateMustReset(
          a,
          AuthAuthenticated(profile: _profile(1, 'school-b')),
        ),
        isTrue,
        reason: 'same user id in another school is another account',
      );
    });

    test('does not reset on unrelated updates or when a session starts', () {
      final a = AuthAuthenticated(profile: _profile(1, 'school-a'));
      final refreshed = AuthAuthenticated(
        profile: _profile(1, 'school-a', name: 'Renamed'),
      );

      expect(workspaceStateMustReset(a, refreshed), isFalse);
      expect(workspaceStateMustReset(const AuthUnauthenticated(), a), isFalse);
      expect(workspaceStateMustReset(const AuthInitial(), a), isFalse);
      expect(
        workspaceStateMustReset(const AuthUnauthenticated(), const AuthLoading()),
        isFalse,
      );
    });
  });

  group('AdminWorkspaceCubit', () {
    late _AdminRepository repository;
    late AdminWorkspaceCubit cubit;

    setUp(() {
      repository = _AdminRepository();
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
    });

    test('reset restores every field to its initial value', () async {
      await cubit.load('/school/staff');
      await cubit.loadSetup();
      await cubit.loadPermissions();
      repository.failPermissions = true;
      await cubit.loadPermissions();
      expect(cubit.state.records, isNotEmpty);
      expect(cubit.state.steps, isNotEmpty);
      expect(cubit.state.permissions, isNotEmpty);
      expect(cubit.state.nextCursor, 'cursor-1');
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.error, isNotNull);

      cubit.reset();

      _expectInitial(cubit.state);
      final listCalls = repository.calls('listPage');
      await cubit.loadMore('/school/staff');
      expect(repository.calls('listPage'), listCalls, reason: 'no cursor left');
    });

    test('reset makes no API call', () async {
      await cubit.load('/school/staff');
      final before = repository.totalCalls;

      cubit.reset();

      expect(repository.totalCalls, before);
    });

    test('reset while a request is loading clears the loading flag', () async {
      repository.hold = true;
      unawaited(cubit.loadSetup());
      await pumpEventQueue();
      expect(cubit.state.loading, isTrue);

      cubit.reset();

      _expectInitial(cubit.state);
    });

    final operations = <String, Future<void> Function(AdminWorkspaceCubit)>{
      'load': (c) => c.load('/school/staff'),
      'loadSetup': (c) => c.loadSetup(),
      'loadPermissions': (c) => c.loadPermissions(),
      'loadProfile': (c) => c.loadProfile('/school/profile'),
    };
    final gates = <String, String>{
      'load': 'listPage',
      'loadSetup': 'setup',
      'loadPermissions': 'permissions',
      'loadProfile': 'get',
    };

    for (final entry in operations.entries) {
      for (final failure in [false, true]) {
        test(
          'a ${entry.key} started before reset cannot touch the new session '
          '(${failure ? 'error' : 'success'})',
          () async {
            repository.hold = true;
            unawaited(entry.value(cubit));
            await pumpEventQueue();
            cubit.reset();
            final emitted = <AdminWorkspaceState>[];
            final subscription = cubit.stream.listen(emitted.add);
            addTearDown(subscription.cancel);

            repository.finish(gates[entry.key]!, 0, fail: failure);
            await pumpEventQueue();

            expect(emitted, isEmpty);
            _expectInitial(cubit.state);
          },
        );
      }
    }

    test('loadMore started before reset cannot append to the new session', () async {
      await cubit.load('/school/staff');
      repository.hold = true;
      unawaited(cubit.loadMore('/school/staff'));
      await pumpEventQueue();
      cubit.reset();
      final emitted = <AdminWorkspaceState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      repository.finish('listPage', 0);
      await pumpEventQueue();

      expect(emitted, isEmpty);
      _expectInitial(cubit.state);
    });

    test('a mutation finishing after reset is ignored and does not refresh', () async {
      repository.hold = true;
      unawaited(cubit.send('POST', '/school/staff', refreshPath: '/school/staff'));
      await pumpEventQueue();
      cubit.reset();

      repository.finish('send', 0);
      await pumpEventQueue();

      _expectInitial(cubit.state);
      expect(repository.calls('listPage'), 0, reason: 'no refresh of old data');
    });

    test('a failed mutation reports false after reset without an error', () async {
      repository.hold = true;
      final result = cubit.submit(() => repository.delete('/x'));
      await pumpEventQueue();
      cubit.reset();

      repository.finish('delete', 0, fail: true);

      expect(await result, isFalse);
      _expectInitial(cubit.state);
    });

    for (final failure in [false, true]) {
      test(
        'an old ${failure ? 'error' : 'response'} cannot clear or fill a newer '
        'request',
        () async {
          repository.hold = true;
          unawaited(cubit.loadSetup());
          await pumpEventQueue();
          cubit.reset();
          unawaited(cubit.loadSetup());
          await pumpEventQueue();
          expect(cubit.state.loading, isTrue);

          repository.finish('setup', 0, fail: failure);
          await pumpEventQueue();
          expect(cubit.state.loading, isTrue, reason: 'new request still runs');
          expect(cubit.state.steps, isEmpty, reason: 'old account data dropped');
          expect(cubit.state.error, isNull, reason: 'old error dropped');

          repository.finish(
            'setup',
            1,
            steps: const [SetupStep(key: 'b', done: true)],
          );
          await pumpEventQueue();
          expect(cubit.state.loading, isFalse);
          expect(cubit.state.steps.map((s) => s.key), ['b']);
        },
      );
    }

    testWidgets('a failed account-B load cannot leave account-A setup visible', (
      tester,
    ) async {
      repository.steps = const [SetupStep(key: 'profile', done: true)];
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const Scaffold(body: AdminSetupScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);

      cubit.reset();
      repository.failSetup = true;
      await tester.runAsync(() => cubit.loadSetup());
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsNothing);
      expect(find.text('Offline'), findsOneWidget);
    });
  });

  group('TeacherWorkspaceBloc', () {
    late _TeacherRepository repository;
    late TeacherWorkspaceBloc bloc;

    setUp(() {
      repository = _TeacherRepository();
      bloc = TeacherWorkspaceBloc(repository: repository);
      addTearDown(bloc.close);
    });

    test('reset restores every field to its initial value', () async {
      bloc
        ..add(const TeacherSectionsRequested())
        ..add(const TeacherSubjectsRequested());
      await pumpEventQueue();
      repository.failSubjects = true;
      bloc.add(const TeacherSubjectsRequested());
      await pumpEventQueue();
      expect(bloc.state.sections, isNotEmpty);
      expect(bloc.state.subjectsError, isNotNull);

      bloc.add(const TeacherWorkspaceReset());
      await pumpEventQueue();

      expect(bloc.state, const TeacherWorkspaceState());
    });

    for (final failure in [false, true]) {
      for (final subjects in [false, true]) {
        test(
          'a ${subjects ? 'subjects' : 'sections'} request started before reset '
          'cannot touch the new session (${failure ? 'error' : 'success'})',
          () async {
            repository.hold = true;
            bloc.add(
              subjects
                  ? const TeacherSubjectsRequested()
                  : const TeacherSectionsRequested(),
            );
            await pumpEventQueue();
            bloc.add(const TeacherWorkspaceReset());
            await pumpEventQueue();
            final emitted = <TeacherWorkspaceState>[];
            final subscription = bloc.stream.listen(emitted.add);
            addTearDown(subscription.cancel);

            repository.finish(subjects ? 'subjects' : 'sections', 0, fail: failure);
            await pumpEventQueue();

            expect(emitted, isEmpty);
            expect(bloc.state, const TeacherWorkspaceState());
          },
        );
      }
    }

    for (final failure in [false, true]) {
      for (final responseFirst in [false, true]) {
        test(
          'reset() invalidates an in-flight request before its own event is '
          'handled (${failure ? 'error' : 'success'}, '
          '${responseFirst ? 'response completes first' : 'reset called first'})',
          () async {
            repository.hold = true;
            bloc.add(const TeacherSectionsRequested());
            await pumpEventQueue();
            expect(bloc.state.sectionsStatus, TeacherDataStatus.loading);
            final emitted = <TeacherWorkspaceState>[];
            final subscription = bloc.stream.listen(emitted.add);
            addTearDown(subscription.cancel);

            // No await between the two calls: the response is already queued
            // to resume the handler when reset() runs, ahead of the queued
            // TeacherWorkspaceReset event.
            if (responseFirst) {
              repository.finish('sections', 0, fail: failure);
              bloc.reset();
            } else {
              bloc.reset();
              repository.finish('sections', 0, fail: failure);
            }
            await pumpEventQueue();

            expect(
              emitted,
              [const TeacherWorkspaceState()],
              reason: 'only the wipe; the old response must emit nothing',
            );
          },
        );
      }
    }

    for (final failure in [false, true]) {
      test(
        'an old ${failure ? 'error' : 'response'} cannot clear or fill a newer '
        'request',
        () async {
          repository.hold = true;
          bloc.add(const TeacherSectionsRequested());
          await pumpEventQueue();
          bloc.add(const TeacherWorkspaceReset());
          bloc.add(const TeacherSectionsRequested());
          await pumpEventQueue();
          expect(bloc.state.sectionsStatus, TeacherDataStatus.loading);

          repository.finish('sections', 0, fail: failure);
          await pumpEventQueue();
          expect(bloc.state.sectionsStatus, TeacherDataStatus.loading);
          expect(bloc.state.sections, isEmpty);
          expect(bloc.state.sectionsError, isNull);

          repository.finish('sections', 1, sections: const []);
          await pumpEventQueue();
          expect(bloc.state.sectionsStatus, TeacherDataStatus.success);
        },
      );
    }
  });

  group('AuthBloc account switching', () {
    // The guard resets on A to B directly, but the app cannot produce that
    // today: every handler that can emit AuthAuthenticated first emits
    // AuthLoading or AuthSessionRestoring. These tests pin that property so
    // a future handler that skips the intermediate state is noticed.
    test('login as B while A is signed in passes through a non-authenticated state', () async {
      final repository = _AuthRepository();
      final bloc = AuthBloc(repository: repository, storage: _Storage());
      addTearDown(bloc.close);
      bloc.add(const AuthAppStarted());
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
      final seen = <AuthState>[];
      final subscription = bloc.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      repository.profile = _profile(2, 'school-b');
      bloc.add(
        const AuthLoginRequested(
          school: 'school-b',
          identifier: 'b@example.test',
          password: 'not-a-real-password',
        ),
      );
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);

      expect(_noDirectAccountSwitch(seen), isTrue, reason: '$seen');
      expect(seen.first, isNot(isA<AuthAuthenticated>()));
    });

    test('restoring the session as B while A is signed in passes through a non-authenticated state', () async {
      final repository = _AuthRepository();
      final bloc = AuthBloc(repository: repository, storage: _Storage());
      addTearDown(bloc.close);
      bloc.add(const AuthAppStarted());
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
      final seen = <AuthState>[];
      final subscription = bloc.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      repository.profile = _profile(2, 'school-b');
      bloc.add(const AuthAppStarted());
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);

      expect(_noDirectAccountSwitch(seen), isTrue, reason: '$seen');
      expect(seen.first, isA<AuthSessionRestoring>());
    });
  });

  group('WorkspaceSessionGuard wiring', () {
    late _AuthRepository authRepository;
    late _ScriptedAuthBloc auth;
    late TeacherWorkspaceBloc teacher;
    late AdminWorkspaceCubit admin;

    Future<void> pumpGuard(WidgetTester tester) async {
      // Created in the real zone so their streams run on the real event loop.
      await tester.runAsync(() async {
        authRepository = _AuthRepository();
        auth = _ScriptedAuthBloc(authRepository);
        teacher = TeacherWorkspaceBloc(repository: _TeacherRepository());
        admin = AdminWorkspaceCubit(_AdminRepository());
      });
      addTearDown(auth.close);
      addTearDown(teacher.close);
      addTearDown(admin.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider.value(value: teacher),
            BlocProvider.value(value: admin),
          ],
          child: const WorkspaceSessionGuard(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(),
            ),
          ),
        ),
      );
    }

    // Bloc work needs the real event loop, which testWidgets replaces with a
    // fake clock; run it through runAsync and pump the widget tree after.
    Future<void> settle(WidgetTester tester, Future<void> Function() work) async {
      await tester.runAsync(() async {
        await work();
        await pumpEventQueue();
      });
      await tester.pump();
    }

    Future<void> signInAndLoad(WidgetTester tester) async {
      await settle(tester, () async {
        auth.add(const AuthAppStarted());
        await auth.stream.firstWhere((s) => s is AuthAuthenticated);
        teacher
          ..add(const TeacherSectionsRequested())
          ..add(const TeacherSubjectsRequested());
        await admin.load('/school/staff');
        await admin.loadSetup();
        await admin.loadPermissions();
      });
      expect(teacher.state.sections, isNotEmpty);
      expect(admin.state.steps, isNotEmpty);
    }

    void expectCleared() {
      expect(teacher.state, const TeacherWorkspaceState());
      _expectInitial(admin.state);
    }

    final endings = <String, void Function(_ScriptedAuthBloc)>{
      'logout': (a) => a.add(const AuthLogoutRequested()),
      'logout-all': (a) => a.add(const AuthLogoutAllRequested()),
      'AuthSessionEnded': (a) => a.add(const AuthSessionEnded('Signed out.')),
      'forced 401 / session expiry': (a) => a.add(const AuthForced401()),
    };
    for (final entry in endings.entries) {
      testWidgets('${entry.key} clears both workspaces', (tester) async {
        await pumpGuard(tester);
        await signInAndLoad(tester);

        await settle(tester, () async {
          entry.value(auth);
          await auth.stream.firstWhere((s) => s is AuthUnauthenticated);
        });

        expectCleared();
      });
    }

    testWidgets('account A to account B directly clears both workspaces', (
      tester,
    ) async {
      await pumpGuard(tester);
      await signInAndLoad(tester);

      await settle(tester, () async {
        auth.push(AuthAuthenticated(profile: _profile(2, 'school-b')));
      });

      expectCleared();
    });

    testWidgets('a profile refresh of the same account keeps the data', (
      tester,
    ) async {
      await pumpGuard(tester);
      await signInAndLoad(tester);

      await settle(tester, () async {
        auth.push(
          AuthAuthenticated(profile: _profile(1, 'school-a', name: 'Renamed')),
        );
      });

      expect(teacher.state.sections, isNotEmpty);
      expect(admin.state.steps, isNotEmpty);
    });

    testWidgets('data loaded for B after a switch is not wiped again', (
      tester,
    ) async {
      await pumpGuard(tester);
      await signInAndLoad(tester);
      await settle(tester, () async => auth.push(const AuthUnauthenticated()));
      expectCleared();

      await settle(tester, () async {
        auth.push(AuthAuthenticated(profile: _profile(2, 'school-b')));
        await admin.loadSetup();
      });

      expect(admin.state.steps, isNotEmpty, reason: 'starting B needs no reset');
    });
  });
}

/// True when no two consecutive states are signed in as different accounts.
bool _noDirectAccountSwitch(List<AuthState> states) {
  for (var i = 1; i < states.length; i++) {
    final before = workspaceSessionKey(states[i - 1]);
    final after = workspaceSessionKey(states[i]);
    if (before != null && after != null && before != after) return false;
  }
  return true;
}

void _expectInitial(AdminWorkspaceState state) {
  expect(state.loading, isFalse);
  expect(state.saving, isFalse);
  expect(state.error, isNull);
  expect(state.records, isEmpty);
  expect(state.steps, isEmpty);
  expect(state.permissions, isEmpty);
  expect(state.nextCursor, isNull);
  expect(state.hasMore, isFalse);
}

AccountProfile _profile(int id, String slug, {String name = 'Asha'}) =>
    AccountProfile(
      id: id,
      kind: 'school',
      name: name,
      email: 'user$id@example.test',
      userType: 'staff',
      school: SchoolInfo(name: slug, slug: slug, status: 'active'),
      abilities: const ['school.view', 'classes.view', 'subjects.view'],
      emailVerified: true,
      mfaEnabled: true,
      mfaRequired: false,
    );

/// Answers immediately, or (when [hold] is set) only when a test calls
/// [finish], so request races are deterministic.
mixin _Gates {
  bool hold = false;
  final Map<String, List<Completer<Object?>>> _pending = {};
  final Map<String, int> _counts = {};

  int calls(String operation) => _counts[operation] ?? 0;
  int get totalCalls => _counts.values.fold(0, (a, b) => a + b);

  Future<T> answer<T>(String operation, T Function() value) {
    _counts[operation] = calls(operation) + 1;
    if (!hold) return Future.value(value());
    final completer = Completer<Object?>();
    (_pending[operation] ??= []).add(completer);
    return completer.future.then((_) => value());
  }

  /// Completes the [index]-th held call of [operation].
  void completeHeld(String operation, int index, {required bool fail}) {
    final completer = _pending[operation]![index];
    if (fail) {
      completer.completeError(const NetworkFailure(message: 'Offline'));
    } else {
      completer.complete(null);
    }
  }
}

class _AdminRepository with _Gates implements AdminRepository {
  bool failPermissions = false;
  bool failSetup = false;
  List<SetupStep> steps = const [SetupStep(key: 'profile', done: true)];
  List<SetupStep>? _stepsOverride;

  void finish(String operation, int index, {bool fail = false, List<SetupStep>? steps}) {
    _stepsOverride = steps;
    completeHeld(operation, index, fail: fail);
  }

  @override
  Future<AdminPage> listPage(String path, {Map<String, dynamic>? query}) =>
      answer(
        'listPage',
        () => AdminPage(
          records: [AdminRecord.fromJson({'id': 'r-${query?['cursor']}'})],
          nextCursor: 'cursor-1',
          hasMore: true,
        ),
      );

  @override
  Future<AdminRecord> get(String path) =>
      answer('get', () => AdminRecord.fromJson({'id': 'profile'}));

  @override
  Future<List<SetupStep>> setup() {
    if (failSetup) {
      return Future.error(const NetworkFailure(message: 'Offline'));
    }
    return answer('setup', () => _stepsOverride ?? steps);
  }

  @override
  Future<List<PermissionGroup>> permissions() {
    if (failPermissions) {
      return Future.error(const NetworkFailure(message: 'Offline'));
    }
    return answer(
      'permissions',
      () => [
        PermissionGroup.fromJson({
          'module': 'classes',
          'permissions': [
            {'name': 'classes.view', 'action': 'view'},
          ],
        }),
      ],
    );
  }

  @override
  Future<AdminRecord> send(String method, String path, {JsonMap? body}) =>
      answer('send', () => AdminRecord.fromJson({'id': 'sent'}));

  @override
  Future<void> delete(String path) => answer('delete', () {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TeacherRepository with _Gates implements TeacherWorkspaceRepository {
  bool failSubjects = false;
  List<TeacherSection>? _sectionsOverride;

  void finish(String operation, int index, {bool fail = false, List<TeacherSection>? sections}) {
    _sectionsOverride = sections;
    completeHeld(operation, index, fail: fail);
  }

  @override
  Future<List<TeacherSection>> getMySections() =>
      answer('sections', () => _sectionsOverride ?? [_section]);

  @override
  Future<List<TeacherSubject>> getMySubjects() {
    if (failSubjects) {
      return Future.error(const NetworkFailure(message: 'Offline'));
    }
    return answer('subjects', () => [_subject]);
  }
}

const _subject = TeacherSubject(
  id: 'subject-a',
  code: 'MATH',
  name: 'Mathematics',
  sections: [],
);

final _section = TeacherSection(
  id: 'section-a',
  name: '8-A',
  room: 'Room 1',
  academicYear: const TeacherYearSummary(id: 'year', name: '2026-2027'),
  gradeLevel: const TeacherGradeLevelSummary(id: 'grade', name: 'Class 8'),
  isClassTeacher: true,
  subjects: const [],
);

class _AuthRepository implements AuthRepository {
  AccountProfile profile = _profile(1, 'school-a');

  @override
  Future<AccountProfile> getMe() async => profile;
  @override
  Future<LoginResult> login({
    required String school,
    required String identifier,
    required String password,
  }) async => const LoginResult(
    state: LoginState.complete,
    accessToken: 'token-b',
    tokenType: 'Bearer',
  );
  @override
  Future<void> logout() async {}
  @override
  Future<int> logoutAll() async => 1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorageService {
  @override
  Future<String?> getToken() async => 'token';
  @override
  Future<void> saveToken(String token, {DateTime? expiresAt}) async {}
  @override
  Future<void> saveSchoolSlug(String slug) async {}
  @override
  Future<void> clearAll() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An [AuthBloc] whose state a test can set directly, to model transitions
/// the real app cannot produce yet (such as signed in as A, then as B).
class _ScriptedAuthBloc extends AuthBloc {
  _ScriptedAuthBloc(AuthRepository repository)
    : super(repository: repository, storage: _Storage());

  void push(AuthState state) => emit(state);
}
