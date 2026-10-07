// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:dio/dio.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/network/api_client.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';

abstract interface class AdminRemoteDataSource {
  Future<List<AdminRecord>> list(String path, {Map<String, dynamic>? query});
  Future<AdminPage> listPage(String path, {Map<String, dynamic>? query});
  Future<AdminRecord> get(String path);
  Future<AdminRecord> send(String method, String path, {JsonMap? body});
  Future<void> delete(String path);
  Future<List<SetupStep>> setup();
  Future<List<PermissionGroup>> permissions();
  Future<List<AdminRecord>> replaceCurriculum(JsonMap body);
  Future<List<AdminRecord>> updateSettings(JsonMap body);
  Future<List<AdminRecord>> replaceRolePermissions(String id, JsonMap body);
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  AdminRemoteDataSourceImpl({required ApiClient client}) : _client = client;
  final ApiClient _client;

  @override
  Future<List<AdminRecord>> list(String path, {Map<String, dynamic>? query}) =>
      _request(
        () async => _records(
          (await _client.get<Map<String, dynamic>>(
            path,
            queryParameters: query,
          )).data,
        ),
      );
  @override
  Future<AdminPage> listPage(String path, {Map<String, dynamic>? query}) =>
      _request(() async {
        final json = (await _client.get<Map<String, dynamic>>(
          path,
          queryParameters: query,
        )).data;
        final meta = json?['meta'];
        final data = json?['data'];
        if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
          throw ApiException(
            message: 'The server returned an unexpected collection.',
            errorCode: ApiErrorCode.serverError,
          );
        }
        return AdminPage(
          records: data
              .map((row) => AdminRecord.fromJson(row as JsonMap))
              .toList(growable: false),
          nextCursor: meta is Map<String, dynamic>
              ? meta['next_cursor'] as String?
              : null,
          hasMore: meta is Map<String, dynamic>
              ? meta['has_more'] as bool? ?? false
              : false,
        );
      });
  @override
  Future<AdminRecord> get(String path) => _request(
    () async => _record((await _client.get<Map<String, dynamic>>(path)).data),
  );
  @override
  Future<AdminRecord> send(String method, String path, {JsonMap? body}) =>
      _request(() async {
        final response = switch (method) {
          'POST' => await _client.post<Map<String, dynamic>>(path, data: body),
          'PATCH' => await _client.patch<Map<String, dynamic>>(
            path,
            data: body,
          ),
          'PUT' => await _client.put<Map<String, dynamic>>(path, data: body),
          _ => throw ArgumentError.value(method, 'method'),
        };
        return _record(response.data);
      });
  @override
  Future<void> delete(String path) => _request(() async {
    await _client.delete<void>(path);
  });

  @override
  Future<List<SetupStep>> setup() => _request(() async {
    final rows = _data(
      (await _client.get<Map<String, dynamic>>(ApiEndpoints.schoolSetup)).data,
    );
    return rows.map((row) => SetupStep.fromJson(row)).toList(growable: false);
  });
  @override
  Future<List<PermissionGroup>> permissions() => _request(() async {
    final rows = _data(
      (await _client.get<Map<String, dynamic>>(ApiEndpoints.permissions)).data,
    );
    return rows
        .map((row) => PermissionGroup.fromJson(row))
        .toList(growable: false);
  });
  @override
  Future<List<AdminRecord>> replaceCurriculum(JsonMap body) => _request(
    () async => _records(
      (await _client.put<Map<String, dynamic>>(
        ApiEndpoints.curriculum,
        data: body,
      )).data,
    ),
  );
  @override
  Future<List<AdminRecord>> updateSettings(JsonMap body) => _request(
    () async => _records(
      (await _client.patch<Map<String, dynamic>>(
        ApiEndpoints.schoolSettings,
        data: body,
      )).data,
    ),
  );
  @override
  Future<List<AdminRecord>> replaceRolePermissions(String id, JsonMap body) =>
      _request(
        () async => _records(
          (await _client.put<Map<String, dynamic>>(
            ApiEndpoints.rolePermissions(id),
            data: body,
          )).data,
        ),
      );

  static List<JsonMap> _data(Map<String, dynamic>? json) {
    final data = json?['data'];
    if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
      throw ApiException(
        message: 'The server returned an unexpected collection.',
        errorCode: ApiErrorCode.serverError,
      );
    }
    return data.cast<JsonMap>();
  }

  static List<AdminRecord> _records(Map<String, dynamic>? json) {
    final data = json?['data'];
    if (data is Map<String, dynamic>) return [AdminRecord.fromJson(data)];
    return _data(json).map(AdminRecord.fromJson).toList(growable: false);
  }

  static AdminRecord _record(Map<String, dynamic>? json) {
    final data = json?['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'The server returned an unexpected resource.',
        errorCode: ApiErrorCode.serverError,
      );
    }
    return AdminRecord.fromJson(data);
  }

  static Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.error is ApiException) throw error.error as ApiException;
      if (error.error is NetworkException)
        throw error.error as NetworkException;
      throw NetworkException(
        error.message ?? 'The school data request failed.',
      );
    }
  }
}
