import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_bloc.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_event.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_state.dart';
import 'package:school_app/shared/feedback/error_state_view.dart';

class MySubjectsScreen extends StatelessWidget {
  const MySubjectsScreen({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TeacherWorkspaceBloc, TeacherWorkspaceState>(
    builder: (context, state) {
      if (state.subjectsStatus == TeacherDataStatus.initial ||
          state.subjectsStatus == TeacherDataStatus.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.subjectsStatus == TeacherDataStatus.failure) {
        return ErrorStateView(
          title: 'Subjects could not be loaded',
          message: state.subjectsError ?? 'Please try again.',
          onRetry: () => context.read<TeacherWorkspaceBloc>().add(
            const TeacherSubjectsRequested(),
          ),
        );
      }
      if (state.subjects.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, size: 52),
                SizedBox(height: 12),
                Text('No assigned subjects', style: TextStyle(fontSize: 20)),
                SizedBox(height: 6),
                Text(
                  'Your active subject assignments will appear here.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.subjects.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final subject = state.subjects[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    subject.code,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (subject.sections.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Assigned sections'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: subject.sections
                          .map(
                            (section) => Chip(
                              label: Text(
                                '${section.name} · ${section.gradeLevel.name}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
