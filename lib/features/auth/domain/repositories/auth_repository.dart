import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/domain/entities/active_token.dart';
import 'package:school_app/features/auth/domain/entities/confirm_mfa_result.dart';
import 'package:school_app/features/auth/domain/entities/login_result.dart';
import 'package:school_app/features/auth/domain/entities/mfa_enrollment_info.dart';

/// Contract for all authentication and session operations.
///
/// Implementations throw [Failure] subclasses on error (not return Either).
/// This matches the Phase 0 pattern established in [AppConfigRepository].
abstract interface class AuthRepository {
  // ── Login ─────────────────────────────────────────────────────────────────

  /// Authenticates a school user.
  ///
  /// Throws [UnauthorizedFailure] on invalid credentials.
  /// Throws [ValidationFailure] on malformed request.
  /// Throws [RateLimitedFailure] on `auth-attempt` throttle.
  Future<LoginResult> login({
    required String school,
    required String identifier,
    required String password,
  });

  // ── MFA ───────────────────────────────────────────────────────────────────

  /// Verifies a TOTP [code] or [recoveryCode] against the pending token.
  ///
  /// Exactly one of [code] or [recoveryCode] must be non-null.
  /// Throws [UnauthorizedFailure] if the code is invalid or the account is locked.
  Future<LoginResult> verifyMfa({String? code, String? recoveryCode});

  /// Begins TOTP enrollment. Returns the secret and otpauth URI.
  ///
  /// Throws [ConflictFailure] if MFA is already enrolled (invalid_state).
  Future<MfaEnrollmentInfo> enrollMfa();

  /// Confirms TOTP enrollment with a valid [code].
  ///
  /// Returns 10 one-time recovery codes. If called with a pending token,
  /// also returns a full session [LoginResult] in [ConfirmMfaResult.sessionToken].
  ///
  /// Throws [ValidationFailure] if the code is invalid.
  Future<ConfirmMfaResult> confirmMfa({required String code});

  /// Disables MFA. Requires [password] + current TOTP [code].
  ///
  /// Throws [ForbiddenFailure] if MFA is mandatory for the account.
  /// Throws [ValidationFailure] if password/code are incorrect.
  Future<void> disableMfa({required String password, required String code});

  // ── Session ───────────────────────────────────────────────────────────────

  /// Fetches the current user's profile and session abilities.
  ///
  /// Used on app startup for session restoration and role-based routing.
  /// Throws [UnauthorizedFailure] if the token is invalid or expired.
  Future<AccountProfile> getMe();

  /// Revokes the current device token.
  Future<void> logout();

  /// Revokes ALL active tokens. Returns the count revoked.
  Future<int> logoutAll();

  /// Lists all active tokens for the current user.
  Future<List<ActiveToken>> listTokens();

  /// Revokes a specific token by its integer [tokenId].
  ///
  /// Throws [NotFoundFailure] if the token doesn't belong to the current user.
  Future<void> revokeToken({required int tokenId});

  /// Changes the authenticated user's password.
  ///
  /// The backend revokes ALL tokens on success, requiring re-login.
  /// Throws [ValidationFailure] if [currentPassword] is wrong or new password
  /// fails the policy (min 12, mixed case, digit, symbol).
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  });
}

