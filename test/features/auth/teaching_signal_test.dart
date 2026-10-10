import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/router/app_route_policy.dart';
import 'package:school_app/features/auth/data/models/account_profile_model.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/presentation/workspace_landing_policy.dart';
import 'package:school_app/features/teacher_workspace/presentation/teacher_route_policy.dart';

/// The `data` of `GET /common/me` for a school account, in the shape Laravel
/// returns it (AccountResource, PR #10): the existing fields plus `is_teaching`.
Map<String, dynamic> _meJson({
  String userType = 'staff',
  List<String> abilities = const ['classes.view', 'subjects.view'],
  Object? isTeaching = const _Absent(),
}) => {
  'id': 15,
  'kind': 'school',
  'name': 'Jane Smith',
  'email': 'jane@springfield.edu',
  'user_type': userType,
  'school': {'name': 'Springfield High', 'slug': 'springfield', 'status': 'active'},
  'abilities': abilities,
  'email_verified': true,
  'mfa_enabled': false,
  'mfa_required': false,
  if (isTeaching is! _Absent) 'is_teaching': isTeaching,
};

class _Absent {
  const _Absent();
}

AccountProfile _profile(
  String type,
  List<String> abilities, {
  bool? isTeaching,
}) => AccountProfileModel.fromJson({
  'data': _meJson(
    userType: type,
    abilities: abilities,
    isTeaching: isTeaching,
  ),
}).toEntity();

// Default role abilities of the API (DefaultRolePermissions).
const _structure = ['academic_years.view', 'classes.view', 'subjects.view'];
const _receptionist = _structure;
const _accountant = [..._structure, 'staff.view'];
const _vicePrincipal = [
  'school.view',
  'academic_years.view',
  'academic_years.manage',
  'classes.view',
  'classes.manage',
  'subjects.view',
  'subjects.manage',
  'staff.view',
  'teaching_assignments.manage',
];

