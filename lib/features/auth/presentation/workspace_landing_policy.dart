import 'package:school_app/features/auth/domain/entities/account_profile.dart';

/// Selects the authenticated landing destination from the account's actual
/// abilities. Staff accounts with both admin and teaching access land in Admin;
/// teaching-only accounts still land in the Teacher workspace.
String authenticatedLandingPath(AccountProfile profile) {
  if (profile.canOpenAdminWorkspace) return '/admin/setup';
  if (profile.canOpenTeacherWorkspace) {
    return profile.can('classes.view')
        ? '/teacher/sections'
        : '/teacher/subjects';
  }
  return '/profile';
}
