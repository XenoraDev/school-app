/// Result of `POST /auth/mfa/enroll`.
///
/// Contains the TOTP secret and the `otpauth://` URI for QR code rendering.
class MfaEnrollmentInfo {
  /// Base32-encoded TOTP secret (for manual entry).
  final String secret;

  /// `otpauth://totp/...` URI for QR code display.
  final String uri;

  const MfaEnrollmentInfo({required this.secret, required this.uri});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MfaEnrollmentInfo &&
          runtimeType == other.runtimeType &&
          secret == other.secret &&
          uri == other.uri;

  @override
  int get hashCode => Object.hash(runtimeType, secret, uri);

  @override
  String toString() => 'MfaEnrollmentInfo(uri: $uri)';
}

