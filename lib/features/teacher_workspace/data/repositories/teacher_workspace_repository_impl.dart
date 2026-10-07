import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/features/teacher_workspace/data/datasources/teacher_workspace_remote_data_source.dart';
import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';
import 'package:school_app/features/teacher_workspace/domain/repositories/teacher_workspace_repository.dart';

class TeacherWorkspaceRepositoryImpl implements TeacherWorkspaceRepository {
  final TeacherWorkspaceRemoteDataSource _remote;

  const TeacherWorkspaceRepositoryImpl({
    required TeacherWorkspaceRemoteDataSource remote,
  }) : _remote = remote;

  @override
  Future<List<TeacherSection>> getMySections() async {
    try {
      return (await _remote.getMySections())
          .map((model) => model.toEntity())
          .toList(growable: false);
    } on ApiException catch (error) {
      throw error.toFailure();
    } on NetworkException catch (error) {
      throw error.toFailure();
    }
  }

  @override
  Future<List<TeacherSubject>> getMySubjects() async {
    try {
      return (await _remote.getMySubjects())
          .map((model) => model.toEntity())
          .toList(growable: false);
    } on ApiException catch (error) {
      throw error.toFailure();
    } on NetworkException catch (error) {
      throw error.toFailure();
    }
  }
}
