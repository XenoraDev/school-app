import 'package:dio/dio.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/network/api_client.dart';
import 'package:school_app/features/app_config/data/models/app_config_model.dart';

abstract interface class AppConfigRemoteDataSource {
  Future<AppConfigModel> getAppConfig();
  Future<bool> checkHealth();
}

class AppConfigRemoteDataSourceImpl implements AppConfigRemoteDataSource {
  final ApiClient _client;

  AppConfigRemoteDataSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<AppConfigModel> getAppConfig() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.appConfig,
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException(
          message: 'Empty response received from app-config endpoint.',
          errorCode: ApiErrorCode.serverError,
        );
      }

      return AppConfigModel.fromJson(data);
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      if (e.error is NetworkException) {
        throw e.error as NetworkException;
      }
      throw NetworkException(
        e.message ?? 'Failed to communicate with app-config endpoint.',
      );
    }
  }

  @override
  Future<bool> checkHealth() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.health,
      );

      final data = response.data;
      if (data != null && data['status'] == 'ok') {
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      if (e.error is NetworkException) {
        throw e.error as NetworkException;
      }
      throw NetworkException(
        e.message ?? 'Failed to communicate with health endpoint.',
      );
    }
  }
}
