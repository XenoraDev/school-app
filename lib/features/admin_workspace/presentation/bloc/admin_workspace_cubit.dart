import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/domain/repositories/admin_repository.dart';

class AdminWorkspaceState {
  const AdminWorkspaceState({
    this.loading = false,
    this.saving = false,
    this.error,
    this.records = const [],
    this.steps = const [],
    this.permissions = const [],
    this.nextCursor,
    this.hasMore = false,
  });
  final bool loading, saving;
  final String? error;
  final List<AdminRecord> records;
  final List<SetupStep> steps;
  final List<PermissionGroup> permissions;
  final String? nextCursor;
  final bool hasMore;
  AdminWorkspaceState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    List<AdminRecord>? records,
    List<SetupStep>? steps,
    List<PermissionGroup>? permissions,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
  }) => AdminWorkspaceState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
    records: records ?? this.records,
    steps: steps ?? this.steps,
    permissions: permissions ?? this.permissions,
    nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
  );
}

class AdminWorkspaceCubit extends Cubit<AdminWorkspaceState> {
  AdminWorkspaceCubit(this._repository) : super(const AdminWorkspaceState());
  final AdminRepository _repository;
  String? _activePath;
  Map<String, dynamic> _activeQuery = const {};
  Future<List<AdminRecord>> fetchRecords(String path) => _repository.list(path);
  Future<void> load(String path, {Map<String, dynamic>? query}) async {
    _activePath = path;
    _activeQuery = query ?? const {};
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        records: const [],
        clearCursor: true,
        hasMore: false,
      ),
    );
    try {
      final page = await _repository.listPage(path, query: query);
      emit(
        state.copyWith(
          loading: false,
          records: page.records,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  Future<void> loadMore(String path) async {
    if (state.loading || !state.hasMore || state.nextCursor == null) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final page = await _repository.listPage(
        _activePath ?? path,
        query: {..._activeQuery, 'cursor': state.nextCursor},
      );
      emit(
        state.copyWith(
          loading: false,
          records: [...state.records, ...page.records],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  Future<void> loadSetup() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      emit(state.copyWith(loading: false, steps: await _repository.setup()));
    } catch (e) {
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  Future<void> loadPermissions() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      emit(
        state.copyWith(
          loading: false,
          permissions: await _repository.permissions(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  Future<bool> submit(Future<void> Function() task) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await task();
      emit(state.copyWith(saving: false));
      return true;
    } catch (e) {
      emit(state.copyWith(saving: false, error: _message(e)));
      return false;
    }
  }

  Future<void> send(
    String method,
    String path, {
    JsonMap? body,
    String? refreshPath,
  }) async {
    await submit(() async {
      await _repository.send(method, path, body: body);
      if (refreshPath != null) await load(refreshPath);
    });
  }

  Future<void> delete(String path, {String? refreshPath}) async {
    await submit(() async {
      await _repository.delete(path);
      if (refreshPath != null) await load(refreshPath);
    });
  }

  Future<void> saveSpecial(
    Future<void> Function(AdminRepository repository) action,
  ) async {
    await submit(() => action(_repository));
  }

  Future<void> replaceCurriculum(
    JsonMap body,
    String year,
    String grade,
  ) async {
    final saved = await submit(() async {
      await _repository.replaceCurriculum(body);
    });
    if (!saved) return;
    await load(
      ApiEndpoints.curriculum,
      query: {'academic_year': year, 'grade_level': grade},
    );
  }

  Future<bool> replacePermissions(String id, JsonMap body) =>
      submit(() => _repository.replaceRolePermissions(id, body));
  Future<void> loadProfile(String path) async {
    emit(state.copyWith(loading: true, clearError: true, records: const []));
    try {
      emit(
        state.copyWith(loading: false, records: [await _repository.get(path)]),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  String _message(Object e) {
    if (e is ValidationFailure && e.errors.isNotEmpty) {
      final details = e.errors.entries
          .expand(
            (entry) => entry.value.map((message) => '${entry.key}: $message'),
          )
          .join('\n');
      return '${e.message}\n$details';
    }
    if (e is Failure) return e.message;
    return e.toString();
  }
}
