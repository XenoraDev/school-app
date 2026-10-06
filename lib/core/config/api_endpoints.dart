/// API endpoint path constants relative to base URL (/api/v1).
abstract final class ApiEndpoints {
  // ── Phase 0 ──────────────────────────────────────────────────────────────

  /// Health check endpoint (GET /api/v1/health)
  static const String health = '/health';

  /// App public branding configuration endpoint (GET /api/v1/app-config)
  static const String appConfig = '/app-config';

  // ── Phase 1 — Auth, Session & MFA ────────────────────────────────────────

  /// School-user password login (POST /api/v1/auth/login)
  static const String login = '/auth/login';

  /// Revoke current device token (POST /api/v1/auth/logout)
  static const String logout = '/auth/logout';

  /// Revoke all active tokens (POST /api/v1/auth/logout-all)
  static const String logoutAll = '/auth/logout-all';

  /// List active tokens (GET /api/v1/auth/tokens)
  static const String tokens = '/auth/tokens';

  /// Change password — revokes all tokens (POST /api/v1/auth/password/change)
  static const String changePassword = '/auth/password/change';

  /// Request password-reset email — 503 while EMAIL_AUTH_ENABLED=false
  /// (POST /api/v1/auth/password/forgot)
  static const String forgotPassword = '/auth/password/forgot';

  /// Complete password reset — 503 while EMAIL_AUTH_ENABLED=false
  /// (POST /api/v1/auth/password/reset)
  static const String resetPassword = '/auth/password/reset';

  /// MFA verify with pending token (POST /api/v1/auth/mfa/verify)
  static const String mfaVerify = '/auth/mfa/verify';

  /// Begin TOTP enrollment (POST /api/v1/auth/mfa/enroll)
  static const String mfaEnroll = '/auth/mfa/enroll';

  /// Confirm TOTP enrollment (POST /api/v1/auth/mfa/confirm)
  static const String mfaConfirm = '/auth/mfa/confirm';

  /// Disable MFA (POST /api/v1/auth/mfa/disable)
  static const String mfaDisable = '/auth/mfa/disable';

  /// Authenticated user profile + abilities (GET /api/v1/common/me)
  static const String me = '/common/me';

  /// Revoke a specific token by integer ID (DELETE /api/v1/auth/tokens/{id})
  static String revokeToken(int id) => '/auth/tokens/$id';
}

