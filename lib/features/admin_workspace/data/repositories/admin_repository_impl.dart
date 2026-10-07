import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/features/admin_workspace/data/datasources/admin_remote_data_source.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({required AdminRemoteDataSource remote})
    : _remote = remote;
  final AdminRemoteDataSource _remote;
  Future<T> _map<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      throw error.toFailure();
    } on NetworkException catch (error) {
      throw error.toFailure();
    }
  }

  @override
  Future<List<AdminRecord>> list(String path, {Map<String, dynamic>? query}) =>
      _map(() => _remote.list(path, query: query));
  @override
  Future<AdminPage> listPage(String path, {Map<String, dynamic>? query}) =>
      _map(() => _remote.listPage(path, query: query));
  @override
  Future<AdminRecord> get(String path) => _map(() => _remote.get(path));
  @override
  Future<AdminRecord> send(String method, String path, {JsonMap? body}) =>
      _map(() => _remote.send(method, path, body: body));
  @override
  Future<void> delete(String path) => _map(() => _remote.delete(path));
  @override
  Future<List<SetupStep>> setup() => _map(_remote.setup);
  @override
  Future<List<PermissionGroup>> permissions() => _map(_remote.permissions);
  @override
  Future<List<AdminRecord>> replaceCurriculum(JsonMap body) =>
      _map(() => _remote.replaceCurriculum(body));
  @override
  Future<List<AdminRecord>> updateSettings(JsonMap body) =>
      _map(() => _remote.updateSettings(body));
  @override
  Future<List<AdminRecord>> replaceRolePermissions(String id, JsonMap body) =>
      _map(() => _remote.replaceRolePermissions(id, body));
}
