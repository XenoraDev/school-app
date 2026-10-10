import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/core/router/app_route_policy.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';

void main() {
  group('appRouteRedirect', () {
    test('signed-out visitors are sent to the root, which stays put', () {
      expect(appRouteRedirect(null, '/'), isNull);
      expect(appRouteRedirect(null, '/profile'), '/');
      expect(appRouteRedirect(null, '/admin/setup'), '/');
      expect(appRouteRedirect(null, '/teacher/sections'), '/');
    });

    test('the root sends every account type to its landing screen', () {
      expect(
        appRouteRedirect(_profile('staff', ['school.view']), '/'),
        '/admin/setup',
      );
      expect(
        appRouteRedirect(_profile('staff', ['subjects.view']), '/'),
        '/teacher/subjects',
      );
      expect(
        appRouteRedirect(_profile('teacher', ['classes.view']), '/'),
        '/teacher/sections',
      );
      expect(appRouteRedirect(_profile('parent', []), '/'), '/profile');
      expect(appRouteRedirect(_profile('student', []), '/'), '/profile');
    });

    test('every signed-in account can open account security', () {
      for (final type in ['staff', 'teacher', 'parent', 'student']) {
        expect(appRouteRedirect(_profile(type, []), '/profile/security'), isNull);
      }
      expect(appRouteRedirect(null, '/profile/security'), '/');
    });

    test('a teacher holding admin abilities is kept out of /admin', () {
      final teacher = _profile('teacher', [
        'school.view',
        'staff.view',
        'classes.view',
      ]);
      expect(appRouteRedirect(teacher, '/'), '/teacher/sections');
      expect(appRouteRedirect(teacher, '/admin/setup'), '/profile');
      expect(appRouteRedirect(teacher, '/admin/staff'), '/profile');
    });

    test('parents and students cannot open either workspace', () {
      for (final type in ['parent', 'student']) {
        final profile = _profile(type, ['school.view', 'classes.view']);
        expect(appRouteRedirect(profile, '/admin/setup'), '/profile');
        expect(appRouteRedirect(profile, '/teacher/sections'), '/profile');
        expect(appRouteRedirect(profile, '/profile'), isNull);
      }
    });

    test('staff with only teaching abilities cannot open /admin', () {
      final staff = _profile('staff', ['classes.view', 'subjects.view']);
      expect(appRouteRedirect(staff, '/admin/sections'), '/profile');
      expect(appRouteRedirect(staff, '/teacher/sections'), isNull);
    });

    test('a teaching route the profile lacks falls back to the other tab', () {
      final staff = _profile('staff', ['subjects.view']);
      expect(appRouteRedirect(staff, '/teacher/sections'), '/teacher/subjects');
    });

    test('admin routes pass when the profile holds the needed ability', () {
      final admin = _profile('staff', ['school.view', 'staff.view']);
      expect(appRouteRedirect(admin, '/admin/setup'), isNull);
      expect(appRouteRedirect(admin, '/admin/staff'), isNull);
    });

    group('/admin/setup without school.view', () {
      test('falls back to the first sidebar item the profile can open', () {
        expect(
          appRouteRedirect(_profile('staff', ['staff.view']), '/admin/setup'),
          '/admin/staff',
        );
        expect(
          appRouteRedirect(_profile('staff', ['roles.view']), '/admin/setup'),
          '/admin/roles',
        );
      });

      test('the first match follows sidebar order, not ability order', () {
        final profile = _profile('staff', ['roles.view', 'staff.view']);
        expect(appRouteRedirect(profile, '/admin/setup'), '/admin/staff');
      });

      test('other gated routes fall back the same way', () {
        final profile = _profile('staff', ['staff.view']);
        expect(appRouteRedirect(profile, '/admin/roles'), '/admin/staff');
        expect(appRouteRedirect(profile, '/admin/profile'), '/admin/staff');
      });

      test('a users.view-only account is kept out of /admin', () {
        final profile = _profile('staff', ['users.view']);
        expect(profile.canOpenAdminWorkspace, isFalse);
        expect(appRouteRedirect(profile, '/admin/setup'), '/profile');
        expect(appRouteRedirect(profile, '/'), '/profile');
      });
    });
  });

  group('adminRouteAbility', () {
    test('maps each admin route to the ability that gates it', () {
      expect(adminRouteAbility('/admin'), 'school.view');
      expect(adminRouteAbility('/admin/setup'), 'school.view');
      expect(adminRouteAbility('/admin/settings'), 'school.view');
      expect(adminRouteAbility('/admin/academic-years'), 'academic_years.view');
      expect(adminRouteAbility('/admin/terms'), 'academic_years.view');
      expect(adminRouteAbility('/admin/sections'), 'classes.view');
      expect(adminRouteAbility('/admin/curriculum'), 'subjects.view');
      expect(adminRouteAbility('/admin/staff'), 'staff.view');
      expect(adminRouteAbility('/admin/roles'), 'roles.view');
      expect(adminRouteAbility('/admin/unknown'), isNull);
    });
  });

  group('GoRouter wired to appRouteRedirect', () {
    Future<GoRouter> pumpRouter(
      WidgetTester tester,
      AccountProfile? profile,
      String initialLocation,
    ) async {
      Widget page(String name) => Scaffold(body: Text(name));
      final router = GoRouter(
        initialLocation: initialLocation,
        redirect: (context, state) => appRouteRedirect(profile, state.uri.path),
        routes: [
          GoRoute(path: '/', builder: (_, _) => page('login')),
          GoRoute(path: '/profile', builder: (_, _) => page('profile')),
          GoRoute(
            path: '/teacher/sections',
            builder: (_, _) => page('teacher-sections'),
          ),
          GoRoute(
            path: '/teacher/subjects',
            builder: (_, _) => page('teacher-subjects'),
          ),
          GoRoute(path: '/admin/setup', builder: (_, _) => page('admin-setup')),
          GoRoute(path: '/admin/staff', builder: (_, _) => page('admin-staff')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return router;
    }

    final cases = <String, (AccountProfile?, String)>{
      'signed out': (null, 'login'),
      'admin staff': (_profile('staff', ['school.view']), 'admin-setup'),
      'staff without school.view': (
        _profile('staff', ['staff.view']),
        'admin-staff',
      ),
      'staff with only subjects.view': (
        _profile('staff', ['subjects.view']),
        'teacher-subjects',
      ),
      'teacher with classes.view': (
        _profile('teacher', ['classes.view']),
        'teacher-sections',
      ),
      'parent': (_profile('parent', []), 'profile'),
      'student': (_profile('student', []), 'profile'),
    };
    for (final entry in cases.entries) {
      testWidgets('opening / shows the right screen for ${entry.key}', (
        tester,
      ) async {
        await pumpRouter(tester, entry.value.$1, '/');
        expect(find.text(entry.value.$2), findsOneWidget);
      });
    }

    testWidgets('a teacher deep-linking into /admin/setup ends on profile', (
      tester,
    ) async {
      await pumpRouter(
        tester,
        _profile('teacher', ['school.view', 'classes.view']),
        '/admin/setup',
      );
      expect(find.text('profile'), findsOneWidget);
    });
  });
}

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
