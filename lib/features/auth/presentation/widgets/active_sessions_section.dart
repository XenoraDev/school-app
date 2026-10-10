import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/features/auth/domain/entities/active_token.dart';
import 'package:school_app/features/auth/presentation/bloc/active_sessions_cubit.dart';

/// The account's active sessions, with a revoke action for the other ones.
/// Needs an [ActiveSessionsCubit] above it. The server decides what may be
/// revoked; the current session is never offered here.
class ActiveSessionsSection extends StatelessWidget {
  const ActiveSessionsSection({super.key});

  Future<void> _confirmRevoke(BuildContext context, ActiveToken session) async {
    final cubit = context.read<ActiveSessionsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign out this session?'),
        content: Text(
          'The session "${session.name}" ends and its device needs to sign in '
          'again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Sign out session'),
          ),
        ],
      ),
    );
    if (confirmed == true) unawaited(cubit.revoke(session));
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ActiveSessionsCubit, ActiveSessionsState>(
        listenWhen: (previous, state) =>
            state.message != null && state.message != previous.message,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Active sessions',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh sessions',
                    onPressed: state.loading || state.saving
                        ? null
                        : () => unawaited(
                            context.read<ActiveSessionsCubit>().load(),
                          ),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const Text('Devices currently signed in to this account.'),
              const SizedBox(height: 12),
              if (state.loading && state.sessions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.loadError != null && state.sessions.isEmpty)
                _LoadError(message: state.loadError!)
              else ...[
                if (state.loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      state.loadError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                if (state.sessions.isEmpty)
                  const Text('No active sessions.')
                else
                  for (final session in state.sessions)
                    _SessionTile(
                      session: session,
                      revoking: state.revokingId == session.id,
                      // One change at a time, and not while the list reloads.
                      enabled: !state.saving && !state.loading,
                      onRevoke: () => _confirmRevoke(context, session),
                    ),
              ],
            ],
          );
        },
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => unawaited(context.read<ActiveSessionsCubit>().load()),
        child: const Text('Retry'),
      ),
    ],
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.revoking,
    required this.enabled,
    required this.onRevoke,
  });

  final ActiveToken session;
  final bool revoking;
  final bool enabled;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(session.isCurrent ? Icons.smartphone : Icons.devices_other),
      title: Text(session.name),
      subtitle: Text(
        'Signed in: ${_formatDate(session.createdAt)}\n'
        'Last used: ${_formatDate(session.lastUsedAt, empty: 'Never')}\n'
        'Expires: ${_formatDate(session.expiresAt, empty: 'No expiry')}',
      ),
      isThreeLine: true,
      trailing: session.isCurrent
          ? const Chip(label: Text('This device'))
          : revoking
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: enabled ? onRevoke : null,
              child: const Text('Sign out'),
            ),
    ),
  );
}

/// `2026-10-10 14:05` in the device's time zone.
String _formatDate(DateTime? value, {String empty = 'Unknown'}) {
  if (value == null) return empty;
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
