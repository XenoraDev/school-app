import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';

class TeacherYearSummaryModel {
  final String id;
  final String name;

  const TeacherYearSummaryModel({required this.id, required this.name});

  factory TeacherYearSummaryModel.fromJson(Map<String, dynamic> json) =>
      TeacherYearSummaryModel(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  TeacherYearSummary toEntity() => TeacherYearSummary(id: id, name: name);
}

class TeacherGradeLevelSummaryModel {
  final String id;
  final String name;

  const TeacherGradeLevelSummaryModel({required this.id, required this.name});

  factory TeacherGradeLevelSummaryModel.fromJson(Map<String, dynamic> json) =>
      TeacherGradeLevelSummaryModel(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  TeacherGradeLevelSummary toEntity() =>
      TeacherGradeLevelSummary(id: id, name: name);
}

class TeacherSectionSubjectModel {
  final String id;
  final String code;
  final String name;

  const TeacherSectionSubjectModel({
    required this.id,
    required this.code,
    required this.name,
  });

  factory TeacherSectionSubjectModel.fromJson(Map<String, dynamic> json) =>
      TeacherSectionSubjectModel(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
      );

  TeacherSectionSubject toEntity() =>
      TeacherSectionSubject(id: id, code: code, name: name);
}

class TeacherSectionModel {
  final String id;
  final String name;
  final String? room;
  final TeacherYearSummaryModel academicYear;
  final TeacherGradeLevelSummaryModel gradeLevel;
  final bool isClassTeacher;
  final List<TeacherSectionSubjectModel> subjects;

  const TeacherSectionModel({
    required this.id,
    required this.name,
    required this.room,
    required this.academicYear,
    required this.gradeLevel,
    required this.isClassTeacher,
    required this.subjects,
  });

  factory TeacherSectionModel.fromJson(
    Map<String, dynamic> json,
  ) => TeacherSectionModel(
    id: json['id'] as String,
    name: json['name'] as String,
    room: json['room'] as String?,
    academicYear: TeacherYearSummaryModel.fromJson(
      json['academic_year'] as Map<String, dynamic>,
    ),
    gradeLevel: TeacherGradeLevelSummaryModel.fromJson(
      json['grade_level'] as Map<String, dynamic>,
    ),
    isClassTeacher: json['is_class_teacher'] as bool,
    subjects: (json['subjects'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              TeacherSectionSubjectModel.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
  );

  TeacherSection toEntity() => TeacherSection(
    id: id,
    name: name,
    room: room,
    academicYear: academicYear.toEntity(),
    gradeLevel: gradeLevel.toEntity(),
    isClassTeacher: isClassTeacher,
    subjects: subjects.map((item) => item.toEntity()).toList(growable: false),
  );
}

class TeacherSubjectSectionModel {
  final String id;
  final String name;
  final TeacherGradeLevelSummaryModel gradeLevel;

  const TeacherSubjectSectionModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
  });

  factory TeacherSubjectSectionModel.fromJson(Map<String, dynamic> json) =>
      TeacherSubjectSectionModel(
        id: json['id'] as String,
        name: json['name'] as String,
        gradeLevel: TeacherGradeLevelSummaryModel.fromJson(
          json['grade_level'] as Map<String, dynamic>,
        ),
      );

  TeacherSubjectSection toEntity() => TeacherSubjectSection(
    id: id,
    name: name,
    gradeLevel: gradeLevel.toEntity(),
  );
}

class TeacherSubjectModel {
  final String id;
  final String code;
  final String name;
  final List<TeacherSubjectSectionModel> sections;

  const TeacherSubjectModel({
    required this.id,
    required this.code,
    required this.name,
    required this.sections,
  });

  factory TeacherSubjectModel.fromJson(
    Map<String, dynamic> json,
  ) => TeacherSubjectModel(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              TeacherSubjectSectionModel.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
  );

  TeacherSubject toEntity() => TeacherSubject(
    id: id,
    code: code,
    name: name,
    sections: sections.map((item) => item.toEntity()).toList(growable: false),
  );
}
