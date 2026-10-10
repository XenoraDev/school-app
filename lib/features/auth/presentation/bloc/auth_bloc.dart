import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/core/storage/secure_storage_service.dart';
import 'package:school_app/features/auth/domain/entities/login_result.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';

/// Central state machine for authentication, session lifecycle, and MFA flow.
///
/// State transitions:
/// ```
/// AuthInitial
///   → AuthAppStarted → AuthSessionRestoring
///     → [token found] → AuthAuthenticated
///     → [no token / 401] → AuthUnauthenticated
///
/// AuthUnauthenticated
///   → AuthLoginRequested → AuthLoading
///     → complete        → AuthAuthenticated
///     → mfa_required    → AuthAwaitingMfa
///     → enrollment_req  → AuthAwaitingMfaEnrollment
///     → failure         → AuthFailure
///
/// AuthAwaitingMfa
///   → AuthMfaVerifyRequested → AuthLoading
///     → success → AuthAuthenticated
///     → failure → AuthFailure
///
/// AuthAwaitingMfaEnrollment (handled in MfaEnrollBloc / screens)
///
/// AuthAuthenticated
///   → AuthLogoutRequested / AuthLogoutAllRequested / AuthForced401
///     → AuthUnauthenticated
/// ```
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;
  final SecureStorageService _storage;

  AuthBloc({
    required AuthRepository repository,
    required SecureStorageService storage,
  }) : _repository = repository,
       _storage = storage,
       super(const AuthInitial()) {
    on<AuthAppStarted>(_onAppStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthMfaVerifyRequested>(_onMfaVerifyRequested);
    on<AuthMfaEnrollRequested>(_onMfaEnrollRequested);
    on<AuthMfaConfirmRequested>(_onMfaConfirmRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthLogoutAllRequested>(_onLogoutAllRequested);
    on<AuthSessionEnded>(_onSessionEnded);
    on<AuthForced401>(_onForced401);
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _onAppStarted(
    AuthAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthSessionRestoring());
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }
      // Token exists — validate by fetching profile.
      final profile = await _repository.getMe();
      emit(AuthAuthenticated(profile: profile));
    } on UnauthorizedFailure {
      await _storage.clearAll();
      emit(
        const AuthUnauthenticated(
          message: 'Your session has expired. Please log in again.',
        ),
      );
    } on Failure catch (f) {
      await _storage.clearAll();
      emit(AuthUnauthenticated(message: f.message));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _repository.login(
        school: event.school,
        identifier: event.identifier,
        password: event.password,
      );
      await _storage.saveSchoolSlug(event.school);

      switch (result.state) {
        case LoginState.complete:
          // Store full session token, then fetch profile.
          await _storage.saveToken(
            result.accessToken,
            expiresAt: result.expiresAt,
          );
          final profile = await _repository.getMe();
          emit(AuthAuthenticated(profile: profile));

        case LoginState.mfaRequired:
          // Store pending token temporarily so AuthInterceptor can attach it.
          await _storage.saveToken(
            result.accessToken,
            expiresAt: result.expiresAt,
          );
          emit(AuthAwaitingMfa(pendingResult: result));

        case LoginState.mfaEnrollmentRequired:
          await _storage.saveToken(
            result.accessToken,
            expiresAt: result.expiresAt,
          );
          emit(AuthAwaitingMfaEnrollment(pendingResult: result));
      }
    } on ValidationFailure catch (f) {
      emit(AuthFailure(message: f.message, fieldErrors: f.errors));
    } on RateLimitedFailure catch (f) {
      emit(
        AuthFailure(
          message: 'Too many attempts. Please wait and try again.',
          fieldErrors: {
            '_': [f.message],
          },
        ),
      );
    } on Failure catch (f) {
      emit(AuthFailure(message: f.message));
    }
  }

  Future<void> _onMfaVerifyRequested(
    AuthMfaVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    final previousState = state;
    emit(const AuthLoading());
    try {
      final result = await _repository.verifyMfa(
        code: event.code,
        recoveryCode: event.recoveryCode,
      );
      // Backend returns a full session token upon successful MFA verification.
      await _storage.saveToken(result.accessToken, expiresAt: result.expiresAt);
      final profile = await _repository.getMe();
      emit(AuthAuthenticated(profile: profile));
    } on ValidationFailure catch (f) {
      emit(
        previousState is AuthAwaitingMfa
            ? AuthAwaitingMfa(
                pendingResult: previousState.pendingResult,
                message: f.message,
              )
            : AuthFailure(message: f.message, fieldErrors: f.errors),
      );
    } on Failure catch (f) {
      emit(
        previousState is AuthAwaitingMfa
            ? AuthAwaitingMfa(
                pendingResult: previousState.pendingResult,
                message: f.message,
              )
            : AuthFailure(message: f.message),
      );
    }
  }

  Future<void> _onMfaEnrollRequested(
    AuthMfaEnrollRequested event,
    Emitter<AuthState> emit,
  ) async {
    final previousState = state;
    emit(const AuthLoading());
    try {
      emit(AuthMfaEnrollmentReady(info: await _repository.enrollMfa()));
    } on Failure catch (f) {
      emit(
        previousState is AuthAwaitingMfaEnrollment
            ? AuthAwaitingMfaEnrollment(
                pendingResult: previousState.pendingResult,
                message: f.message,
              )
            : AuthFailure(message: f.message),
      );
    }
  }

  Future<void> _onMfaConfirmRequested(
    AuthMfaConfirmRequested event,
    Emitter<AuthState> emit,
  ) async {
    final previousState = state;
    emit(const AuthLoading());
    try {
      final result = await _repository.confirmMfa(code: event.code);
      final session = result.sessionToken;
      if (session != null) {
        await _storage.saveToken(
          session.accessToken,
          expiresAt: session.expiresAt,
        );
      }
      final profile = await _repository.getMe();
      emit(
        AuthMfaEnrollmentConfirmed(
          recoveryCodes: result.recoveryCodes,
          profile: profile,
        ),
      );
    } on Failure catch (f) {
      emit(
        previousState is AuthMfaEnrollmentReady
            ? AuthMfaEnrollmentReady(
                info: previousState.info,
                message: f.message,
              )
            : AuthFailure(message: f.message),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repository.logout();
    } catch (_) {
      // Best-effort — always clear local storage even if the API call fails.
    } finally {
      await _storage.clearAll();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutAllRequested(
    AuthLogoutAllRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repository.logoutAll();
    } catch (_) {
      // Best-effort logout.
    } finally {
      await _storage.clearAll();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSessionEnded(
    AuthSessionEnded event,
    Emitter<AuthState> emit,
  ) async {
    await _storage.clearAll();
    emit(AuthUnauthenticated(message: event.message));
  }

  /// Triggered by [AuthInterceptor.onUnauthorized] on any HTTP 401 response.
  ///
  /// Wipes local storage and returns to login without waiting for the network.
  Future<void> _onForced401(
    AuthForced401 event,
    Emitter<AuthState> emit,
  ) async {
    await _storage.clearAll();
    emit(
      const AuthUnauthenticated(
        message: 'Your session has expired. Please log in again.',
      ),
    );
  }
}
