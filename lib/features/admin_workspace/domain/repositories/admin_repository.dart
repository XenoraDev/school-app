import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';

abstract interface class AdminRepository {
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
