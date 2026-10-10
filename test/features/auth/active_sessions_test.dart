import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/auth/domain/entities/active_token.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_app/features/auth/presentation/bloc/active_sessions_cubit.dart';
import 'package:school_app/features/auth/presentation/widgets/active_sessions_section.dart';

ActiveToken _token(
  int id, {
  String name = 'login',
  bool current = false,
  DateTime? lastUsedAt,
  DateTime? expiresAt,
}) => ActiveToken(
  id: id,
  name: name,
  isCurrent: current,
  createdAt: DateTime(2026, 10, 1, 8, 30),
  lastUsedAt: lastUsedAt,
  expiresAt: expiresAt,
);

void main() {
  group('ActiveSessionsCubit', () {
    late _FakeRepository repository;
    late ActiveSessionsCubit cubit;

    setUp(() {
      repository = _FakeRepository();
      cubit = ActiveSessionsCubit(repository);
      addTearDown(cubit.close);
    });

    test('loads the sessions', () async {
      repository.tokens = [_token(1, current: true), _token(2)];

      await cubit.load();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.sessions.map((s) => s.id), [1, 2]);
      expect(cubit.state.loadError, isNull);
    });

    test('keeps a load failure so the screen can retry', () async {
      repository.listFailure = const NetworkFailure(message: 'Offline.');

      await cubit.load();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.loadError, 'Offline.');

      repository.listFailure = null;
      repository.tokens = [_token(1, current: true)];
      await cubit.load();

      expect(cubit.state.loadError, isNull);
      expect(cubit.state.sessions, hasLength(1));
    });

    test('an unexpected load error never leaves the cubit loading', () async {
      repository.unexpectedError = StateError('boom');

      await cubit.load();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.loadError, 'Something went wrong. Please try again.');
    });

    test('revokes another session and refreshes the list', () async {
      repository.tokens = [_token(1, current: true), _token(2)];
      await cubit.load();

      await cubit.revoke(_token(2));

      expect(repository.revoked, [2]);
      expect(cubit.state.sessions.map((s) => s.id), [1]);
      expect(cubit.state.revokingId, isNull);
      expect(cubit.state.message, 'Session signed out.');
    });

    test('a revoked session stays gone when the refresh fails', () async {
      repository.tokens = [_token(1, current: true), _token(2)];
      await cubit.load();
      repository.afterRevoke = () =>
          repository.listFailure = const NetworkFailure(message: 'Offline.');

      await cubit.revoke(_token(2));

      expect(repository.revoked, [2]);
      expect(cubit.state.sessions.map((s) => s.id), [1]);
      expect(cubit.state.loadError, 'Offline.');
      expect(cubit.state.message, 'Session signed out.');
    });

    test('never revokes the current session', () async {
      repository.tokens = [_token(1, current: true)];
      await cubit.load();

      await cubit.revoke(_token(1, current: true));

      expect(repository.revoked, isEmpty);
    });

    test('ignores a second revoke while one is in flight', () async {
      repository.tokens = [_token(1, current: true), _token(2), _token(3)];
      await cubit.load();
      final gate = Completer<void>();
      repository.revokeGate = gate.future;

      final first = cubit.revoke(_token(2));
      expect(cubit.state.revokingId, 2);
      await cubit.revoke(_token(3));
      expect(repository.revoked, [2]);

      gate.complete();
      await first;
      expect(repository.revoked, [2]);
    });

    test('a 404 says the session is gone and refreshes the list', () async {
      repository.tokens = [_token(1, current: true), _token(2)];
      await cubit.load();
      repository.revokeFailure = const NotFoundFailure(message: 'Not found.');
      repository.afterRevoke = () => repository.tokens = [_token(1, current: true)];

      await cubit.revoke(_token(2));

      expect(cubit.state.message, 'That session no longer exists.');
      expect(cubit.state.sessions.map((s) => s.id), [1]);
      expect(cubit.state.revokingId, isNull);
    });

    test('another failure keeps the list and shows the server message', () async {
      repository.tokens = [_token(1, current: true), _token(2)];
      await cubit.load();
      repository.revokeFailure = const NetworkFailure(message: 'Offline.');

      await cubit.revoke(_token(2));

      expect(cubit.state.message, 'Offline.');
      expect(cubit.state.sessions.map((s) => s.id), [1, 2]);
      expect(cubit.state.revokingId, isNull);
      expect(repository.listCalls, 1, reason: 'no refresh after a failure');
    });

    test('a late list answer cannot overwrite a newer one', () async {
      final slow = Completer<List<ActiveToken>>();
      repository.listGates.add(slow.future);
      repository.tokens = [_token(9, current: true)];

      final stale = cubit.load();
      await cubit.load();
      expect(cubit.state.sessions.map((s) => s.id), [9]);

      slow.complete([_token(1, current: true)]);
      await stale;

      expect(cubit.state.sessions.map((s) => s.id), [9]);
    });
  });

  group('ActiveSessionsSection', () {
    late _FakeRepository repository;

    Future<void> pump(WidgetTester tester) async {
      final cubit = ActiveSessionsCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const Scaffold(
              body: SingleChildScrollView(child: ActiveSessionsSection()),
            ),
          ),
        ),
      );
      unawaited(cubit.load());
      await tester.pump();
    }

    setUp(() => repository = _FakeRepository());

    testWidgets('shows a spinner while loading', (tester) async {
      final gate = Completer<List<ActiveToken>>();
      repository.listGates.add(gate.future);

      await pump(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(const []);
      await tester.pump();
    });

    testWidgets('shows the empty state', (tester) async {
      await pump(tester);
      await tester.pump();

      expect(find.text('No active sessions.'), findsOneWidget);
    });

    testWidgets('shows an error and retries', (tester) async {
      repository.listFailure = const NetworkFailure(message: 'Offline.');
      await pump(tester);
      await tester.pump();
      expect(find.text('Offline.'), findsOneWidget);

      repository.listFailure = null;
      repository.tokens = [_token(1, current: true)];
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Offline.'), findsNothing);
      expect(find.text('This device'), findsOneWidget);
    });

    testWidgets('shows name and dates and marks the current session', (
      tester,
    ) async {
      repository.tokens = [
        _token(
          1,
          name: 'mobile',
          current: true,
          lastUsedAt: DateTime(2026, 10, 9, 17, 5),
          expiresAt: DateTime(2026, 11, 1, 8, 30),
        ),
        _token(2, name: 'tablet'),
      ];
      await pump(tester);
      await tester.pump();

      expect(find.text('mobile'), findsOneWidget);
      expect(find.text('tablet'), findsOneWidget);
      expect(find.textContaining('Signed in: 2026-10-01 08:30'), findsNWidgets(2));
      expect(find.textContaining('Last used: 2026-10-09 17:05'), findsOneWidget);
      expect(find.textContaining('Last used: Never'), findsOneWidget);
      expect(find.textContaining('Expires: 2026-11-01 08:30'), findsOneWidget);
      expect(find.textContaining('Expires: No expiry'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
    });

    testWidgets('only other sessions can be signed out', (tester) async {
      repository.tokens = [_token(1, current: true), _token(2), _token(3)];
      await pump(tester);
      await tester.pump();

      expect(find.widgetWithText(TextButton, 'Sign out'), findsNWidgets(2));
    });

    testWidgets('cancelling the dialog revokes nothing', (tester) async {
      repository.tokens = [_token(1, current: true), _token(2)];
      await pump(tester);
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out this session?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.revoked, isEmpty);
    });

    testWidgets('confirming revokes the session and refreshes the list', (
      tester,
    ) async {
      repository.tokens = [_token(1, current: true), _token(2, name: 'tablet')];
      await pump(tester);
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out session'));
      await tester.pumpAndSettle();

      expect(repository.revoked, [2]);
      expect(find.text('tablet'), findsNothing);
      expect(find.text('Session signed out.'), findsOneWidget);
    });

    testWidgets('shows the revoking state and disables the other buttons', (
      tester,
    ) async {
      repository.tokens = [_token(1, current: true), _token(2), _token(3)];
      await pump(tester);
      await tester.pump();
      final gate = Completer<void>();
      repository.revokeGate = gate.future;

      await tester.tap(find.widgetWithText(TextButton, 'Sign out').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out session'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final remaining = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Sign out'),
      );
      expect(remaining.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a 404 shows a normal message', (tester) async {
      repository.tokens = [_token(1, current: true), _token(2)];
      await pump(tester);
      await tester.pump();
      repository.revokeFailure = const NotFoundFailure(message: 'Not found.');
      repository.afterRevoke = () => repository.tokens = [_token(1, current: true)];

      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out session'));
      await tester.pumpAndSettle();

      expect(find.text('That session no longer exists.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign out'), findsNothing);
    });
  });
}

class _FakeRepository implements AuthRepository {
  List<ActiveToken> tokens = [];
  final List<int> revoked = [];
  final List<Future<List<ActiveToken>>> listGates = [];
  int listCalls = 0;
  Failure? listFailure;
  Failure? revokeFailure;
  Object? unexpectedError;
  Future<void>? revokeGate;
  void Function()? afterRevoke;

  @override
  Future<List<ActiveToken>> listTokens() async {
    listCalls++;
    if (listGates.isNotEmpty) return listGates.removeAt(0);
    if (unexpectedError != null) throw unexpectedError!;
    if (listFailure != null) throw listFailure!;
    return List.of(tokens);
  }

  @override
  Future<void> revokeToken({required int tokenId}) async {
    revoked.add(tokenId);
    await revokeGate;
    if (revokeFailure != null) {
      afterRevoke?.call();
      throw revokeFailure!;
    }
    tokens = tokens.where((t) => t.id != tokenId).toList();
    afterRevoke?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
