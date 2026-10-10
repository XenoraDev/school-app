import 'package:school_app/features/admin_workspace/presentation/screens/admin_screens.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/presentation/workspace_landing_policy.dart';
import 'package:school_app/features/teacher_workspace/presentation/teacher_route_policy.dart';

/// The app-wide route guard. [profile] is `null` while nobody is signed in.
/// Returns the path to redirect to, or `null` to stay on [path].
String? appRouteRedirect(AccountProfile? profile, String path) {
  if (profile == null) return path == '/' ? null : '/';
  if (path == '/') return authenticatedLandingPath(profile);
  final teacherRedirect = teacherWorkspaceRouteRedirect(profile, path);
  if (teacherRedirect != null) return teacherRedirect;
  if (path.startsWith('/admin')) {
    if (!profile.canOpenAdminWorkspace) return '/profile';
    final requiredAbility = adminRouteAbility(path);
    if (requiredAbility != null && !profile.can(requiredAbility)) {
      return firstAdminRoute(profile);
    }
  }
  return null;
}

/// The ability an admin route needs, or `null` when the path is not gated.
String? adminRouteAbility(String path) {
  if (path == '/admin' || path == '/admin/setup' || path == '/admin/profile') {
    return 'school.view';
  }
  if (path == '/admin/settings') {
    return 'school.view';
  }
  if (path.startsWith('/admin/academic-years') || path == '/admin/terms') {
    return 'academic_years.view';
  }
  if (path == '/admin/grade-levels' || path == '/admin/sections') {
    return 'classes.view';
  }
  if (path == '/admin/subjects' || path == '/admin/curriculum') {
    return 'subjects.view';
  }
  if (path == '/admin/staff') {
    return 'staff.view';
  }
  if (path == '/admin/roles') {
    return 'roles.view';
  }
  return null;
}

/// The first admin sidebar destination the profile may open, else `/profile`.
String firstAdminRoute(AccountProfile profile) {
  for (final item in AdminWorkspaceShell.items) {
    if (profile.can(item.$4)) return item.$1;
  }
  return '/profile';
}
