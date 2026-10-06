import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:school_app/core/config/env_config.dart';
import 'package:school_app/core/network/api_client.dart';
import 'package:school_app/core/storage/secure_storage_service.dart';
import 'package:school_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:school_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/domain/entities/mfa_enrollment_info.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SecureStorageService();
  late final AuthBloc authBloc;
  final client = ApiClient(
    config: EnvConfig.dev(),
    tokenProvider: storage,
    onUnauthorized: () => authBloc.add(const AuthForced401()),
  );
  authBloc = AuthBloc(
    repository: AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(client: client),
    ),
    storage: storage,
  )..add(const AuthAppStarted());
  runApp(SchoolApp(authBloc: authBloc));
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({required this.authBloc, super.key});
  final AuthBloc authBloc;

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: authBloc,
    child: MaterialApp(
      title: 'School App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const _AuthRouter(),
    ),
  );
}

class _AuthRouter extends StatelessWidget {
  const _AuthRouter();

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) {
      if (state is AuthAuthenticated) {
        return _HomeScreen(profile: state.profile);
      }
      if (state is AuthAwaitingMfa) {
        return _MfaVerifyScreen(message: state.message);
      }
      if (state is AuthAwaitingMfaEnrollment) {
        return _MfaEnrollmentScreen(
          startEnrollment: true,
          message: state.message,
        );
      }
      if (state is AuthMfaEnrollmentReady) {
        return _MfaEnrollmentScreen(info: state.info, message: state.message);
      }
      if (state is AuthMfaEnrollmentConfirmed) {
        return _RecoveryCodesScreen(state: state);
      }
      if (state is AuthSessionRestoring ||
          state is AuthInitial ||
          state is AuthLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return AuthLoginScreen(
        message: state is AuthFailure
            ? state.message
            : (state is AuthUnauthenticated ? state.message : null),
      );
    },
  );
}

class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({this.message, super.key});
  final String? message;
  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _school = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _school.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sign in')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Icon(Icons.school, size: 56),
              const SizedBox(height: 20),
              if (widget.message != null) _MessageBox(widget.message!),
              TextFormField(
                controller: _school,
                decoration: const InputDecoration(labelText: 'School slug'),
                textInputAction: TextInputAction.next,
                validator: _required,
              ),
              TextFormField(
                controller: _identifier,
                decoration: const InputDecoration(
                  labelText: 'Email or username',
                ),
                textInputAction: TextInputAction.next,
                validator: _required,
              ),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: _required,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
  void _submit() {
    if (!_form.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        school: _school.text.trim(),
        identifier: _identifier.text.trim(),
        password: _password.text,
      ),
    );
  }
}

class _MfaVerifyScreen extends StatefulWidget {
  const _MfaVerifyScreen({this.message});
  final String? message;
  @override
  State<_MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends State<_MfaVerifyScreen> {
  final _code = TextEditingController();
  bool _recovery = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify your identity')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.message != null) _MessageBox(widget.message!),
          TextField(
            controller: _code,
            decoration: InputDecoration(
              labelText: _recovery
                  ? 'Recovery code'
                  : '6-digit authenticator code',
            ),
            keyboardType: TextInputType.text,
          ),
          TextButton(
            onPressed: () => setState(() => _recovery = !_recovery),
            child: Text(
              _recovery ? 'Use authenticator code' : 'Use a recovery code',
            ),
          ),
          FilledButton(
            onPressed: () {
              final code = _code.text.trim();
              if (code.isEmpty) return;
              context.read<AuthBloc>().add(
                _recovery
                    ? AuthMfaVerifyRequested(recoveryCode: code)
                    : AuthMfaVerifyRequested(code: code),
              );
            },
            child: const Text('Verify'),
          ),
          TextButton(
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
            child: const Text('Cancel and sign out'),
          ),
        ],
      ),
    ),
  );
}

class _MfaEnrollmentScreen extends StatefulWidget {
  const _MfaEnrollmentScreen({
    this.info,
    this.startEnrollment = false,
    this.message,
  });
  final MfaEnrollmentInfo? info;
  final bool startEnrollment;
  final String? message;
  @override
  State<_MfaEnrollmentScreen> createState() => _MfaEnrollmentScreenState();
}

class _MfaEnrollmentScreenState extends State<_MfaEnrollmentScreen> {
  final _code = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.startEnrollment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AuthBloc>().add(const AuthMfaEnrollRequested());
        }
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up MFA')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: info == null
            ? widget.message == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MessageBox(widget.message!),
                        FilledButton(
                          onPressed: () => context.read<AuthBloc>().add(
                            const AuthMfaEnrollRequested(),
                          ),
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: () => context.read<AuthBloc>().add(
                            const AuthLogoutRequested(),
                          ),
                          child: const Text('Cancel and sign out'),
                        ),
                      ],
                    )
            : ListView(
                children: [
                  if (widget.message != null) _MessageBox(widget.message!),
                  const Text(
                    'Scan this code with an authenticator app, then enter the generated code.',
                  ),
                  const SizedBox(height: 16),
                  Center(child: QrImageView(data: info.uri, size: 210)),
                  SelectableText('Setup key: ${info.secret}'),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Authenticator code',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (_code.text.trim().isNotEmpty) {
                        context.read<AuthBloc>().add(
                          AuthMfaConfirmRequested(code: _code.text.trim()),
                        );
                      }
                    },
                    child: const Text('Confirm MFA'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RecoveryCodesScreen extends StatelessWidget {
  const _RecoveryCodesScreen({required this.state});
  final AuthMfaEnrollmentConfirmed state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Save recovery codes')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('These codes are shown once. Store them somewhere safe.'),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: state.recoveryCodes
                  .map(
                    (code) => SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                  .toList(),
            ),
          ),
          FilledButton(
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthAppStarted()),
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.profile});
  final AccountProfile profile;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(profile.school.name),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Hello, ${profile.name}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(profile.email),
        Text('Account type: ${profile.userType}'),
        const SizedBox(height: 20),
        const Text(
          'Permissions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (profile.abilities.isEmpty)
          const Text('No permissions were returned.')
        else
          ...profile.abilities.map(
            (ability) => ListTile(
              dense: true,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(ability),
            ),
          ),
      ],
    ),
  );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
