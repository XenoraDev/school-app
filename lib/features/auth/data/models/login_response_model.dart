import 'package:school_app/features/auth/domain/entities/login_result.dart';

/// Data Transfer Object for `POST /auth/login` and `POST /auth/mfa/verify`
/// responses.
///
/// Response shape (verified from LoginController.php + Authenticator.php):
/// ```json
/// {
///   "data": {
///     "state": "complete|mfa_required|mfa_enrollment_required",
///     "token_type": "Bearer",
///     "access_token": "sch_1|...",
///     "expires_at": "2026-11-05T15:30:00Z"
///   }
/// }
/// ```
class LoginResponseModel {
  final String state;
  final String accessToken;
  final String tokenType;
  final DateTime? expiresAt;

  const LoginResponseModel({
    required this.state,
    required this.accessToken,
    required this.tokenType,
    this.expiresAt,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return LoginResponseModel(
      state: data['state'] as String,
      accessToken: data['access_token'] as String,
      tokenType: data['token_type'] as String? ?? 'Bearer',
      expiresAt: data['expires_at'] != null
          ? DateTime.tryParse(data['expires_at'] as String)
          : null,
    );
  }

  LoginResult toEntity() => LoginResult(
        state: LoginState.fromString(state),
        accessToken: accessToken,
        tokenType: tokenType,
        expiresAt: expiresAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginResponseModel &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          accessToken == other.accessToken &&
          tokenType == other.tokenType &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode =>
      Object.hash(runtimeType, state, accessToken, tokenType, expiresAt);
}

