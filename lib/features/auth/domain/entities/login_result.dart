/// Represents the three possible outcomes of a login attempt.
///
/// Mirrors `LoginOutcome::COMPLETE`, `MFA_REQUIRED`, `MFA_ENROLLMENT_REQUIRED`
/// from `school-api/app/Auth/LoginOutcome.php`.
enum LoginState {
  /// Credentials valid, no MFA required. Full session token issued.
  complete,

  /// Account has MFA enrolled. Pending token returned; must verify TOTP or
  /// recovery code via `POST /auth/mfa/verify`.
  mfaRequired,

  /// MFA is mandatory for this account but not yet enrolled. Pending token
  /// returned; must enroll via `POST /auth/mfa/enroll` + `confirm`.
  mfaEnrollmentRequired;

  static LoginState fromString(String value) {
    return switch (value) {
      'complete' => LoginState.complete,
      'mfa_required' => LoginState.mfaRequired,
      'mfa_enrollment_required' => LoginState.mfaEnrollmentRequired,
      _ => throw ArgumentError('Unknown LoginState: $value'),
    };
  }
}

/// Domain entity returned from `POST /auth/login` and `POST /auth/mfa/verify`.
class LoginResult {
  /// The authentication flow state.
  final LoginState state;

  /// The Bearer token value. May be a pending token (auth.mfa) or a full
  /// session token (auth.session) depending on [state].
  final String accessToken;

  /// Always `'Bearer'`.
  final String tokenType;

  /// Token expiry. Pending tokens expire in 10 minutes. Full tokens up to 30 days.
  final DateTime? expiresAt;

  const LoginResult({
    required this.state,
    required this.accessToken,
    required this.tokenType,
    this.expiresAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginResult &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          accessToken == other.accessToken &&
          tokenType == other.tokenType &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(runtimeType, state, accessToken, tokenType, expiresAt);

  @override
  String toString() =>
      'LoginResult(state: $state, tokenType: $tokenType, expiresAt: $expiresAt)';
}

