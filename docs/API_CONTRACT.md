# API Contract (Verified from Backend Source of Truth)

This document contains **ONLY** the API endpoints currently defined, verified, and active in `D:\Projects\school-api\routes\api.php`. No planned or hypothetical endpoints are included.

All endpoints are mounted on the API host under `/api/v1/`.

---

## 1. Global Wire Format & Conventions

### 1.1 Headers
* Required on every request:
  * `Accept: application/json`
  * `Content-Type: application/json` (for POST, PATCH, PUT)
* Required on authenticated requests:
  * `Authorization: Bearer <access_token>`

### 1.2 Success Envelope (`ApiResponse::data`)
```json
{
  "data": { ... },
  "meta": {
    "request_id": "01J9XABCDEF123456789012345"
  }
}
```

### 1.3 Paginated List Envelope (`ListQuery::respond`)
All collection endpoints use cursor-based pagination with a default `per_page` of 25 (max 100).
```json
{
  "data": [ ... ],
  "meta": {
    "request_id": "01J9XABCDEF123456789012345",
    "per_page": 25,
    "next_cursor": "eyJpZCI6MTAxfQ",
    "has_more": true
  },
  "links": {
    "next": "https://api.school.internal/api/v1/resource?cursor=eyJpZCI6MTAxfQ",
    "prev": null
  }
}
```

### 1.4 Error Envelope (`ApiResponse::error`)
```json
{
  "message": "The given data was invalid.",
  "code": "validation_failed",
  "errors": {
    "field_name": ["Specific error description."]
  },
  "request_id": "01J9XABCDEF123456789012345"
}
```

Stable `code` values (`ErrorCode` enum):
* `bad_request` (400)
* `unauthenticated` (401)
* `forbidden` (403)
* `school_suspended` (403)
* `not_found` (404)
* `conflict` (409)
* `invalid_state` (409)
* `validation_failed` (422)
* `idempotency_mismatch` (422)
* `rate_limited` (429)
* `server_error` (500)

---

## 2. Public / Foundation Endpoints

### 2.1 Health Check
* **Endpoint**: `GET /api/v1/health`
* **Auth**: None
* **Throttle**: `health` (120/min)
* **Response**: `200 OK`
  ```json
  { "status": "ok" }
  ```

### 2.2 App Configuration
* **Endpoint**: `GET /api/v1/app-config`
* **Auth**: None
* **Throttle**: `app-config` (60/min)
* **Response**: `200 OK`
  ```json
  {
    "name": "School App",
    "tagline": "Next Generation School Management",
    "support_email": "support@school.internal",
    "primary_color": "#1E40AF",
    "logo_url": null
  }
  ```

### 2.3 Accept Account Invitation
* **Endpoint**: `POST /api/v1/auth/invitations/accept`
* **Auth**: None
* **Throttle**: `invitation`
* **Request**:
  ```json
  {
    "token": "<id>.<secret>",
    "password": "NewSecurePassword123!",
    "password_confirmation": "NewSecurePassword123!"
  }
  ```
* **Response**: `200 OK` (Sets password and verifies email; does not issue a token. User must log in next).

---

## 3. Authentication & Session Endpoints

### 3.1 Login (School User)
* **Endpoint**: `POST /api/v1/auth/login`
* **Auth**: None
* **Throttle**: `auth-attempt` (5/min per identifier+IP)
* **Request**:
  ```json
  {
    "school": "springfield",
    "identifier": "teacher@springfield.edu",
    "password": "Password123!"
  }
  ```
* **Success Response (No MFA)**: `200 OK`
  ```json
  {
    "data": {
      "state": "complete",
      "token_type": "Bearer",
      "access_token": "sch_1|abcdef123456...",
      "expires_at": "2026-11-05T15:30:00Z"
    },
    "meta": { "request_id": "..." }
  }
  ```
* **Success Response (MFA Required)**: `200 OK`
  ```json
  {
    "data": {
      "state": "mfa_required",
      "token_type": "Bearer",
      "access_token": "sch_1|pending_mfa_token...",
      "expires_at": "2026-10-06T15:40:00Z"
    },
    "meta": { "request_id": "..." }
  }
  ```
  *(Note: The pending token carries ability `auth.mfa` only and is valid for 10 minutes).*
* **Success Response (MFA Enrollment Required)**: `200 OK`
  ```json
  {
    "data": {
      "state": "mfa_enrollment_required",
      "token_type": "Bearer",
      "access_token": "sch_1|pending_mfa_token...",
      "expires_at": "2026-10-06T15:40:00Z"
    },
    "meta": { "request_id": "..." }
  }
  ```
* **Failure Response**: `401 Unauthorized`
  ```json
  {
    "message": "Invalid credentials.",
    "code": "unauthenticated",
    "request_id": "..."
  }
  ```

### 3.2 MFA Verification
* **Endpoint**: `POST /api/v1/auth/mfa/verify`
* **Auth**: Bearer token (Must be a **pending** token with ability `auth.mfa`)
* **Throttle**: `sensitive`
* **Request (TOTP)**:
  ```json
  { "code": "123456" }
  ```
