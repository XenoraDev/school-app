import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_bloc.dart';

/// Identifies the signed-in account, or `null` when nobody is signed in.
/// Two different accounts never share a key, and the key does not change on
/// unrelated auth updates for the same account.
String? workspaceSessionKey(AuthState state) => state is AuthAuthenticated
    ? '${state.profile.school.slug}:${state.profile.id}'
    : null;

/// Whether moving from [previous] to [current] must discard workspace data:
/// the session ended (logout, logout-all, session-ended, forced 401) or the
/// signed-in account changed directly (A to B). Starting a session from
/// nothing needs no reset: leaving the previous one already cleared it.
bool workspaceStateMustReset(AuthState previous, AuthState current) {
  final before = workspaceSessionKey(previous);
  return before != null && before != workspaceSessionKey(current);
}

/// Clears the teacher and admin workspace state, and drops their requests
/// still in flight, whenever the signed-in session ends or changes account.
/// Place it below the providers for [AuthBloc], [TeacherWorkspaceBloc] and
/// [AdminWorkspaceCubit].
class WorkspaceSessionGuard extends StatelessWidget {
  const WorkspaceSessionGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<AuthBloc, AuthState>(
    listenWhen: workspaceStateMustReset,
    listener: (context, _) {
      context.read<TeacherWorkspaceBloc>().reset();
      context.read<AdminWorkspaceCubit>().reset();
    },
    child: child,
  );
}
