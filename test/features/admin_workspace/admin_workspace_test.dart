import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/domain/repositories/admin_repository.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/features/admin_workspace/presentation/screens/admin_screens.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/data/models/account_profile_model.dart';
import 'package:school_app/features/auth/presentation/workspace_landing_policy.dart';
import 'package:school_app/features/teacher_workspace/presentation/teacher_route_policy.dart';

void main() {
  group('Phase 2B contracts', () {
    test(
      'endpoint constants use only the school APIs verified in backend routes',
      () {
        expect(ApiEndpoints.schoolSetup, '/school/setup');
        expect(ApiEndpoints.schoolProfile, '/school/profile');
        expect(ApiEndpoints.schoolSettings, '/school/settings');
        expect(ApiEndpoints.academicYears, '/school/academic-years');
        expect(ApiEndpoints.terms, '/school/terms');
        expect(ApiEndpoints.gradeLevels, '/school/grade-levels');
        expect(ApiEndpoints.sections, '/school/sections');
        expect(ApiEndpoints.subjects, '/school/subjects');
        expect(ApiEndpoints.curriculum, '/school/curriculum');
        expect(ApiEndpoints.staff, '/school/staff');
        expect(ApiEndpoints.roles, '/school/roles');
        expect(ApiEndpoints.permissions, '/school/permissions');
        expect(
          ApiEndpoints.rolePermissions('01abc'),
          '/school/roles/01abc/permissions',
        );
      },
    );

    test(
      'DTOs preserve server resource fields and parse setup and permission catalogue',
      () {
        final resource = AdminRecord.fromJson({
          'id': '01id',
          'name': 'Class 1',
          'sequence': 1,
        });
        expect(resource.values['sequence'], 1);
        expect(
          SetupStep.fromJson({'key': 'grade_levels', 'done': true}).done,
          isTrue,
        );
        final group = PermissionGroup.fromJson({
          'module': 'classes',
          'permissions': [
            {'name': 'classes.view', 'action': 'view'},
          ],
        });
        expect(group.permissions.single.name, 'classes.view');
      },
    );

    test(
      'admin workspace entry requires staff type and a readable admin ability',
      () {
        expect(_profile('staff', []).canOpenAdminWorkspace, isFalse);
        expect(_profile('staff', ['staff.view']).canOpenAdminWorkspace, isTrue);
        expect(
          _profile('staff', [
            'academic_years.view',
            'classes.view',
            'subjects.view',
          ]).canOpenAdminWorkspace,
          isFalse,
        );
        // users.view only gates reading a staff login inside the directory; it
        // opens no admin screen on its own (School Admin also holds school.view).
        expect(_profile('staff', ['users.view']).canOpenAdminWorkspace, isFalse);
        expect(_liveAdminProfile().canOpenAdminWorkspace, isTrue);
        expect(
          _profile('teacher', ['school.view']).canOpenAdminWorkspace,
          isFalse,
        );
        expect(
          _profile('staff', ['classes.view']).canOpenTeacherWorkspace,
          isTrue,
        );
      },
    );

    test('parses the live admin profile payload and its abilities', () {
      final profile = _liveAdminProfile();
      expect(profile.abilities, _liveAdminAbilities);
      expect(profile.userType, 'staff');
      expect(profile.school.status, 'active');
      expect(profile.canOpenAdminWorkspace, isTrue);
      expect(profile.canOpenTeacherWorkspace, isTrue);
    });

    group('authenticated landing path', () {
      test('dual access staff land in Admin', () {
        expect(authenticatedLandingPath(_liveAdminProfile()), '/admin/setup');
      });

      test('staff with only classes.view land in My sections', () {
        expect(
          authenticatedLandingPath(_profile('staff', ['classes.view'])),
          '/teacher/sections',
        );
      });

      test('staff with only subjects.view land in My subjects', () {
        final profile = _profile('staff', ['subjects.view']);
        expect(profile.canOpenAdminWorkspace, isFalse);
        expect(authenticatedLandingPath(profile), '/teacher/subjects');
      });

      test('staff without abilities land on the profile', () {
        expect(authenticatedLandingPath(_profile('staff', [])), '/profile');
      });

      test('teachers land in the teacher workspace', () {
        expect(
          authenticatedLandingPath(_profile('teacher', ['subjects.view'])),
          '/teacher/subjects',
        );
        expect(
          authenticatedLandingPath(_profile('teacher', ['classes.view'])),
          '/teacher/sections',
        );
      });

      test('a teacher holding admin abilities never lands in Admin', () {
        final profile = _profile('teacher', _liveAdminAbilities);
        expect(profile.canOpenAdminWorkspace, isFalse);
        expect(authenticatedLandingPath(profile), '/teacher/sections');
      });

      test('a teacher with only admin-only abilities lands on the profile', () {
        expect(
          authenticatedLandingPath(
            _profile('teacher', ['school.view', 'staff.view', 'roles.view']),
          ),
          '/profile',
        );
      });

      test('parents and students land on the profile, whatever they hold', () {
        for (final type in ['parent', 'student']) {
          expect(authenticatedLandingPath(_profile(type, [])), '/profile');
          expect(
            authenticatedLandingPath(_profile(type, _liveAdminAbilities)),
            '/profile',
            reason: '$type must not reach a workspace through abilities',
          );
        }
      });
    });

    test('profile navigation is not redirected into the teacher workspace', () {
      expect(
        teacherWorkspaceRouteRedirect(
          _profile('teacher', ['classes.view']),
          '/profile',
        ),
        isNull,
      );
      expect(
        teacherWorkspaceRouteRedirect(_profile('staff', []), '/profile'),
        isNull,
      );
      expect(
        teacherWorkspaceRouteRedirect(
          _profile('staff', []),
          '/teacher/sections',
        ),
        '/profile',
      );
    });
  });

  group('AdminWorkspaceCubit and checklist UI', () {
    test('loads server checklist and retries failures', () async {
      final repo = _FakeAdminRepository()..failSetupOnce = true;
      final cubit = AdminWorkspaceCubit(repo);
      addTearDown(cubit.close);
      await cubit.loadSetup();
      expect(cubit.state.error, 'Could not load setup');
      await cubit.loadSetup();
      expect(cubit.state.steps.map((s) => s.key), ['profile', 'academic_year']);
    });

    test('appends cursor pages while keeping active filters', () async {
      final repo = _FakeAdminRepository();
      final cubit = AdminWorkspaceCubit(repo);
      addTearDown(cubit.close);
      await cubit.load(ApiEndpoints.staff, query: {'filter[q]': 'Asha'});
      expect(cubit.state.hasMore, isTrue);
      await cubit.loadMore(ApiEndpoints.staff);
      expect(cubit.state.records.map((r) => r.id), ['01first', '01second']);
      expect(repo.queries.last, {'filter[q]': 'Asha', 'cursor': 'next-page'});
    });

    testWidgets('setup screen shows loading data and retryable errors', (
      tester,
    ) async {
      final cubit = AdminWorkspaceCubit(_FakeAdminRepository());
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const Scaffold(body: AdminSetupScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('School setup'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets(
      'creates staff, refreshes the directory, then reopens the record',
      (tester) async {
        final repository = _FakeAdminRepository()..staffRecords = const [];
        final cubit = AdminWorkspaceCubit(repository);
        addTearDown(cubit.close);
        final router = GoRouter(
          initialLocation: '/admin/staff',
          routes: [
            ShellRoute(
              builder: (context, state, child) => Scaffold(
                appBar: AppBar(
                  actions: [
                    IconButton(
                      key: const ValueKey('go-to-setup'),
                      onPressed: () => context.go('/admin/setup'),
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
                body: child,
              ),
              routes: [
                GoRoute(
                  path: '/admin/staff',
                  builder: (context, state) => const AdminResourceScreen(
                    title: 'Staff directory',
                    path: ApiEndpoints.staff,
                    searchable: true,
                    fields: [
                      AdminField(
                        'employee_no',
                        'Employee number',
                        required: true,
                        editable: false,
                      ),
                      AdminField('full_name', 'Full name', required: true),
                      AdminField(
                        'joined_on',
                        'Joined on',
                        nullable: true,
                        type: 'date',
                      ),
                    ],
                  ),
                ),
                GoRoute(
                  path: '/admin/setup',
                  builder: (context, state) => Center(
                    child: TextButton(
                      onPressed: () => context.go('/admin/staff'),
                      child: const Text('Open Staff Directory'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => BlocProvider.value(
              value: cubit,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No staff directory found.'), findsOneWidget);

        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Employee number'),
          'EMP-101',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Full name'),
          'Asha Staff',
        );
        await tester.tap(find.widgetWithText(TextFormField, 'Joined on'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(repository.sentBody?['employee_no'], 'EMP-101');
        expect(repository.sentBody?['full_name'], 'Asha Staff');
        expect(
          repository.sentBody?['joined_on'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        );
        expect(find.text('Asha Staff'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('go-to-setup')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Staff Directory'));
        await tester.pumpAndSettle();
        expect(find.text('Asha Staff'), findsOneWidget);
        await tester.tap(find.text('Asha Staff'));
        await tester.pumpAndSettle();
        expect(find.text('Edit Staff directory'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Asha Staff'), findsOneWidget);
      },
    );
  });
}

const _liveAdminAbilities = [
  'academic_years.view',
  'academic_years.manage',
  'users.view',
  'users.manage',
  'roles.view',
  'roles.manage',
  'audit.view',
  'school.view',
  'school.update',
  'settings.manage',
  'classes.view',
  'classes.manage',
  'subjects.view',
  'subjects.manage',
  'staff.view',
  'staff.create',
  'staff.update',
  'staff.archive',
  'teaching_assignments.manage',
];

AccountProfile _liveAdminProfile() => AccountProfileModel.fromJson({
  'data': {
    'id': 42,
    'kind': 'school',
    'name': 'School Admin',
    'email': 'admin@example.test',
    'user_type': 'staff',
    'school': {
      'name': 'Example School',
      'slug': 'sc-101',
      'status': 'active',
    },
    'abilities': _liveAdminAbilities,
    'email_verified': true,
    'mfa_enabled': true,
    'mfa_required': true,
  },
}).toEntity();

AccountProfile _profile(String type, List<String> abilities) => AccountProfile(
  id: 1,
  kind: 'school',
  name: 'Asha',
  email: 'asha@example.test',
  userType: type,
  school: const SchoolInfo(name: 'Example', slug: 'example', status: 'active'),
  abilities: abilities,
  emailVerified: true,
  mfaEnabled: true,
  mfaRequired: false,
);

class _FakeAdminRepository implements AdminRepository {
  bool failSetupOnce = false;
  final List<Map<String, dynamic>?> queries = [];
  List<AdminRecord>? staffRecords;
  JsonMap? sentBody;
  @override
  Future<List<AdminRecord>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => [];
  @override
  Future<AdminPage> listPage(String path, {Map<String, dynamic>? query}) async {
    queries.add(query);
    if (path == ApiEndpoints.staff && staffRecords != null) {
      return AdminPage(records: staffRecords!);
    }
    if (query?['cursor'] == 'next-page') {
      return AdminPage(
        records: [
          AdminRecord.fromJson({'id': '01second', 'name': 'B'}),
        ],
      );
    }
    return AdminPage(
      records: [
        AdminRecord.fromJson({'id': '01first', 'name': 'A'}),
      ],
      nextCursor: 'next-page',
      hasMore: true,
    );
  }

  @override
  Future<AdminRecord> get(String path) async =>
      AdminRecord.fromJson({'id': '01role', 'permissions': <String>[]});
  @override
  Future<AdminRecord> send(String method, String path, {JsonMap? body}) async {
    sentBody = body;
    final record = AdminRecord.fromJson({
      'id': '01created',
      'employee_no': body?['employee_no'],
      'full_name': body?['full_name'],
      'joined_on': body?['joined_on'],
      'version': 1,
    });
    if (path == ApiEndpoints.staff) staffRecords = [record];
    return record;
  }

  @override
  Future<void> delete(String path) async {}
  @override
  Future<List<SetupStep>> setup() async {
    if (failSetupOnce) {
      failSetupOnce = false;
      throw const NetworkFailure(message: 'Could not load setup');
    }
    return const [
      SetupStep(key: 'profile', done: false),
      SetupStep(key: 'academic_year', done: true),
    ];
  }

  @override
  Future<List<PermissionGroup>> permissions() async => const [];
  @override
  Future<List<AdminRecord>> replaceCurriculum(JsonMap body) async => const [];
  @override
  Future<List<AdminRecord>> updateSettings(JsonMap body) async => const [];
  @override
  Future<List<AdminRecord>> replaceRolePermissions(
    String id,
    JsonMap body,
  ) async => const [];
}