* **Request (Recovery Code)**:
  ```json
  { "recovery_code": "ABCD-1234-EFGH" }
  ```
* **Response**: `200 OK` (Returns full session Bearer token with state `complete`).

### 3.3 MFA Enrollment
* **Endpoint**: `POST /api/v1/auth/mfa/enroll`
* **Auth**: Bearer token (`auth.mfa` or `auth.session`)
* **Throttle**: `sensitive`
* **Response**: `200 OK`
  ```json
  {
    "data": {
      "secret": "JBSWY3DPEHPK3PXP",
      "uri": "otpauth://totp/SchoolApp:teacher@springfield.edu?secret=JBSWY3DPEHPK3PXP&issuer=SchoolApp"
    },
    "meta": { "request_id": "..." }
  }
  ```

### 3.4 MFA Confirm Enrollment
* **Endpoint**: `POST /api/v1/auth/mfa/confirm`
* **Auth**: Bearer token (`auth.mfa` or `auth.session`)
* **Throttle**: `sensitive`
* **Request**:
  ```json
  { "code": "123456" }
  ```
* **Response**: `200 OK`
  ```json
  {
    "data": {
      "recovery_codes": [
        "1A2B-3C4D", "5E6F-7G8H", "9I0J-1K2L", "3M4N-5O6P", "7Q8R-9S0T",
        "1U2V-3W4X", "5Y6Z-7A8B", "9C0D-1E2F", "3G4H-5I6J", "7K8L-9M0N"
      ],
      "state": "complete",
      "token_type": "Bearer",
      "access_token": "sch_1|full_token...",
      "expires_at": "2026-11-05T15:30:00Z"
    },
    "meta": { "request_id": "..." }
  }
  ```

### 3.5 Current Account Profile
* **Endpoint**: `GET /api/v1/common/me`
* **Auth**: Bearer token (`auth.session`)
* **Throttle**: `api`
* **Response**: `200 OK`
  ```json
  {
    "data": {
      "id": 15,
      "kind": "school",
      "name": "Jane Smith",
      "email": "jane@springfield.edu",
      "user_type": "teacher",
      "school": {
        "name": "Springfield High",
        "slug": "springfield",
        "status": "active"
      },
      "abilities": [
        "classes.view",
        "subjects.view"
      ],
      "email_verified": true,
      "mfa_enabled": false,
      "mfa_required": false
    },
    "meta": { "request_id": "..." }
  }
  ```

### 3.6 Session Revocation
* **Logout (Current Device)**: `POST /api/v1/auth/logout` $\rightarrow$ `200 OK { "data": { "logged_out": true } }`
* **Logout All Devices**: `POST /api/v1/auth/logout-all` $\rightarrow$ `200 OK { "data": { "logged_out": true, "revoked": 3 } }`
* **List Active Tokens**: `GET /api/v1/auth/tokens` $\rightarrow$ `200 OK`
* **Revoke Specific Token**: `DELETE /api/v1/auth/tokens/{token_id}` $\rightarrow$ `200 OK`
* **Change Password**: `POST /api/v1/auth/password/change` (Revokes all active tokens upon success, requiring re-login).

---

## 4. Teacher Workspace Endpoints (`/api/v1/teacher/*`)

Open to `user_type` = `teacher` or `staff`. Scoped strictly to active teaching assignments for the current academic year (`TeacherScope`).

### 4.1 My Sections
* **Endpoint**: `GET /api/v1/teacher/my/sections`
* **Auth**: Bearer token (`classes.view` ability)
* **Response**: `200 OK`
  ```json
  {
    "data": [
      {
        "id": "01J9XABCDEF123456789012345",
        "name": "8-A",
        "room": "Room 101",
        "academic_year": {
          "id": "01J9X111111111111111111111",
          "name": "2026-2027"
        },
        "grade_level": {
          "id": "01J9X222222222222222222222",
          "name": "Class 8"
        },
        "is_class_teacher": true,
        "subjects": [
          {
            "id": "01J9X333333333333333333333",
            "code": "MATH08",
            "name": "Mathematics"
          }
        ]
      }
    ],
    "meta": { "request_id": "..." }
  }
  ```

### 4.2 My Subjects
* **Endpoint**: `GET /api/v1/teacher/my/subjects`
* **Auth**: Bearer token (`subjects.view` ability)
* **Response**: `200 OK`
  ```json
  {
    "data": [
      {
        "id": "01J9X333333333333333333333",
        "code": "MATH08",
        "name": "Mathematics",
        "sections": [
          {
            "id": "01J9XABCDEF123456789012345",
            "name": "8-A",
            "grade_level": {
              "id": "01J9X222222222222222222222",
              "name": "Class 8"
            }
          }
        ]
      }
    ],
    "meta": { "request_id": "..." }
  }
  ```

---

## 5. School Administration Endpoints (`/api/v1/school/*`)

