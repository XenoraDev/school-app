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

  /// Bumped by [reset]. Every async operation remembers the value it started
  /// with and drops its result if the session has changed in the meantime, so
  /// a response for a previous account can never land in the current state.
  int _generation = 0;

  /// Bumped by every operation that replaces the list (`load`, `loadProfile`).
  /// `load`, `loadMore` and `loadProfile` drop their result when a newer
  /// list request has started, so a late page for an earlier filter can never
  /// be appended to, or overwrite, the list the user is looking at now.
  int _listRequest = 0;

  /// Returns the cubit to its initial state and invalidates every request that
  /// is still in flight. Makes no API call. Call it when the session ends or
  /// the signed-in account changes.
  void reset() {
    _generation++;
    _activePath = null;
    _activeQuery = const {};
    emit(const AdminWorkspaceState());
  }

  Future<List<AdminRecord>> fetchRecords(String path) => _repository.list(path);

  /// Reads every page of a collection (100 per page, at most [maxPages]) for
  /// pickers and name lookups. Does not touch the cubit state.
  Future<List<AdminRecord>> fetchAll(
    String path, {
    Map<String, dynamic>? query,
    int maxPages = 50,
  }) async {
    final records = <AdminRecord>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final result = await _repository.listPage(
        path,
        query: {...?query, 'per_page': 100, 'cursor': ?cursor},
      );
      records.addAll(result.records);
      cursor = result.nextCursor;
      if (!result.hasMore || cursor == null) break;
    }
    return records;
  }
  Future<void> load(String path, {Map<String, dynamic>? query}) async {
    final generation = _generation;
    final request = ++_listRequest;
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
      if (generation != _generation || request != _listRequest) return;
      emit(
        state.copyWith(
          loading: false,
          records: page.records,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      if (generation != _generation || request != _listRequest) return;
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  Future<void> loadMore(String path) async {
    if (state.loading || !state.hasMore || state.nextCursor == null) return;
    final generation = _generation;
    final request = _listRequest;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final page = await _repository.listPage(
        _activePath ?? path,
        query: {..._activeQuery, 'cursor': state.nextCursor},
      );
      if (generation != _generation || request != _listRequest) return;
      emit(
        state.copyWith(
          loading: false,
          records: [...state.records, ...page.records],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      if (generation != _generation || request != _listRequest) return;
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  Future<void> loadSetup() async {
    final generation = _generation;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final steps = await _repository.setup();
      if (generation != _generation) return;
      emit(state.copyWith(loading: false, steps: steps));
    } catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  Future<void> loadPermissions() async {
    final generation = _generation;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final permissions = await _repository.permissions();
      if (generation != _generation) return;
      emit(state.copyWith(loading: false, permissions: permissions));
    } catch (e) {
      if (generation != _generation) return;
      emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  /// Runs a mutation. Returns `false` when it failed or when the session was
  /// reset while it ran (its result no longer belongs to this session).
  Future<bool> submit(Future<void> Function() task) async {
    final generation = _generation;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await task();
      if (generation != _generation) return false;
      emit(state.copyWith(saving: false));
      return true;
    } catch (e) {
      if (generation != _generation) return false;
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
    final generation = _generation;
    await submit(() async {
      await _repository.send(method, path, body: body);
      if (generation != _generation) return;
      if (refreshPath != null) await load(refreshPath);
    });
  }

  Future<void> delete(String path, {String? refreshPath}) async {
    final generation = _generation;
    await submit(() async {
      await _repository.delete(path);
      if (generation != _generation) return;
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
    final generation = _generation;
    final request = ++_listRequest;
    emit(state.copyWith(loading: true, clearError: true, records: const []));
    try {
      final record = await _repository.get(path);
      if (generation != _generation || request != _listRequest) return;
      emit(state.copyWith(loading: false, records: [record]));
    } catch (e) {
      if (generation != _generation || request != _listRequest) return;
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
