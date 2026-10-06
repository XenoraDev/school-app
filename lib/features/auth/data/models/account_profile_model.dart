import 'package:school_app/features/auth/domain/entities/account_profile.dart';

/// Data Transfer Object for `GET /api/v1/common/me` response.
///
/// Response shape (verified from AccountResource.php):
/// ```json
/// {
///   "data": {
///     "id": 15,
///     "kind": "school",
///     "name": "Jane Smith",
///     "email": "jane@springfield.edu",
///     "user_type": "teacher",
///     "school": { "name": "Springfield High", "slug": "springfield", "status": "active" },
///     "abilities": ["classes.view", "subjects.view"],
///     "email_verified": true,
///     "mfa_enabled": false,
///     "mfa_required": false
///   }
/// }
/// ```
/// Note: `abilities` never contains `auth.*` — filtered by the backend.
class AccountProfileModel {
  final int id;
  final String kind;
  final String name;
  final String email;
  final String userType;
  final SchoolInfoModel school;
  final List<String> abilities;
  final bool emailVerified;
  final bool mfaEnabled;
  final bool mfaRequired;

  const AccountProfileModel({
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

  factory AccountProfileModel.fromJson(Map<String, dynamic> json) {
    // Handles both wrapped { "data": {...} } and unwrapped shapes.
    final d = json.containsKey('data')
        ? json['data'] as Map<String, dynamic>
        : json;

    final rawAbilities = d['abilities'] as List<dynamic>? ?? [];
    final schoolJson = d['school'] as Map<String, dynamic>? ?? {};

    return AccountProfileModel(
      id: d['id'] as int,
      kind: d['kind'] as String? ?? 'school',
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      userType: d['user_type'] as String? ?? '',
      school: SchoolInfoModel.fromJson(schoolJson),
      abilities: rawAbilities.map((e) => e.toString()).toList(),
      emailVerified: d['email_verified'] as bool? ?? false,
      mfaEnabled: d['mfa_enabled'] as bool? ?? false,
      mfaRequired: d['mfa_required'] as bool? ?? false,
    );
  }

  AccountProfile toEntity() => AccountProfile(
        id: id,
        kind: kind,
        name: name,
        email: email,
        userType: userType,
        school: school.toEntity(),
        abilities: abilities,
        emailVerified: emailVerified,
        mfaEnabled: mfaEnabled,
        mfaRequired: mfaRequired,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AccountProfileModel || runtimeType != other.runtimeType) {
      return false;
    }
    return id == other.id &&
        kind == other.kind &&
        name == other.name &&
        email == other.email &&
        userType == other.userType &&
        school == other.school &&
        emailVerified == other.emailVerified &&
        mfaEnabled == other.mfaEnabled &&
        mfaRequired == other.mfaRequired;
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
        emailVerified,
        mfaEnabled,
        mfaRequired,
      );
}

/// DTO for the `school` object embedded in `AccountProfileModel`.
class SchoolInfoModel {
  final String name;
  final String slug;
  final String status;

  const SchoolInfoModel({
    required this.name,
    required this.slug,
    required this.status,
  });

  factory SchoolInfoModel.fromJson(Map<String, dynamic> json) =>
      SchoolInfoModel(
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
      );

  SchoolInfo toEntity() => SchoolInfo(name: name, slug: slug, status: status);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolInfoModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          slug == other.slug &&
          status == other.status;

  @override
  int get hashCode => Object.hash(runtimeType, name, slug, status);
}

