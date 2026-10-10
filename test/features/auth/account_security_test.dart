import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/core/storage/secure_storage_service.dart';
import 'package:school_app/features/auth/domain/entities/active_token.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_app/features/auth/presentation/bloc/account_security_cubit.dart';
import 'package:school_app/features/auth/presentation/bloc/active_sessions_cubit.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:school_app/features/auth/presentation/screens/account_security_screen.dart';

void main() {
  group('AccountSecurityCubit', () {
    late _FakeRepository repository;
    late AccountSecurityCubit cubit;

    setUp(() {
      repository = _FakeRepository();
      cubit = AccountSecurityCubit(repository);
      addTearDown(cubit.close);
    });

    test('forwards the password change and reports success', () async {
      await cubit.changePassword(
        currentPassword: 'old-pass',
        password: 'new-pass',
        passwordConfirmation: 'new-pass',
      );

      expect(cubit.state.status, AccountSecurityStatus.passwordChanged);
      expect(repository.passwordRequests, [('old-pass', 'new-pass', 'new-pass')]);
    });

    test('keeps the server field errors from a rejected change', () async {
      repository.changePasswordFailure = const ValidationFailure(
        message: 'The given data was invalid.',
        errors: {
          'current_password': ['The password is not correct.'],
        },
      );

      await cubit.changePassword(
        currentPassword: 'wrong',
        password: 'new-pass',
        passwordConfirmation: 'new-pass',
      );

      expect(cubit.state.status, AccountSecurityStatus.idle);
      expect(cubit.state.fieldErrors['current_password'], [
        'The password is not correct.',
      ]);
      expect(cubit.state.message, 'The given data was invalid.');
    });

    test('shows a general failure without ending the session', () async {
      repository.changePasswordFailure = const NetworkFailure(
        message: 'No connection.',
      );

      await cubit.changePassword(
        currentPassword: 'a',
        password: 'b',
        passwordConfirmation: 'b',
      );

      expect(cubit.state.status, AccountSecurityStatus.idle);
      expect(cubit.state.message, 'No connection.');
      expect(cubit.state.fieldErrors, isEmpty);
    });

    test('signing out everywhere reports success', () async {
      await cubit.signOutEverywhere();

      expect(cubit.state.status, AccountSecurityStatus.signedOutEverywhere);
      expect(repository.logoutAllCalls, 1);
    });

    test('a failed sign-out everywhere keeps the session and says why', () async {
      repository.logoutAllFailure = const NetworkFailure(message: 'Offline.');

      await cubit.signOutEverywhere();

      expect(cubit.state.status, AccountSecurityStatus.idle);
      expect(cubit.state.message, 'Offline.');
    });

    test('an unexpected error never leaves the cubit submitting', () async {
      repository.changePasswordFailure = null;
      repository.unexpectedError = StateError('boom');

      await cubit.changePassword(
        currentPassword: 'a',
        password: 'b',
        passwordConfirmation: 'b',
      );
      expect(cubit.state.status, AccountSecurityStatus.idle);
      expect(cubit.state.message, 'Something went wrong. Please try again.');

      await cubit.signOutEverywhere();
      expect(cubit.state.status, AccountSecurityStatus.idle);
      expect(cubit.state.message, contains('Could not confirm'));
    });

    test('nothing can start again after a request succeeded', () async {
      await cubit.signOutEverywhere();
      expect(cubit.state.completed, isTrue);

      await cubit.signOutEverywhere();
      await cubit.changePassword(
        currentPassword: 'a',
        password: 'b',
        passwordConfirmation: 'b',
      );

      expect(repository.logoutAllCalls, 1);
      expect(repository.passwordRequests, isEmpty);
      expect(cubit.state.status, AccountSecurityStatus.signedOutEverywhere);
    });

    test('ignores a second request while one is in flight', () async {
      final gate = Completer<void>();
      repository.changePasswordGate = gate.future;

      final first = cubit.changePassword(
        currentPassword: 'a',
        password: 'b',
        passwordConfirmation: 'b',
      );
      await cubit.changePassword(
        currentPassword: 'a',
        password: 'b',
        passwordConfirmation: 'b',
      );
      await cubit.signOutEverywhere();
      expect(cubit.state.submitting, isTrue);

      gate.complete();
      await first;

      expect(repository.passwordRequests, hasLength(1));
      expect(repository.logoutAllCalls, 0);
    });
  });

  group('AuthBloc session end', () {
    test('AuthSessionEnded clears local data and shows the message', () async {
      final storage = _MemoryStorage()
        ..token = 'token'
        ..school = 'springfield';
      final bloc = AuthBloc(repository: _FakeRepository(), storage: storage);
      addTearDown(bloc.close);
      final next = bloc.stream.firstWhere((s) => s is AuthUnauthenticated);

      bloc.add(const AuthSessionEnded('Signed out.'));

      expect((await next as AuthUnauthenticated).message, 'Signed out.');
      expect(storage.token, isNull);
      expect(storage.school, isNull);
    });
  });

  group('AccountSecurityScreen', () {
    late _FakeRepository repository;
    late _MemoryStorage storage;
    late AuthBloc authBloc;

    Future<void> pumpScreen(WidgetTester tester) async {
      repository = _FakeRepository();
      storage = _MemoryStorage()..token = 'token';
      authBloc = AuthBloc(repository: repository, storage: storage);
      final cubit = AccountSecurityCubit(repository);
      final sessions = ActiveSessionsCubit(repository);
      addTearDown(authBloc.close);
      addTearDown(cubit.close);
      addTearDown(sessions.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: authBloc),
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: sessions),
            ],
            child: const AccountSecurityScreen(),
          ),
        ),
      );
      // Settle the sessions spinner so pumpAndSettle can finish.
      await sessions.load();
      await tester.pump();
    }

    Future<void> fill(
      WidgetTester tester, {
      String current = 'old-pass',
      String password = 'new-pass',
      String confirmation = 'new-pass',
    }) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Current password'), current);
      await tester.enterText(find.widgetWithText(TextFormField, 'New password'), password);
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm new password'), confirmation);
    }

    testWidgets('requires every field and a matching confirmation', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();
      expect(find.text('Required'), findsNWidgets(2));
      expect(repository.passwordRequests, isEmpty);

      await fill(tester, confirmation: 'different');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(repository.passwordRequests, isEmpty);
    });

    testWidgets('shows the server message under the field it belongs to', (
      tester,
    ) async {
      await pumpScreen(tester);
      repository.changePasswordFailure = const ValidationFailure(
        message: 'The given data was invalid.',
        errors: {
          'current_password': ['The password is not correct.'],
          'password': ['The password must be at least 12 characters.'],
        },
      );

      await fill(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(find.text('The password is not correct.'), findsOneWidget);
      expect(
        find.text('The password must be at least 12 characters.'),
        findsOneWidget,
      );
      expect(storage.token, 'token', reason: 'the session must stay');
    });

    testWidgets('a successful change ends the local session', (tester) async {
      await pumpScreen(tester);
      final ended = authBloc.stream.firstWhere((s) => s is AuthUnauthenticated);

      await fill(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      final state = await ended as AuthUnauthenticated;
      expect(state.message, contains('password was changed'));
      expect(storage.token, isNull);
      expect(repository.passwordRequests, [('old-pass', 'new-pass', 'new-pass')]);
    });

    testWidgets('controls stay disabled once the change succeeded', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fill(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();
      await tester.pump();

      final change = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Change password'),
      );
      final signOut = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Sign out everywhere'),
      );
      expect(change.onPressed, isNull);
      expect(signOut.onPressed, isNull);
    });

    testWidgets('cancelling the sign-out dialog changes nothing', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Sign out everywhere'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of all devices?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.logoutAllCalls, 0);
      expect(storage.token, 'token');
    });

    testWidgets('confirming signs out of every device and locally', (
      tester,
    ) async {
      await pumpScreen(tester);
      final ended = authBloc.stream.firstWhere((s) => s is AuthUnauthenticated);

      await tester.tap(find.text('Sign out everywhere'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out everywhere'));
      await tester.pumpAndSettle();

      expect(repository.logoutAllCalls, 1);
      expect((await ended as AuthUnauthenticated).message, contains('all devices'));
      expect(storage.token, isNull);
    });

    testWidgets('a failed sign-out everywhere keeps the session and says so', (
      tester,
    ) async {
      await pumpScreen(tester);
      repository.logoutAllFailure = const NetworkFailure(message: 'Offline.');

      await tester.tap(find.text('Sign out everywhere'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out everywhere'));
      await tester.pumpAndSettle();

      expect(find.text('Offline.'), findsOneWidget);
      expect(storage.token, 'token');
    });
  });
}

class _FakeRepository implements AuthRepository {
  final List<(String, String, String)> passwordRequests = [];
  int logoutAllCalls = 0;
  Failure? changePasswordFailure;
  Failure? logoutAllFailure;
  Future<void>? changePasswordGate;
  Object? unexpectedError;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    passwordRequests.add((currentPassword, password, passwordConfirmation));
    await changePasswordGate;
    if (unexpectedError != null) throw unexpectedError!;
    if (changePasswordFailure != null) throw changePasswordFailure!;
  }

  @override
  Future<List<ActiveToken>> listTokens() async => const [];

  @override
  Future<int> logoutAll() async {
    logoutAllCalls++;
    if (unexpectedError != null) throw unexpectedError!;
    if (logoutAllFailure != null) throw logoutAllFailure!;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryStorage implements SecureStorageService {
  String? token;
  String? school;

  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> clearAll() async {
    token = null;
    school = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
