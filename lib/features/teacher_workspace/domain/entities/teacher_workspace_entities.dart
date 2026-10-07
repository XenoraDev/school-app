import 'package:equatable/equatable.dart';

class TeacherYearSummary extends Equatable {
  final String id;
  final String name;

  const TeacherYearSummary({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

class TeacherGradeLevelSummary extends Equatable {
  final String id;
  final String name;

  const TeacherGradeLevelSummary({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

class TeacherSectionSubject extends Equatable {
  final String id;
  final String code;
  final String name;

  const TeacherSectionSubject({
    required this.id,
    required this.code,
    required this.name,
  });

  @override
  List<Object?> get props => [id, code, name];
}

class TeacherSection extends Equatable {
  final String id;
  final String name;
  final String? room;
  final TeacherYearSummary academicYear;
  final TeacherGradeLevelSummary gradeLevel;
  final bool isClassTeacher;
  final List<TeacherSectionSubject> subjects;

  const TeacherSection({
    required this.id,
    required this.name,
    required this.room,
    required this.academicYear,
    required this.gradeLevel,
    required this.isClassTeacher,
    required this.subjects,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    room,
    academicYear,
    gradeLevel,
    isClassTeacher,
    subjects,
  ];
}

class TeacherSubjectSection extends Equatable {
  final String id;
  final String name;
  final TeacherGradeLevelSummary gradeLevel;

  const TeacherSubjectSection({
    required this.id,
    required this.name,
    required this.gradeLevel,
  });

  @override
  List<Object?> get props => [id, name, gradeLevel];
}

class TeacherSubject extends Equatable {
  final String id;
  final String code;
  final String name;
  final List<TeacherSubjectSection> sections;

  const TeacherSubject({
    required this.id,
    required this.code,
    required this.name,
    required this.sections,
  });

  @override
  List<Object?> get props => [id, code, name, sections];
}
