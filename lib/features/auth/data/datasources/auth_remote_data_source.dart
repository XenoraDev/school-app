import 'package:dio/dio.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/network/api_client.dart';
import 'package:school_app/features/auth/data/models/account_profile_model.dart';
import 'package:school_app/features/auth/data/models/active_token_model.dart';
import 'package:school_app/features/auth/data/models/login_response_model.dart';
import 'package:school_app/features/auth/domain/entities/confirm_mfa_result.dart';
import 'package:school_app/features/auth/domain/entities/login_result.dart';
import 'package:school_app/features/auth/domain/entities/mfa_enrollment_info.dart';

/// Contract for authentication remote operations.
abstract interface class AuthRemoteDataSource {
  Future<LoginResponseModel> login({
    required String school,
    required String identifier,
    required String password,
  });

  Future<LoginResponseModel> verifyMfa({String? code, String? recoveryCode});
  Future<MfaEnrollmentInfo> enrollMfa();
  Future<ConfirmMfaResult> confirmMfa({required String code});
  Future<void> disableMfa({required String password, required String code});
  Future<AccountProfileModel> getMe();
  Future<void> logout();
  Future<int> logoutAll();
  Future<List<ActiveTokenModel>> listTokens();
  Future<void> revokeToken({required int tokenId});
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  });
}

/// Concrete implementation of [AuthRemoteDataSource] using [ApiClient].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _client;

  AuthRemoteDataSourceImpl({required ApiClient client}) : _client = client;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extracts `response.data` as a Map, throwing [ApiException] on null.
  Map<String, dynamic> _requireData(dynamic raw, String endpoint) {
    if (raw is Map<String, dynamic>) return raw;
    throw ApiException(
      message: 'Empty or malformed response from $endpoint.',
      errorCode: ApiErrorCode.serverError,
    );
  }

  /// Unwraps a DioException into the typed exception stored in [err.error],
  /// or creates a [NetworkException] as a fallback.
  Never _rethrow(DioException err, String endpoint) {
    if (err.error is ApiException) throw err.error as ApiException;
    if (err.error is NetworkException) throw err.error as NetworkException;
    throw NetworkException(
      err.message ?? 'Failed to communicate with $endpoint.',
    );
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  @override
  Future<LoginResponseModel> login({
    required String school,
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {'school': school, 'identifier': identifier, 'password': password},
      );
      final data = _requireData(response.data, 'login');
      return LoginResponseModel.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e, 'login');
    }
  }

  // ── MFA ───────────────────────────────────────────────────────────────────

  @override
  Future<LoginResponseModel> verifyMfa({
    String? code,
    String? recoveryCode,
  }) async {
    assert(
      (code != null) != (recoveryCode != null),
      'Exactly one of code or recoveryCode must be provided',
    );
    try {
      final body = code != null ? {'code': code} : {'recovery_code': recoveryCode};
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.mfaVerify,
        data: body,
      );
      final data = _requireData(response.data, 'mfa/verify');
      return LoginResponseModel.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e, 'mfa/verify');
    }
  }

  @override
  Future<MfaEnrollmentInfo> enrollMfa() async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.mfaEnroll,
      );
      final raw = _requireData(response.data, 'mfa/enroll');
      final data = raw['data'] as Map<String, dynamic>? ?? raw;
      return MfaEnrollmentInfo(
        secret: data['secret'] as String,
        uri: data['uri'] as String,
      );
    } on DioException catch (e) {
      _rethrow(e, 'mfa/enroll');
    }
  }

  @override
  Future<ConfirmMfaResult> confirmMfa({required String code}) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.mfaConfirm,
        data: {'code': code},
      );
      final raw = _requireData(response.data, 'mfa/confirm');
      final data = raw['data'] as Map<String, dynamic>? ?? raw;

      final rawCodes = data['recovery_codes'] as List<dynamic>? ?? [];
      final recoveryCodes = rawCodes.map((e) => e.toString()).toList();

      // Full session token is only present when called with a pending token.
      LoginResult? sessionToken;
      if (data.containsKey('access_token')) {
        sessionToken = LoginResponseModel.fromJson(raw).toEntity();
      }

      return ConfirmMfaResult(
        recoveryCodes: recoveryCodes,
        sessionToken: sessionToken,
      );
    } on DioException catch (e) {
      _rethrow(e, 'mfa/confirm');
    }
  }

  @override
  Future<void> disableMfa({
    required String password,
    required String code,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiEndpoints.mfaDisable,
        data: {'password': password, 'code': code},
      );
    } on DioException catch (e) {
      _rethrow(e, 'mfa/disable');
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  @override
  Future<AccountProfileModel> getMe() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(ApiEndpoints.me);
      final data = _requireData(response.data, 'common/me');
      return AccountProfileModel.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e, 'common/me');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.post<Map<String, dynamic>>(ApiEndpoints.logout);
    } on DioException catch (e) {
      _rethrow(e, 'auth/logout');
    }
  }

  @override
  Future<int> logoutAll() async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.logoutAll,
      );
      final raw = _requireData(response.data, 'auth/logout-all');
      final data = raw['data'] as Map<String, dynamic>? ?? raw;
      return data['revoked'] as int? ?? 0;
    } on DioException catch (e) {
      _rethrow(e, 'auth/logout-all');
    }
  }

  @override
  Future<List<ActiveTokenModel>> listTokens() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.tokens,
      );
      final raw = _requireData(response.data, 'auth/tokens');
      final list = raw['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => ActiveTokenModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _rethrow(e, 'auth/tokens');
    }
  }

  @override
  Future<void> revokeToken({required int tokenId}) async {
    try {
      await _client.delete<Map<String, dynamic>>(
        ApiEndpoints.revokeToken(tokenId),
      );
    } on DioException catch (e) {
      _rethrow(e, 'auth/tokens/$tokenId');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiEndpoints.changePassword,
        data: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
    } on DioException catch (e) {
      _rethrow(e, 'auth/password/change');
    }
  }
}

