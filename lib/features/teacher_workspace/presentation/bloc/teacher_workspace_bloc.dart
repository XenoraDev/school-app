import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/teacher_workspace/domain/repositories/teacher_workspace_repository.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_event.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_state.dart';

class TeacherWorkspaceBloc
    extends Bloc<TeacherWorkspaceEvent, TeacherWorkspaceState> {
  final TeacherWorkspaceRepository _repository;

  /// Bumped by [TeacherWorkspaceReset]. A request keeps the value it started
  /// with and drops its result if the session changed while it was running.
  int _generation = 0;

  TeacherWorkspaceBloc({required TeacherWorkspaceRepository repository})
    : _repository = repository,
      super(const TeacherWorkspaceState()) {
    on<TeacherSectionsRequested>(_onSectionsRequested);
    on<TeacherSubjectsRequested>(_onSubjectsRequested);
    on<TeacherWorkspaceReset>(_onReset);
  }

  /// Ends the current session's workspace data. Requests still in flight are
  /// invalidated immediately (not when the queued event is handled), so a
  /// response that arrives in between can no longer emit the old account's
  /// data; the state itself is cleared by the queued [TeacherWorkspaceReset].
  void reset() {
    _generation++;
    add(const TeacherWorkspaceReset());
  }

  void _onReset(
    TeacherWorkspaceReset event,
    Emitter<TeacherWorkspaceState> emit,
  ) {
    // Also bumped here so that adding the event directly still invalidates.
    _generation++;
    emit(const TeacherWorkspaceState());
  }

  Future<void> _onSectionsRequested(
    TeacherSectionsRequested event,
    Emitter<TeacherWorkspaceState> emit,
  ) async {
    final generation = _generation;
    emit(
      state.copyWith(
        sectionsStatus: TeacherDataStatus.loading,
        clearSectionsError: true,
      ),
    );
    try {
      final sections = await _repository.getMySections();
      if (generation != _generation) return;
      emit(
        state.copyWith(
          sectionsStatus: TeacherDataStatus.success,
          sections: sections,
        ),
      );
    } on Failure catch (failure) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          sectionsStatus: TeacherDataStatus.failure,
          sectionsError: failure.message,
        ),
      );
    }
  }

  Future<void> _onSubjectsRequested(
    TeacherSubjectsRequested event,
    Emitter<TeacherWorkspaceState> emit,
  ) async {
    final generation = _generation;
    emit(
      state.copyWith(
        subjectsStatus: TeacherDataStatus.loading,
        clearSubjectsError: true,
      ),
    );
    try {
      final subjects = await _repository.getMySubjects();
      if (generation != _generation) return;
      emit(
        state.copyWith(
          subjectsStatus: TeacherDataStatus.success,
          subjects: subjects,
        ),
      );
    } on Failure catch (failure) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          subjectsStatus: TeacherDataStatus.failure,
          subjectsError: failure.message,
        ),
      );
    }
  }
}
