import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_bloc.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_event.dart';

class TeacherWorkspaceShell extends StatefulWidget {
  const TeacherWorkspaceShell({
    required this.profile,
    required this.navigationShell,
    super.key,
  });

  final AccountProfile profile;
  final StatefulNavigationShell navigationShell;

  @override
  State<TeacherWorkspaceShell> createState() => _TeacherWorkspaceShellState();
}

class _TeacherWorkspaceShellState extends State<TeacherWorkspaceShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<TeacherWorkspaceBloc>();
      if (widget.profile.can('classes.view')) {
        bloc.add(const TeacherSectionsRequested());
      }
      if (widget.profile.can('subjects.view')) {
        bloc.add(const TeacherSubjectsRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <(int, NavigationDestination)>[];
    if (widget.profile.can('classes.view')) {
      destinations.add((
        0,
        const NavigationDestination(
          icon: Icon(Icons.class_outlined),
          selectedIcon: Icon(Icons.class_),
          label: 'Sections',
        ),
      ));
    }
    if (widget.profile.can('subjects.view')) {
      destinations.add((
        1,
        const NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Subjects',
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.school.name),
        actions: [
          IconButton(
            tooltip: 'Account security',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => context.push('/profile/security'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: destinations.length < 2
          ? null
          : NavigationBar(
              selectedIndex: destinations.indexWhere(
                (entry) => entry.$1 == widget.navigationShell.currentIndex,
              ),
              destinations: destinations.map((entry) => entry.$2).toList(),
              onDestinationSelected: (index) =>
                  widget.navigationShell.goBranch(destinations[index].$1),
            ),
    );
  }
}
