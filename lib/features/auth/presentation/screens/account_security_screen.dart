import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/account_security_cubit.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';

/// Change password and sign out of every device. Needs an [AuthBloc] and an
/// [AccountSecurityCubit] above it. Password rules are enforced by the API and
/// its messages are shown as returned.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    unawaited(
      context.read<AccountSecurityCubit>().changePassword(
        currentPassword: _current.text,
        password: _password.text,
        passwordConfirmation: _confirmation.text,
      ),
    );
  }

  Future<void> _confirmSignOutEverywhere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign out of all devices?'),
        content: const Text(
          'Every session for this account ends, including this device. '
          'You will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Sign out everywhere'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      unawaited(context.read<AccountSecurityCubit>().signOutEverywhere());
    }
  }

  void _onState(BuildContext context, AccountSecurityState state) {
    final message = switch (state.status) {
      AccountSecurityStatus.passwordChanged =>
        'Your password was changed. Sign in again with the new password.',
      AccountSecurityStatus.signedOutEverywhere =>
        'You were signed out of all devices.',
      _ => null,
    };
    if (message != null) {
      context.read<AuthBloc>().add(AuthSessionEnded(message));
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<AccountSecurityCubit, AccountSecurityState>(
        listener: _onState,
        builder: (context, state) {
          final busy = state.submitting || state.completed;
          return Scaffold(
            appBar: AppBar(title: const Text('Account security')),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Change password',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'You will be signed out on every device afterwards. '
                  'Your school\'s password policy applies.',
                ),
                const SizedBox(height: 16),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      _PasswordField(
                        controller: _current,
                        label: 'Current password',
                        enabled: !busy,
                        serverError: state.fieldErrors['current_password'],
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      _PasswordField(
                        controller: _password,
                        label: 'New password',
                        enabled: !busy,
                        serverError: state.fieldErrors['password'],
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      _PasswordField(
                        controller: _confirmation,
                        label: 'Confirm new password',
                        enabled: !busy,
                        serverError: state.fieldErrors['password_confirmation'],
                        validator: (v) => v != _password.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                    ],
                  ),
                ),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      state.message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: state.submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change password'),
                ),
                const Divider(height: 48),
                Text(
                  'Sign out of all devices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ends every session for this account, including this one.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy ? null : _confirmSignOutEverywhere,
                  icon: const Icon(Icons.devices_other),
                  label: const Text('Sign out everywhere'),
                ),
              ],
            ),
          );
        },
      );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.validator,
    this.serverError,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final List<String>? serverError;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        errorText: serverError?.join(' '),
      ),
      validator: validator,
    ),
  );
}
