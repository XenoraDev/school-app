import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:school_app/core/config/env_config.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/router/app_route_policy.dart';
import 'package:school_app/core/session/workspace_session_guard.dart';
import 'package:school_app/core/network/api_client.dart';
import 'package:school_app/core/storage/secure_storage_service.dart';
import 'package:school_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:school_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/domain/entities/mfa_enrollment_info.dart';
import 'package:school_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_app/features/auth/presentation/bloc/account_security_cubit.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:school_app/features/auth/presentation/screens/account_security_screen.dart';
import 'package:school_app/features/admin_workspace/data/datasources/admin_remote_data_source.dart';
import 'package:school_app/features/admin_workspace/data/repositories/admin_repository_impl.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/features/admin_workspace/presentation/screens/admin_screens.dart';
import 'package:school_app/features/admin_workspace/presentation/screens/admin_special_screens.dart';
import 'package:school_app/features/teacher_workspace/data/datasources/teacher_workspace_remote_data_source.dart';
import 'package:school_app/features/teacher_workspace/data/repositories/teacher_workspace_repository_impl.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_bloc.dart';
import 'package:school_app/features/teacher_workspace/presentation/screens/my_sections_screen.dart';
import 'package:school_app/features/teacher_workspace/presentation/screens/my_subjects_screen.dart';
import 'package:school_app/features/teacher_workspace/presentation/screens/teacher_workspace_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SecureStorageService();
  late final AuthBloc authBloc;
  final client = ApiClient(
    config: EnvConfig.dev(),
    tokenProvider: storage,
    onUnauthorized: () => authBloc.add(const AuthForced401()),
  );
  final authRepository = AuthRepositoryImpl(
    remote: AuthRemoteDataSourceImpl(client: client),
  );
  authBloc = AuthBloc(repository: authRepository, storage: storage)
    ..add(const AuthAppStarted());
  final teacherBloc = TeacherWorkspaceBloc(
    repository: TeacherWorkspaceRepositoryImpl(
      remote: TeacherWorkspaceRemoteDataSourceImpl(client: client),
    ),
  );
  final adminCubit = AdminWorkspaceCubit(
    AdminRepositoryImpl(remote: AdminRemoteDataSourceImpl(client: client)),
  );
  runApp(
    SchoolApp(
      authBloc: authBloc,
      authRepository: authRepository,
      teacherBloc: teacherBloc,
      adminCubit: adminCubit,
    ),
  );
}

class SchoolApp extends StatefulWidget {
  const SchoolApp({
    required this.authBloc,
    required this.authRepository,
    required this.teacherBloc,
    required this.adminCubit,
    super.key,
  });
  final AuthBloc authBloc;
  final AuthRepository authRepository;
  final TeacherWorkspaceBloc teacherBloc;
  final AdminWorkspaceCubit adminCubit;

  @override
  State<SchoolApp> createState() => _SchoolAppState();
}

class _SchoolAppState extends State<SchoolApp> {
  late final _AuthRefreshNotifier _refreshNotifier = _AuthRefreshNotifier(
    widget.authBloc,
  );
  late final GoRouter _router = _createRouter();

