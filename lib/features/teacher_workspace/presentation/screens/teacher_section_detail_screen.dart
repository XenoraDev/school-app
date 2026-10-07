import 'package:flutter/material.dart';
import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';

class TeacherSectionDetailScreen extends StatelessWidget {
  const TeacherSectionDetailScreen({required this.section, super.key});
  final TeacherSection section;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(section.name)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          section.gradeLevel.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Academic year: ${section.academicYear.name}'),
        if (section.room != null && section.room!.isNotEmpty)
          Text('Room: ${section.room}'),
        if (section.isClassTeacher)
          const ListTile(
            leading: Icon(Icons.star),
            title: Text('You are the class teacher'),
          ),
        const SizedBox(height: 12),
        Text('Subjects', style: Theme.of(context).textTheme.titleLarge),
        if (section.subjects.isEmpty)
          const ListTile(
            title: Text('No subjects are included in this section assignment.'),
          ),
        ...section.subjects.map(
          (subject) =>
              ListTile(title: Text(subject.name), subtitle: Text(subject.code)),
        ),
      ],
    ),
  );
}
