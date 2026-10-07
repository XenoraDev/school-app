import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';

abstract interface class TeacherWorkspaceRepository {
  Future<List<TeacherSection>> getMySections();
  Future<List<TeacherSubject>> getMySubjects();
}