These routes require a full authenticated session, the staff audience, and the endpoint's specific ability. Mobile ability checks only control navigation and affordances; Laravel policies remain authoritative. Collection routes use cursor pagination (`data`, `meta.per_page`, `meta.next_cursor`, `meta.has_more`). Public resource IDs are ULIDs.

### Setup, school profile, and settings
* `GET /school/setup` (`school.view`) returns `{key, done}` rows for `profile`, `academic_year`, `terms`, `grade_levels`, `sections`, `subjects`, `curriculum`, `staff`, and `teaching`.
* `GET /school/profile` (`school.view`) returns `version` and the profile fields `address_line1`, `address_line2`, `city`, `state`, `postal_code`, `country`, `phone`, `email`, `website`, `affiliation_board`, `affiliation_number`, `established_year`. `PATCH /school/profile` (`school.update`) requires `version` plus one or more allowed fields; stale versions return 409.
* `GET /school/settings` (`school.view`) returns `{key,value,version}` rows. `PATCH /school/settings` (`settings.manage`) takes `{settings:[{key,value,version}]}` and applies the versioned batch atomically.

### Academic structure
* Academic years: `GET/POST /school/academic-years`, `GET/PATCH /school/academic-years/{id}`, and `POST .../{id}/activate|close` (`academic_years.view` for reads, `academic_years.manage` for writes). Create body: `{name,start_date,end_date}`. Close requires `{reason,confirm_name,password}`; conflicts and invalid transitions return 409.
* Terms: `GET/POST /school/terms`, `GET/PATCH/DELETE /school/terms/{id}` with the same view/manage abilities. Create body: `{academic_year,name,start_date,end_date}`; sequence is server assigned.
* Grade levels: `GET/POST /school/grade-levels`, `GET/PATCH /school/grade-levels/{id}`, `POST /school/grade-levels/reorder` with `{order:[ulid,...]}`, and archive/unarchive actions. Read/write abilities: `classes.view`/`classes.manage`.
* Sections: `GET/POST /school/sections`, `GET/PATCH /school/sections/{id}`, close/reopen actions, and `PUT /school/sections/{id}/class-teacher` with `{staff:ulid|null}`. Create body uses `{academic_year,grade_level,name,capacity,room}`; the year and grade are immutable after creation. Read/write abilities: `classes.view`/`classes.manage`.
* Subjects: `GET/POST /school/subjects`, `GET/PATCH /school/subjects/{id}`, archive/unarchive actions. Create body `{code,name,type}`; code is immutable. Read/write abilities: `subjects.view`/`subjects.manage`.
* Curriculum: `GET /school/curriculum?academic_year={ulid}&grade_level={ulid}` and `PUT /school/curriculum` with `{academic_year,grade_level,subjects:[{subject,kind}]}` (`subjects.view`/`subjects.manage`). PUT replaces the complete set.

### Staff directory
* `GET/POST /school/staff`, `GET/PATCH /school/staff/{id}`, archive/unarchive, and disable-login/enable-login actions. Reads require `staff.view`; creation/update/archive use `staff.create`, `staff.update`, and `staff.archive`; login switches require `users.manage`.
* Create requires `{employee_no,full_name}` and accepts email, phone, designation, department, `is_teaching`, `joined_on`, and `left_on`. Update requires the returned `version`. Resource rows expose the staff record and login state, never an internal user ID.
* Login creation, invitations, invitation acceptance, and staff role assignment are separate routes and outside this Phase 2B client scope.

### Teaching assignments
* `GET /school/teaching-assignments` (`classes.view`) returns `{id, academic_year, section, subject, staff, status: active|ended, ended_at}` with public ids only, cursor-paged, with `filter[academic_year|section|subject|staff|status]`. The client resolves names from the sections, grade-levels, academic-years, subjects and staff lists.
* `POST /school/teaching-assignments` (`teaching_assignments.manage`) takes `{section, subject, staff}`; the year is the section's. The API answers 422 for a staff member who is not active and teaching, a subject outside the section's curriculum, or a foreign id, and 409 for a closed section or year and for a combination that already exists (reactivate it instead).
* `POST /school/teaching-assignments/{id}/end` and `.../reactivate` (`teaching_assignments.manage`) change the status; reactivating returns 409 unless the year is open, the section active, the staff member active and teaching, and the subject still in the curriculum.

### Roles and permissions
* `GET /school/permissions` returns module groups containing `{name,action}`. `GET /school/roles` returns `{id,name,reserved,protected,permission_count,holder_count}`; `GET /school/roles/{id}` also returns permission names. Both require `roles.view`.
* `PUT /school/roles/{id}/permissions` requires `roles.manage` and `{permissions:[name,...],password}`. It replaces the complete set, enforces backend no-escalation/protected-role rules, and revokes affected holders' sessions. Custom role create/rename/delete are excluded from Phase 2B.

The implementation is verified against the matching route declarations, resources, authorization tests, and feature contract tests in `school-api`. Do not infer permission assignment, invitation, or other workflows from endpoints omitted above.

