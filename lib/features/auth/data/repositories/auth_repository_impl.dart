import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/domain/entities/active_token.dart';
import 'package:school_app/features/auth/domain/entities/confirm_mfa_result.dart';
import 'package:school_app/features/auth/domain/entities/login_result.dart';
import 'package:school_app/features/auth/domain/entities/mfa_enrollment_info.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';

/// Concrete implementation of [AuthRepository].
///
/// Delegates all HTTP to [AuthRemoteDataSource] and translates
/// [ApiException] / [NetworkException] into domain [Failure] subclasses by
/// calling [e.toFailure()].
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;

  const AuthRepositoryImpl({required AuthRemoteDataSource remote})
      : _remote = remote;

  @override
  Future<LoginResult> login({
    required String school,
    required String identifier,
    required String password,
  }) async {
    try {
      final model = await _remote.login(
        school: school,
        identifier: identifier,
        password: password,
      );
      return model.toEntity();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<LoginResult> verifyMfa({
    String? code,
    String? recoveryCode,
  }) async {
    try {
      final model = await _remote.verifyMfa(
        code: code,
        recoveryCode: recoveryCode,
      );
      return model.toEntity();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<MfaEnrollmentInfo> enrollMfa() async {
    try {
      return await _remote.enrollMfa();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<ConfirmMfaResult> confirmMfa({required String code}) async {
    try {
      return await _remote.confirmMfa(code: code);
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<void> disableMfa({
    required String password,
    required String code,
  }) async {
    try {
      await _remote.disableMfa(password: password, code: code);
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<AccountProfile> getMe() async {
    try {
      final model = await _remote.getMe();
      return model.toEntity();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _remote.logout();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<int> logoutAll() async {
    try {
      return await _remote.logoutAll();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<List<ActiveToken>> listTokens() async {
    try {
      final models = await _remote.listTokens();
      return models.map((m) => m.toEntity()).toList();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<void> revokeToken({required int tokenId}) async {
    try {
      await _remote.revokeToken(tokenId: tokenId);
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await _remote.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }
}

