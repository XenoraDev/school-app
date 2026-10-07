import 'package:dio/dio.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/network/api_client.dart';
import 'package:school_app/features/teacher_workspace/data/models/teacher_workspace_models.dart';

abstract interface class TeacherWorkspaceRemoteDataSource {
  Future<List<TeacherSectionModel>> getMySections();
  Future<List<TeacherSubjectModel>> getMySubjects();
}

class TeacherWorkspaceRemoteDataSourceImpl
    implements TeacherWorkspaceRemoteDataSource {
  final ApiClient _client;

  TeacherWorkspaceRemoteDataSourceImpl({required ApiClient client})
    : _client = client;

  @override
  Future<List<TeacherSectionModel>> getMySections() => _getList(
    path: ApiEndpoints.mySections,
    endpointName: 'teacher/my/sections',
    parse: TeacherSectionModel.fromJson,
  );

  @override
  Future<List<TeacherSubjectModel>> getMySubjects() => _getList(
    path: ApiEndpoints.mySubjects,
    endpointName: 'teacher/my/subjects',
    parse: TeacherSubjectModel.fromJson,
  );

  Future<List<T>> _getList<T>({
    required String path,
    required String endpointName,
    required T Function(Map<String, dynamic>) parse,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      final raw = response.data?['data'];
      if (raw is! List) {
        throw ApiException(
          message: 'Malformed response from $endpointName.',
          errorCode: ApiErrorCode.serverError,
        );
      }
      return raw
          .map((item) => parse(item as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.error is ApiException) {
        throw error.error as ApiException;
      }
      if (error.error is NetworkException) {
        throw error.error as NetworkException;
      }
      throw NetworkException(error.message ?? 'Failed to load $endpointName.');
    }
  }
}
