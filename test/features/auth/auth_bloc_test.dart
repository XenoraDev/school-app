import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/main.dart';
import 'package:school_app/core/storage/secure_storage_service.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/domain/entities/login_result.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';

void main() {
  late _MemoryStorage storage;
  late _FakeAuthRepository repository;
  late AuthBloc bloc;

  setUp(() {
    storage = _MemoryStorage();
    repository = _FakeAuthRepository();
    bloc = AuthBloc(repository: repository, storage: storage);
  });

  tearDown(() => bloc.close());

  test('login stores pending token and enters MFA verification', () async {
    repository.loginResult = const LoginResult(
      state: LoginState.mfaRequired,
      accessToken: 'pending-token',
      tokenType: 'Bearer',
    );
    final result = bloc.stream.firstWhere((state) => state is AuthAwaitingMfa);

    bloc.add(
      const AuthLoginRequested(
        school: 'springfield',
        identifier: 'teacher@example.test',
        password: 'secret',
      ),
    );

    expect(await result, isA<AuthAwaitingMfa>());
    expect(storage.token, 'pending-token');
    expect(storage.school, 'springfield');
  });

  test('forced 401 clears local session', () async {
    storage.token = 'old-token';
    storage.school = 'springfield';
    final result = bloc.stream.firstWhere(
      (state) => state is AuthUnauthenticated,
    );
    bloc.add(const AuthForced401());

    final state = await result as AuthUnauthenticated;
    expect(state.message, contains('session has expired'));
    expect(storage.token, isNull);
    expect(storage.school, isNull);
  });

  testWidgets('login form validates required fields and displays errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(
          home: AuthLoginScreen(message: 'Invalid credentials.'),
        ),
      ),
    );
    expect(find.text('Invalid credentials.'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsNWidgets(3));
    expect(repository.loginCalls, 0);
  });
}

class _MemoryStorage implements SecureStorageService {
  String? token;
  String? school;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> saveToken(String value, {DateTime? expiresAt}) async =>
      token = value;
  @override
  Future<void> saveSchoolSlug(String value) async => school = value;
  @override
  Future<void> clearAll() async {
    token = null;
    school = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;
  LoginResult loginResult = const LoginResult(
    state: LoginState.complete,
    accessToken: 'session',
    tokenType: 'Bearer',
  );
  @override
  Future<LoginResult> login({
    required String school,
    required String identifier,
    required String password,
  }) async {
    loginCalls++;
    return loginResult;
  }

  @override
  Future<AccountProfile> getMe() async => const AccountProfile(
    id: 1,
    kind: 'school',
    name: 'Test User',
    email: 'test@example.test',
    userType: 'teacher',
    school: SchoolInfo(name: 'Test School', slug: 'test', status: 'active'),
    abilities: ['classes.view'],
    emailVerified: true,
    mfaEnabled: false,
    mfaRequired: false,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