void main() {
  group('is_teaching parsing', () {
    AccountProfile parse(Object? value) => AccountProfileModel.fromJson({
      'data': _meJson(isTeaching: value),
    }).toEntity();

    test('true and false are kept', () {
      expect(parse(true).isTeaching, isTrue);
      expect(parse(false).isTeaching, isFalse);
    });

    test('a missing field stays null (an older API)', () {
      final profile = AccountProfileModel.fromJson({
        'data': _meJson(),
      }).toEntity();
      expect(profile.isTeaching, isNull);
    });

    test('null or a non-boolean value stays null', () {
      expect(parse(null).isTeaching, isNull);
      expect(parse('true').isTeaching, isNull);
      expect(parse(1).isTeaching, isNull);
    });

    test('the unwrapped shape is read too, and the rest is unchanged', () {
      final profile = AccountProfileModel.fromJson(
        _meJson(isTeaching: true),
      ).toEntity();

      expect(profile.isTeaching, isTrue);
      expect(profile.userType, 'staff');
      expect(profile.abilities, ['classes.view', 'subjects.view']);
      expect(profile.school.slug, 'springfield');
    });

    test('profiles that differ only in the signal are not equal', () {
      expect(
        _profile('staff', _receptionist, isTeaching: true),
        isNot(_profile('staff', _receptionist, isTeaching: false)),
      );
      expect(
        _profile('staff', _receptionist, isTeaching: true),
        _profile('staff', _receptionist, isTeaching: true),
      );
    });
  });

  group('landing', () {
    test('teaching staff land in the teacher workspace', () {
      final staff = _profile('staff', _receptionist, isTeaching: true);

      expect(authenticatedLandingPath(staff), '/teacher/sections');
      expect(
        authenticatedLandingPath(
          _profile('staff', ['subjects.view'], isTeaching: true),
        ),
        '/teacher/subjects',
      );
    });

    test('non-teaching staff (a receptionist) land on /profile', () {
      final staff = _profile('staff', _receptionist, isTeaching: false);

      expect(authenticatedLandingPath(staff), '/profile');
      expect(staff.canOpenTeacherWorkspace, isFalse);
    });

    test('an unknown signal keeps today\'s landing (older API)', () {
      final staff = _profile('staff', _receptionist);

      expect(staff.isTeaching, isNull);
      expect(authenticatedLandingPath(staff), '/teacher/sections');
      expect(staff.canOpenTeacherWorkspace, isTrue);
    });

    test('admin landing does not depend on the signal', () {
      for (final isTeaching in [true, false, null]) {
        expect(
          authenticatedLandingPath(
            _profile('staff', _vicePrincipal, isTeaching: isTeaching),
          ),
          '/admin/setup',
        );
        // The Accountant keeps landing in the read-only Admin (decided
        // separately), whatever the signal says.
        expect(
          authenticatedLandingPath(
            _profile('staff', _accountant, isTeaching: isTeaching),
          ),
          '/admin/setup',
        );
      }
    });

    test('a teacher login is not affected by the signal', () {
      for (final isTeaching in [true, false, null]) {
        expect(
          authenticatedLandingPath(
            _profile('teacher', _structure, isTeaching: isTeaching),
          ),
          '/teacher/sections',
        );
      }
    });

    test('accounts without teacher abilities still land on /profile', () {
      for (final isTeaching in [true, false, null]) {
        expect(
          authenticatedLandingPath(
            _profile('staff', const [], isTeaching: isTeaching),
          ),
          '/profile',
        );
        expect(
          authenticatedLandingPath(
            _profile('parent', _structure, isTeaching: isTeaching),
          ),
          '/profile',
        );
      }
    });
  });

  group('teacher route guard', () {
    test('keeps non-teaching staff out of the teacher workspace', () {
      final staff = _profile('staff', _receptionist, isTeaching: false);

      expect(teacherWorkspaceRouteRedirect(staff, '/teacher/sections'), '/profile');
      expect(teacherWorkspaceRouteRedirect(staff, '/teacher/subjects'), '/profile');
      expect(appRouteRedirect(staff, '/'), '/profile');
      expect(appRouteRedirect(staff, '/teacher/sections'), '/profile');
      expect(appRouteRedirect(staff, '/profile'), isNull);
    });

    test('lets teaching staff and an unknown signal in', () {
      for (final isTeaching in [true, null]) {
        final staff = _profile('staff', _receptionist, isTeaching: isTeaching);

        expect(teacherWorkspaceRouteRedirect(staff, '/teacher/sections'), isNull);
        expect(teacherWorkspaceRouteRedirect(staff, '/teacher/subjects'), isNull);
      }
    });

    test('still falls back to the other tab for a missing ability', () {
      final staff = _profile('staff', ['subjects.view'], isTeaching: true);

      expect(
        teacherWorkspaceRouteRedirect(staff, '/teacher/sections'),
        '/teacher/subjects',
      );
    });

    test('does not touch the admin gate', () {
      for (final isTeaching in [true, false, null]) {
        final admin = _profile('staff', _vicePrincipal, isTeaching: isTeaching);

        expect(appRouteRedirect(admin, '/admin/sections'), isNull);
        expect(appRouteRedirect(admin, '/admin/teaching-assignments'), isNull);
        expect(
          appRouteRedirect(
            _profile('staff', _receptionist, isTeaching: isTeaching),
            '/admin/sections',
          ),
          '/profile',
        );
      }
    });

    test('agrees with the landing policy for every combination', () {
      const accounts = {
        'receptionist': ('staff', _receptionist),
        'accountant': ('staff', _accountant),
        'vice principal': ('staff', _vicePrincipal),
        'subjects only': ('staff', ['subjects.view']),
        'no abilities': ('staff', <String>[]),
        'teacher': ('teacher', _structure),
        'parent': ('parent', _structure),
      };

      for (final entry in accounts.entries) {
        for (final isTeaching in [true, false, null]) {
          final profile = _profile(
            entry.value.$1,
            entry.value.$2,
            isTeaching: isTeaching,
          );
          final landing = authenticatedLandingPath(profile);
          final label = '${entry.key} isTeaching=$isTeaching -> $landing';

          if (landing.startsWith('/teacher/')) {
            expect(
              teacherWorkspaceRouteRedirect(profile, landing),
              isNull,
              reason: label,
            );
          } else if (landing == '/profile') {
            expect(
              teacherWorkspaceRouteRedirect(profile, '/teacher/sections'),
              '/profile',
              reason: label,
            );
          }
        }
      }
    });
  });
}
