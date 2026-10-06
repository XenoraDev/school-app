import 'login_result.dart';
/// Result of a successful `POST /auth/mfa/confirm` call.
///
/// `recoveryCodesOneTime` is the list of 10 single-use recovery codes shown
/// exactly once — the user must save them.
///
/// `sessionToken` is non-null only when the enrollment was performed with
/// a **pending** token (i.e., `mfa_enrollment_required` flow). When a fully
/// authenticated user enrolls voluntarily, only recovery codes are returned.
class ConfirmMfaResult {
  /// 10 single-use recovery codes returned by the backend (shown once).
  final List<String> recoveryCodes;

  /// The full session [LoginResult] — present only when MFA enrollment was
  /// triggered from a pending token.
  final LoginResult? sessionToken;

  const ConfirmMfaResult({
    required this.recoveryCodes,
    this.sessionToken,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConfirmMfaResult || runtimeType != other.runtimeType) {
      return false;
    }
    if (sessionToken != other.sessionToken) return false;
    if (recoveryCodes.length != other.recoveryCodes.length) return false;
    for (var i = 0; i < recoveryCodes.length; i++) {
      if (recoveryCodes[i] != other.recoveryCodes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(recoveryCodes),
        sessionToken,
      );
}

