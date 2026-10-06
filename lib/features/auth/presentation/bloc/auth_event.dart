import 'package:equatable/equatable.dart';

/// Base class for all AuthBloc events.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on app startup to restore session from secure storage.
class AuthAppStarted extends AuthEvent {
  const AuthAppStarted();
}

/// User submitted the login form.
class AuthLoginRequested extends AuthEvent {
  final String school;
  final String identifier;
  final String password;

  const AuthLoginRequested({
    required this.school,
    required this.identifier,
    required this.password,
  });

  @override
  List<Object?> get props => [school, identifier];
  // Note: password intentionally excluded from props for safety.
}

/// User submitted the MFA verification form (TOTP code or recovery code).
class AuthMfaVerifyRequested extends AuthEvent {
  final String? code;
  final String? recoveryCode;

  const AuthMfaVerifyRequested({this.code, this.recoveryCode})
      : assert(
          (code != null) != (recoveryCode != null),
          'Provide exactly one of code or recoveryCode',
        );

  @override
  List<Object?> get props => [code, recoveryCode];
}

/// User triggered MFA enrollment (auto-dispatched on mfa_enrollment_required).
class AuthMfaEnrollRequested extends AuthEvent {
  const AuthMfaEnrollRequested();
}

/// User submitted the TOTP code to confirm enrollment.
class AuthMfaConfirmRequested extends AuthEvent {
  final String code;

  const AuthMfaConfirmRequested({required this.code});

  @override
  List<Object?> get props => [code];
}

/// User requested to logout from the current device.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// User requested to logout from all devices.
class AuthLogoutAllRequested extends AuthEvent {
  const AuthLogoutAllRequested();
}

/// Emitted by [AuthInterceptor] when any API response returns HTTP 401.
///
/// Forces immediate local session wipe and routing to login.
class AuthForced401 extends AuthEvent {
  const AuthForced401();
}

