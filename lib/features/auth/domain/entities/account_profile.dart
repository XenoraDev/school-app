/// School context embedded within an [AccountProfile].
class SchoolInfo {
  final String name;
  final String slug;
  final String status;

  const SchoolInfo({
    required this.name,
    required this.slug,
    required this.status,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          slug == other.slug &&
          status == other.status;

  @override
  int get hashCode => Object.hash(runtimeType, name, slug, status);

  @override
  String toString() => 'SchoolInfo(name: $name, slug: $slug, status: $status)';
}

/// Domain entity representing the authenticated user's profile and session
/// capabilities. Populated from `GET /api/v1/common/me`.
///
/// See `AccountResource.php` in school-api for the exact response shape.
class AccountProfile {
  /// Backend user integer ID.
  final int id;

  /// Account realm: always `'school'` for mobile users.
  final String kind;

  /// Full display name.
  final String name;

  /// Login email address.
  final String email;

  /// Role category: `'teacher'`, `'staff'`, `'parent'`, or `'student'`.
  final String userType;

  /// The school this user belongs to.
  final SchoolInfo school;

  /// Sanctum token abilities without the `auth.*` prefix.
  /// These are the `module.action` permission strings the user holds.
  /// The backend filters out `auth.*` before returning.
  final List<String> abilities;

  /// Whether the user's email address has been verified.
  final bool emailVerified;

  /// Whether MFA (TOTP) is currently enrolled and active.
  final bool mfaEnabled;

  /// Whether MFA is mandatory for this account (School Admin or
  /// users/roles.manage holders).
  final bool mfaRequired;

  const AccountProfile({
    required this.id,
    required this.kind,
    required this.name,
    required this.email,
    required this.userType,
    required this.school,
    required this.abilities,
    required this.emailVerified,
    required this.mfaEnabled,
    required this.mfaRequired,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AccountProfile || runtimeType != other.runtimeType) {
      return false;
    }
    if (id != other.id ||
        kind != other.kind ||
        name != other.name ||
        email != other.email ||
        userType != other.userType ||
        school != other.school ||
        emailVerified != other.emailVerified ||
        mfaEnabled != other.mfaEnabled ||
        mfaRequired != other.mfaRequired) {
      return false;
    }
    if (abilities.length != other.abilities.length) return false;
    for (var i = 0; i < abilities.length; i++) {
      if (abilities[i] != other.abilities[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    kind,
    name,
    email,
    userType,
    school,
    Object.hashAll(abilities),
    emailVerified,
    mfaEnabled,
    mfaRequired,
  );

  @override
  String toString() =>
      'AccountProfile(id: $id, name: $name, userType: $userType, '
      'school: ${school.slug}, abilities: $abilities)';
}

/// Client-side permission helpers derived from [AccountProfile].
/// These are STRICTLY UX optimizations — the backend enforces all real gates.
extension AccountPermissionsX on AccountProfile {
  /// Returns `true` if the user's token carries the given [permission] ability.
  bool can(String permission) => abilities.contains(permission);

  /// `true` for staff members with `school.view` — the primary admin indicator.
  bool get isStaffAdmin => userType == 'staff' && can('school.view');

  /// `true` if the user has teaching-related access (teacher or teaching staff).
  bool get hasTeachingAccess =>
      userType == 'teacher' || (userType == 'staff' && can('classes.view'));

  /// Whether this profile may enter the teacher workspace UI.
  /// Backend authorization still decides each endpoint request.
  bool get canOpenTeacherWorkspace =>
      (userType == 'teacher' || userType == 'staff') &&
      (can('classes.view') || can('subjects.view'));

  /// User type alone never grants access to school administration.
  bool get canOpenAdminWorkspace =>
      userType == 'staff' &&
      abilities.any(
        const {
          'school.view',
          'staff.view',
          'roles.view',
        }.contains,
      );

  /// `true` for guardian (parent) accounts.
  bool get isParent => userType == 'parent';

  /// `true` for student accounts.
  bool get isStudent => userType == 'student';

  /// `true` if the school is suspended — mutations will return 403.
  bool get isSchoolSuspended => school.status == 'suspended';
}
