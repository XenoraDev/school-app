import 'package:school_app/features/auth/domain/entities/account_profile.dart';

/// Redirects only teacher-workspace destinations that the profile cannot use.
/// A direct `/profile` request intentionally has no teacher-workspace redirect.
String? teacherWorkspaceRouteRedirect(AccountProfile profile, String path) {
  if (!path.startsWith('/teacher/')) return null;
  if (!profile.canOpenTeacherWorkspace) return '/profile';
  if (path == '/teacher/sections' && !profile.can('classes.view')) {
    return profile.can('subjects.view') ? '/teacher/subjects' : '/profile';
  }
  if (path == '/teacher/subjects' && !profile.can('subjects.view')) {
    return profile.can('classes.view') ? '/teacher/sections' : '/profile';
  }
  return null;
}
