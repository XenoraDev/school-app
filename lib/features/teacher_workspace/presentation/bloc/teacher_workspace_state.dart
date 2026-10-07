import 'package:equatable/equatable.dart';
import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';

enum TeacherDataStatus { initial, loading, success, failure }

class TeacherWorkspaceState extends Equatable {
  final TeacherDataStatus sectionsStatus;
  final List<TeacherSection> sections;
  final String? sectionsError;
  final TeacherDataStatus subjectsStatus;
  final List<TeacherSubject> subjects;
  final String? subjectsError;

  const TeacherWorkspaceState({
    this.sectionsStatus = TeacherDataStatus.initial,
    this.sections = const [],
    this.sectionsError,
    this.subjectsStatus = TeacherDataStatus.initial,
    this.subjects = const [],
    this.subjectsError,
  });

  TeacherWorkspaceState copyWith({
    TeacherDataStatus? sectionsStatus,
    List<TeacherSection>? sections,
    String? sectionsError,
    bool clearSectionsError = false,
    TeacherDataStatus? subjectsStatus,
    List<TeacherSubject>? subjects,
    String? subjectsError,
    bool clearSubjectsError = false,
  }) => TeacherWorkspaceState(
    sectionsStatus: sectionsStatus ?? this.sectionsStatus,
    sections: sections ?? this.sections,
    sectionsError: clearSectionsError
        ? null
        : sectionsError ?? this.sectionsError,
    subjectsStatus: subjectsStatus ?? this.subjectsStatus,
    subjects: subjects ?? this.subjects,
    subjectsError: clearSubjectsError
        ? null
        : subjectsError ?? this.subjectsError,
  );

  @override
  List<Object?> get props => [
    sectionsStatus,
    sections,
    sectionsError,
    subjectsStatus,
    subjects,
    subjectsError,
  ];
}
