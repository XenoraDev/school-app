import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_bloc.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_event.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_state.dart';
import 'package:school_app/features/teacher_workspace/presentation/screens/teacher_section_detail_screen.dart';
import 'package:school_app/shared/feedback/error_state_view.dart';

class MySectionsScreen extends StatelessWidget {
  const MySectionsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TeacherWorkspaceBloc, TeacherWorkspaceState>(
        builder: (context, state) {
          if (state.sectionsStatus == TeacherDataStatus.initial ||
              state.sectionsStatus == TeacherDataStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.sectionsStatus == TeacherDataStatus.failure) {
            return ErrorStateView(
              title: 'Sections could not be loaded',
              message: state.sectionsError ?? 'Please try again.',
              onRetry: () => context.read<TeacherWorkspaceBloc>().add(
                const TeacherSectionsRequested(),
              ),
            );
          }
          if (state.sections.isEmpty) {
            return const _TeacherEmptyState(
              icon: Icons.class_outlined,
              title: 'No assigned sections',
              message: 'Your active section assignments will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.sections.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                TeacherSectionCard(section: state.sections[index]),
          );
        },
      );
}

class TeacherSectionCard extends StatelessWidget {
  const TeacherSectionCard({required this.section, super.key});
  final TeacherSection section;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeacherSectionDetailScreen(section: section),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (section.isClassTeacher)
                  const Chip(
                    label: Text('Class teacher'),
                    avatar: Icon(Icons.star, size: 18),
                  ),
              ],
            ),
            Text('${section.gradeLevel.name} · ${section.academicYear.name}'),
            if (section.room != null && section.room!.isNotEmpty)
              Text('Room ${section.room}'),
            if (section.subjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: section.subjects
                    .map((subject) => Chip(label: Text(subject.name)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TeacherEmptyState extends StatelessWidget {
  const _TeacherEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
