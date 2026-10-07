# Authentication, Tenant Isolation & RBAC Architecture

This document specifies the authorization and access control rules for the Flutter mobile application, derived from `AUTHORIZATION.md`, `API-AUTH-SECURITY.md`, and `PRODUCT-MODULES.md` in `school-api`.

---

## 1. Golden Rule: Laravel is the Sole Authority

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│  • Adapts navigation shells to role                    │
│  • Hides / disables action buttons for UX              │
│  • NEVER assumes a hidden button equals security       │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS (Bearer Token)
                           ▼
┌────────────────────────────────────────────────────────┐
│               Laravel Backend (API)                    │
│  • Enforces Tenant Isolation (SchoolScope)             │
│  • Enforces Spatie permissions (module.action)         │
│  • Enforces Relationship Scope (TeacherScope / Parent) │
│  • Rejects unauthorized actions with 403 or 404        │
└────────────────────────────────────────────────────────┘
```

**Client-side permission checks are strictly User Experience (UX) optimizations.** The Flutter application must gracefully handle HTTP 403 (`forbidden`) and HTTP 404 (`not_found`) at all times.

---

## 2. Tenant & School Isolation

1. **School Slug at Login**:
   * The user supplies the school slug (e.g., `springfield`), their login identifier, and password.
   * Laravel looks up the school by slug. If valid and not closed, it issues a Sanctum Bearer token tied to the user and their `school_id`.
2. **Immutable Tenant Context**:
   * The Flutter client **never** transmits `school_id` in headers, query strings, or request bodies.
   * Every query on the backend is automatically scoped to the authenticated user's `school_id` via `SchoolScope`.
3. **Suspended School Behavior**:
   * If a school is suspended (`schools.status == 'suspended'`), Laravel middleware `school.operational` intercepts requests:
     * Read operations (`GET`) may still function.
     * State mutations (`POST`, `PATCH`, `PUT`, `DELETE`) return HTTP 403 `school_suspended`.
   * Flutter must detect the `school_suspended` code and present a banner: *"This school account is currently suspended. Actions are read-only."*

---

## 3. User Types (`user_type` Enum)

The `users.user_type` column defines the primary account audience:

| `user_type` | Description | Allowed Mobile Route Groups | Authorization Model |
|---|---|---|---|
| `staff` | School administrative staff (Principal, VP, Accountant, Clerk). | `/api/v1/school/*`<br>`/api/v1/common/*`<br>`/api/v1/teacher/*` (if assigned to teach) | Spatie roles & permissions in the school team. |
| `teacher` | Teaching staff. | `/api/v1/teacher/*`<br>`/api/v1/common/*`<br>*(Blocked from `/school/*` by `school.audience:staff` middleware)* | Spatie role permissions **AND** `TeacherScope` (active teaching assignments in current year). |
| `parent` | Student guardians. | `/api/v1/parent/*` *(Phase 3+)*<br>`/api/v1/common/*` | **No Spatie roles**. Access is purely relationship-scoped via `student_guardians` table with portal access enabled. |
| `student` | Enrolled students. | `/api/v1/student/*` *(V1.5)*<br>`/api/v1/common/*` | **No Spatie roles**. Self-scoped access only (`/student/me/*`). |
| `platform_admin` | Platform operators. | `/api/v1/platform/*` *(Not supported in mobile app)* | Platform-only guard (`platform_users` table). |

---

## 4. Roles & Permissions Architecture

### 4.1 Seeded Default Roles
Laravel seeds seven default roles per school (Decision `D-22`). These roles cannot be deleted or renamed:
1. **School Admin**: Full access to all school modules; permission set manageable only by platform.
2. **Vice Principal**: Academic structure, staff viewing, student/attendance viewing, no fee management.
3. **Class Teacher**: Same permissions as Subject Teacher, but gains whole-section visibility for assigned classes via `TeacherScope`.
4. **Subject Teacher**: Assigned subjects and classes only via `TeacherScope`.
5. **Accountant**: Fee structures, fee collection, receipts, ledger view.
6. **Receptionist**: Admissions, student data entry, basic inquiries.
7. **Librarian**: Reserved for V2 library module.

### 4.2 Permission Naming Convention
Permissions strictly follow `module.action` (one dot, lowercase):
* `school.view`, `school.update`
* `settings.manage`
* `academic_years.view`, `academic_years.manage`
* `classes.view`, `classes.manage`
* `subjects.view`, `subjects.manage`
* `teaching_assignments.manage`
* `staff.view`, `staff.create`, `staff.update`, `staff.archive`
* `users.view`, `users.manage`
* `roles.view`, `roles.manage`
* `audit.view`

### 4.3 Token Abilities & Session Permissions
When a user authenticates, their Sanctum Bearer token is minted with abilities matching their held permissions plus `auth.session`.

`GET /api/v1/common/me` returns the session's active abilities:
```json
{
  "data": {
    "user_type": "staff",
    "abilities": [
      "school.view",
      "classes.view",
      "subjects.view",
      "teaching_assignments.manage"
    ]
  }
}
```

---

## 5. Scope-Based Access Control (Beyond Roles)

Permissions answer: *"May this user perform this action?"*  
Scopes answer: *"On which specific rows/entities may they act?"*

### 5.1 Teacher Scope (`TeacherScope`)
* A user with `user_type = teacher` (or a `staff` member who teaches) only sees sections and subjects returned by `GET /teacher/my/sections` and `GET /teacher/my/subjects`.
* Scoping criteria:
  1. The user must be linked to an **active** staff profile flagged `is_teaching = 1`.
  2. The teaching assignment must be **active** (`status = 'active'`).
  3. The academic year must be the **current** open year.
  4. The section must be **active** (`status = 'active'`).
* If a teacher is put on leave (`status = 'on_leave'`), their scope is temporarily paused.
* If a teacher resigns or is terminated, their assignments end immediately and their scope becomes empty.

### 5.2 Guardian Scope (Planned Phase 3)
* Parents have no Spatie permissions.
* A parent only accesses child data where `student_guardians.portal_access == true`.
* If a student is unlinked from a guardian, access is revoked on the very next request.

---

## 6. Client-Side Flutter UX Helpers

The Flutter app implements extension methods on the user session model for UI rendering:

```dart
extension AccountPermissionsX on AccountProfile {
  /// Checks whether the user holds a specific backend permission ability.
  bool can(String permission) => abilities.contains(permission);

  /// Checks if the user is a staff administrator.
  bool get isStaffAdmin => userType == 'staff' && can('school.view');

  /// Checks if the user has teaching access.
  bool get hasTeachingAccess =>
      userType == 'teacher' || (userType == 'staff' && can('classes.view'));

  /// Checks if the user is a parent.
  bool get isParent => userType == 'parent';

  /// Checks if the user is a student.
  bool get isStudent => userType == 'student';
}
```

Phase 2A and 2B use separate Teacher and Admin route shells. Teacher entry requires
`user_type` teacher/staff plus `classes.view` or `subjects.view`. Admin entry
requires `user_type=staff` and an admin read ability (`school.view`,
`academic_years.view`, `classes.view`, `subjects.view`, `staff.view`, or
`roles.view`). Navigation and mutation controls are hidden unless the matching
read/manage ability is present. `/profile` remains a valid route for every
authenticated account. These are UX checks only; API requests still rely on
Laravel audience middleware, token abilities, and policies.

### UI Guard Widget Example
```dart
class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthCubit>().state.account;
    if (session != null && session.can(permission)) {
      return child;
    }
    return fallback;
  }
}
```