  GoRouter _createRouter() => GoRouter(
    initialLocation: '/',
    refreshListenable: _refreshNotifier,
    redirect: (context, routeState) {
      final authState = widget.authBloc.state;
      return appRouteRedirect(
        authState is AuthAuthenticated ? authState.profile : null,
        routeState.uri.path,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _AuthRouter()),
      GoRoute(
        path: '/profile',
        builder: (context, state) {
          final authState = widget.authBloc.state;
          return authState is AuthAuthenticated
              ? _HomeScreen(profile: authState.profile)
              : const _AuthRouter();
        },
      ),
      GoRoute(
        path: '/profile/security',
        builder: (context, state) => BlocProvider(
          create: (_) => AccountSecurityCubit(widget.authRepository),
          child: const AccountSecurityScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final authState = widget.authBloc.state;
          if (authState is! AuthAuthenticated) return const _AuthRouter();
          return TeacherWorkspaceShell(
            profile: authState.profile,
            navigationShell: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/sections',
                builder: (context, state) => const MySectionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/subjects',
                builder: (context, state) => const MySubjectsScreen(),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) {
          final authState = widget.authBloc.state;
          if (authState is! AuthAuthenticated) return const _AuthRouter();
          return AdminWorkspaceShell(profile: authState.profile, child: child);
        },
        routes: [
          GoRoute(path: '/admin', redirect: (context, state) => '/admin/setup'),
          GoRoute(
            path: '/admin/setup',
            builder: (_, state) => const AdminSetupScreen(),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (context, state) => AdminResourceScreen(
              title: 'School profile',
              path: ApiEndpoints.schoolProfile,
              create: false,
              canEdit: _hasAbility(context, 'school.update'),
              updatePath: ApiEndpoints.schoolProfile,
              singleResource: true,
              fields: [
                AdminField('address_line1', 'Address line 1'),
                AdminField('address_line2', 'Address line 2', nullable: true),
                AdminField('city', 'City', nullable: true),
                AdminField('state', 'State', nullable: true),
                AdminField('postal_code', 'Postal code', nullable: true),
                AdminField('country', 'Country'),
                AdminField('phone', 'Phone', nullable: true),
                AdminField('email', 'Email', nullable: true),
                AdminField('website', 'Website', nullable: true),
                AdminField(
                  'affiliation_board',
                  'Affiliation board',
                  nullable: true,
                ),
                AdminField(
                  'affiliation_number',
                  'Affiliation number',
                  nullable: true,
                ),
                AdminField(
                  'established_year',
                  'Established year',
                  type: 'int',
                  nullable: true,
                ),
              ],
            ),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => SchoolSettingsScreen(
              canManage: _hasAbility(context, 'settings.manage'),
            ),
          ),
          GoRoute(
            path: '/admin/academic-years',
            builder: (context, state) => AdminResourceScreen(
              title: 'Academic years',
              path: ApiEndpoints.academicYears,
              create: _hasAbility(context, 'academic_years.manage'),
              canEdit: _hasAbility(context, 'academic_years.manage'),
              fields: const [
                AdminField('name', 'Name', required: true),
                AdminField(
                  'start_date',
                  'Start date (YYYY-MM-DD)',
                  required: true,
                ),
                AdminField('end_date', 'End date (YYYY-MM-DD)', required: true),
              ],
              actions: _hasAbility(context, 'academic_years.manage')
                  ? [
                      AdminAction(
                        'Activate',
                        'activate',
                        (path, id) => ApiEndpoints.academicYearActivate(id),
                      ),
                      AdminAction(
                        'Close',
                        'close',
                        (path, id) => ApiEndpoints.academicYearClose(id),
                      ),
                    ]
                  : const [],
            ),
          ),
          GoRoute(
            path: '/admin/terms',
            builder: (context, state) => AdminResourceScreen(
              title: 'Terms',
              path: ApiEndpoints.terms,
              create: _hasAbility(context, 'academic_years.manage'),
              canEdit: _hasAbility(context, 'academic_years.manage'),
              fields: [
                AdminField('academic_year', 'Academic year ID', required: true),
                AdminField('name', 'Name', required: true),
                AdminField(
                  'start_date',
                  'Start date (YYYY-MM-DD)',
                  required: true,
                ),
                AdminField('end_date', 'End date (YYYY-MM-DD)', required: true),
              ],
              actions: _hasAbility(context, 'academic_years.manage')
                  ? [
                      AdminAction(
                        'Delete',
                        'delete',
                        (path, id) => ApiEndpoints.term(id),
                      ),
                    ]
                  : const [],
            ),
          ),
          GoRoute(
            path: '/admin/grade-levels',
            builder: (context, state) => AdminResourceScreen(
              title: 'Grade levels',
              path: ApiEndpoints.gradeLevels,
              create: _hasAbility(context, 'classes.manage'),
              canEdit: _hasAbility(context, 'classes.manage'),
              canReorder: _hasAbility(context, 'classes.manage'),
              fields: const [
                AdminField('name', 'Name', required: true),
                AdminField(
                  'stage',
                  'Stage (pre_primary, primary, middle, secondary)',
                  required: true,
                ),
              ],
              actions: _hasAbility(context, 'classes.manage')
                  ? [
                      AdminAction(
                        'Archive',
                        'archive',
                        (path, id) => ApiEndpoints.gradeLevelArchive(id),
                      ),
                      AdminAction(
                        'Unarchive',
                        'unarchive',
                        (path, id) => ApiEndpoints.gradeLevelUnarchive(id),
                      ),
                    ]
                  : const [],
            ),
          ),
          GoRoute(
            path: '/admin/sections',
            builder: (context, state) => AdminResourceScreen(
              title: 'Sections',
              path: ApiEndpoints.sections,
              create: _hasAbility(context, 'classes.manage'),
              canEdit: _hasAbility(context, 'classes.manage'),
              fields: [
                AdminField(
                  'academic_year',
                  'Academic year ID',
                  required: true,
                  editable: false,
                ),
                AdminField(
                  'grade_level',
                  'Grade level ID',
                  required: true,
                  editable: false,
                ),
                AdminField('name', 'Name', required: true),
                AdminField('capacity', 'Capacity', type: 'int', nullable: true),
                AdminField('room', 'Room', nullable: true),
              ],
              actions: _hasAbility(context, 'classes.manage')
                  ? [
                      AdminAction(
                        'Close',
                        'close',
                        (path, id) => ApiEndpoints.sectionsClose(id),
                      ),
                      AdminAction(
                        'Reopen',
                        'reopen',
                        (path, id) => ApiEndpoints.sectionsReopen(id),
                      ),
                      AdminAction(
                        'Set class teacher',
                        'class-teacher',
                        (path, id) => ApiEndpoints.sectionClassTeacher(id),
                      ),
                    ]
                  : const [],
            ),
          ),
          GoRoute(
            path: '/admin/subjects',
            builder: (context, state) => AdminResourceScreen(
              title: 'Subjects',
              path: ApiEndpoints.subjects,
              searchable: true,
              create: _hasAbility(context, 'subjects.manage'),
              canEdit: _hasAbility(context, 'subjects.manage'),
              fields: const [
                AdminField('code', 'Code', required: true, editable: false),
                AdminField('name', 'Name', required: true),
                AdminField(
                  'type',
                  'Type (core, elective, co_scholastic)',
                  required: true,
                ),
              ],
              actions: _hasAbility(context, 'subjects.manage')
                  ? [
                      AdminAction(
                        'Archive',
                        'archive',
                        (path, id) => ApiEndpoints.subjectArchive(id),
                      ),
                      AdminAction(
                        'Unarchive',
                        'unarchive',
                        (path, id) => ApiEndpoints.subjectUnarchive(id),
                      ),
                    ]
                  : const [],
            ),
          ),
          GoRoute(
            path: '/admin/curriculum',
            builder: (context, state) => CurriculumScreen(
              canManage: _hasAbility(context, 'subjects.manage'),
            ),
          ),
          GoRoute(
            path: '/admin/staff',
            builder: (context, state) => AdminResourceScreen(
              title: 'Staff directory',
              path: ApiEndpoints.staff,
              searchable: true,
              create: _hasAbility(context, 'staff.create'),
              canEdit: _hasAbility(context, 'staff.update'),
              fields: const [
                AdminField(
                  'employee_no',
                  'Employee number',
                  required: true,
                  editable: false,
                ),
                AdminField('full_name', 'Full name', required: true),
                AdminField('email', 'Email', nullable: true),
                AdminField('phone', 'Phone', nullable: true),
                AdminField('designation', 'Designation', nullable: true),
                AdminField('department', 'Department', nullable: true),
                AdminField(
                  'is_teaching',
                  'Teaching staff (true/false)',
                  type: 'bool',
                ),
                AdminField(
                  'joined_on',
                  'Joined on',
                  nullable: true,
                  type: 'date',
                ),
                AdminField('left_on', 'Left on', nullable: true, type: 'date'),
              ],
              actions: [
                if (_hasAbility(context, 'users.manage')) ...[
                  AdminAction(
                    'Disable login',
                    'disable-login',
                    (path, id) => ApiEndpoints.staffDisableLogin(id),
                  ),
                  AdminAction(
                    'Enable login',
                    'enable-login',
                    (path, id) => ApiEndpoints.staffEnableLogin(id),
                  ),
                ],
                if (_hasAbility(context, 'staff.archive')) ...[
                  AdminAction(
                    'Archive',
                    'archive',
                    (path, id) => ApiEndpoints.staffArchive(id),
                  ),
                  AdminAction(
                    'Unarchive',
                    'unarchive',
                    (path, id) => ApiEndpoints.staffUnarchive(id),
                  ),
                ],
              ],
            ),
          ),
          GoRoute(
            path: '/admin/roles',
            builder: (context, state) =>
                RolesScreen(canManage: _hasAbility(context, 'roles.manage')),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'School App',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    routerConfig: _router,
    builder: (context, child) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: widget.authBloc),
        BlocProvider.value(value: widget.teacherBloc),
        BlocProvider.value(value: widget.adminCubit),
      ],
      child: WorkspaceSessionGuard(child: child ?? const SizedBox.shrink()),
    ),
  );
}

bool _hasAbility(BuildContext context, String ability) {
  final state = context.read<AuthBloc>().state;
  return state is AuthAuthenticated && state.profile.can(ability);
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(AuthBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _AuthRouter extends StatelessWidget {
  const _AuthRouter();

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) {
      if (state is AuthAuthenticated) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/profile/security'),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Account security'),
          ),
        ),
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
