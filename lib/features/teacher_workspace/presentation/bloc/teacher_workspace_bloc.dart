import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/teacher_workspace/domain/repositories/teacher_workspace_repository.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_event.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_state.dart';

class TeacherWorkspaceBloc
    extends Bloc<TeacherWorkspaceEvent, TeacherWorkspaceState> {
  final TeacherWorkspaceRepository _repository;

  TeacherWorkspaceBloc({required TeacherWorkspaceRepository repository})
    : _repository = repository,
      super(const TeacherWorkspaceState()) {
    on<TeacherSectionsRequested>(_onSectionsRequested);
    on<TeacherSubjectsRequested>(_onSubjectsRequested);
  }

  Future<void> _onSectionsRequested(
    TeacherSectionsRequested event,
    Emitter<TeacherWorkspaceState> emit,
  ) async {
    emit(
      state.copyWith(
        sectionsStatus: TeacherDataStatus.loading,
        clearSectionsError: true,
      ),
    );
    try {
      final sections = await _repository.getMySections();
      emit(
        state.copyWith(
          sectionsStatus: TeacherDataStatus.success,
          sections: sections,
        ),
      );
    } on Failure catch (failure) {
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
    emit(
      state.copyWith(
        subjectsStatus: TeacherDataStatus.loading,
        clearSubjectsError: true,
      ),
    );
    try {
      final subjects = await _repository.getMySubjects();
      emit(
        state.copyWith(
          subjectsStatus: TeacherDataStatus.success,
          subjects: subjects,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          subjectsStatus: TeacherDataStatus.failure,
          subjectsError: failure.message,
        ),
      );
    }
  }
}
