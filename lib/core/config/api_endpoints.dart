/// API endpoint path constants relative to base URL (/api/v1).
abstract final class ApiEndpoints {
  // ── Phase 0 ──────────────────────────────────────────────────────────────

  /// Health check endpoint (GET /api/v1/health)
  static const String health = '/health';

  /// App public branding configuration endpoint (GET /api/v1/app-config)
  static const String appConfig = '/app-config';

  // ── Phase 1 — Auth, Session & MFA ────────────────────────────────────────

  /// School-user password login (POST /api/v1/auth/login)
  static const String login = '/auth/login';

  /// Revoke current device token (POST /api/v1/auth/logout)
  static const String logout = '/auth/logout';

  /// Revoke all active tokens (POST /api/v1/auth/logout-all)
  static const String logoutAll = '/auth/logout-all';

  /// List active tokens (GET /api/v1/auth/tokens)
  static const String tokens = '/auth/tokens';

  /// Change password — revokes all tokens (POST /api/v1/auth/password/change)
  static const String changePassword = '/auth/password/change';

  /// Request password-reset email — 503 while EMAIL_AUTH_ENABLED=false
  /// (POST /api/v1/auth/password/forgot)
  static const String forgotPassword = '/auth/password/forgot';

  /// Complete password reset — 503 while EMAIL_AUTH_ENABLED=false
  /// (POST /api/v1/auth/password/reset)
  static const String resetPassword = '/auth/password/reset';

  /// MFA verify with pending token (POST /api/v1/auth/mfa/verify)
  static const String mfaVerify = '/auth/mfa/verify';

  /// Begin TOTP enrollment (POST /api/v1/auth/mfa/enroll)
  static const String mfaEnroll = '/auth/mfa/enroll';

  /// Confirm TOTP enrollment (POST /api/v1/auth/mfa/confirm)
  static const String mfaConfirm = '/auth/mfa/confirm';

  /// Disable MFA (POST /api/v1/auth/mfa/disable)
  static const String mfaDisable = '/auth/mfa/disable';

  /// Authenticated user profile + abilities (GET /api/v1/common/me)
  static const String me = '/common/me';

  /// Revoke a specific token by integer ID (DELETE /api/v1/auth/tokens/{id})
  static String revokeToken(int id) => '/auth/tokens/$id';

  // Phase 2A: teacher workspace (caller-scoped endpoints).
  static const String mySections = '/teacher/my/sections';
  static const String mySubjects = '/teacher/my/subjects';

  // Phase 2B: school administration (staff audience, ability protected).
  static const String schoolSetup = '/school/setup';
  static const String schoolProfile = '/school/profile';
  static const String schoolSettings = '/school/settings';
  static const String academicYears = '/school/academic-years';
  static const String terms = '/school/terms';
  static const String gradeLevels = '/school/grade-levels';
  static const String gradeLevelReorder = '/school/grade-levels/reorder';
  static const String sections = '/school/sections';
  static const String subjects = '/school/subjects';
  static const String curriculum = '/school/curriculum';
  static const String staff = '/school/staff';
  static const String roles = '/school/roles';
  static const String permissions = '/school/permissions';

  static String academicYear(String id) => '$academicYears/$id';
  static String academicYearActivate(String id) =>
      '${academicYear(id)}/activate';
  static String academicYearClose(String id) => '${academicYear(id)}/close';
  static String term(String id) => '$terms/$id';
  static String gradeLevel(String id) => '$gradeLevels/$id';
  static String gradeLevelArchive(String id) => '${gradeLevel(id)}/archive';
  static String gradeLevelUnarchive(String id) => '${gradeLevel(id)}/unarchive';
  static String sectionsClose(String id) => '$sections/$id/close';
  static String sectionsReopen(String id) => '$sections/$id/reopen';
  static String sectionClassTeacher(String id) => '$sections/$id/class-teacher';
  static String subject(String id) => '$subjects/$id';
  static String subjectArchive(String id) => '${subject(id)}/archive';
  static String subjectUnarchive(String id) => '${subject(id)}/unarchive';
  static String staffRecord(String id) => '$staff/$id';
  static String staffArchive(String id) => '${staffRecord(id)}/archive';
  static String staffUnarchive(String id) => '${staffRecord(id)}/unarchive';
  static String staffDisableLogin(String id) =>
      '${staffRecord(id)}/disable-login';
  static String staffEnableLogin(String id) =>
      '${staffRecord(id)}/enable-login';
  static String role(String id) => '$roles/$id';
  static String rolePermissions(String id) => '${role(id)}/permissions';

  // ── Phase 2B — Teaching assignments ──────────────────────────────────────

  /// GET (list) and POST (create) /api/v1/school/teaching-assignments
  static const String teachingAssignments = '/school/teaching-assignments';
  static String teachingAssignmentEnd(String id) =>
      '$teachingAssignments/$id/end';
  static String teachingAssignmentReactivate(String id) =>
      '$teachingAssignments/$id/reactivate';
}
