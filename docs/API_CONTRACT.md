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

Restricted to `user_type = staff` with appropriate `module.action` token abilities.

### 5.1 Setup Checklist
* **Endpoint**: `GET /api/v1/school/setup`
* **Permission**: `school.view`
* **Response**: `200 OK`
  ```json
  {
    "data": [
      { "key": "profile", "done": true },
      { "key": "academic_year", "done": true },
      { "key": "terms", "done": true },
      { "key": "grade_levels", "done": true },
      { "key": "sections", "done": true },
      { "key": "subjects", "done": true },
      { "key": "curriculum", "done": true },
      { "key": "staff", "done": true },
      { "key": "teaching", "done": false }
    ],
    "meta": { "request_id": "..." }
  }
  ```

### 5.2 School Profile
* **Get Profile**: `GET /api/v1/school/profile` (`school.view`)
* **Update Profile**: `PATCH /api/v1/school/profile` (`school.update`)
  * Requires `version` (optimistic lock; 409 on stale version).
  * Fields: `name`, `address_line1`, `address_line2`, `city`, `state`, `postal_code`, `country`, `phone`, `email`, `website`, `affiliation_board`, `established_year`.

### 5.3 Academic Years
* **List**: `GET /api/v1/school/academic-years?filter[status]=planned|current|closed`
* **Create**: `POST /api/v1/school/academic-years`
  * Body: `{ "name": "2026-2027", "start_date": "2026-04-01", "end_date": "2027-03-31" }`
* **Activate (Planned $\rightarrow$ Current)**: `POST /api/v1/school/academic-years/{id}/activate` (409 if another year is currently active).
* **Close (Current $\rightarrow$ Closed)**: `POST /api/v1/school/academic-years/{id}/close`
  * Body: `{ "reason": "...", "confirm_name": "2026-2027", "password": "<step_up_password>" }`

### 5.4 Grade Levels & Sections
* **List Grade Levels**: `GET /api/v1/school/grade-levels`
* **List Sections**: `GET /api/v1/school/sections?filter[academic_year]=<ulid>&filter[grade_level]=<ulid>`
* **Assign Class Teacher**: `PUT /api/v1/school/sections/{id}/class-teacher`
  * Body: `{ "staff": "<staff_ulid>" }` (or `null` to clear).

### 5.5 Subjects & Curriculum
* **List Subjects**: `GET /api/v1/school/subjects?filter[q]=math&filter[type]=core|elective`
* **Get Curriculum**: `GET /api/v1/school/curriculum?academic_year=<ulid>&grade_level=<ulid>`
* **Replace Curriculum**: `PUT /api/v1/school/curriculum`
  * Body: `{ "academic_year": "<ulid>", "grade_level": "<ulid>", "subjects": [{ "subject": "<ulid>", "kind": "core" }] }`

### 5.6 Staff Directory & Logins
* **List Staff**: `GET /api/v1/school/staff?filter[status]=active|resigned&filter[is_teaching]=1&filter[q]=sharma`
* **Create Staff**: `POST /api/v1/school/staff`
* **Create Login**: `POST /api/v1/school/staff/{id}/login`
  * Body: `{ "user_type": "teacher", "email": "staff@school.internal" }`
* **Disable Login**: `POST /api/v1/school/staff/{id}/disable-login` (Immediately revokes all tokens).
* **Assign Staff Roles**: `PUT /api/v1/school/staff/{id}/roles`
  * Body: `{ "roles": ["<role_ulid>"], "password": "<step_up_password_if_admin>" }`

### 5.7 Roles & Permissions
* **Permission Catalogue**: `GET /api/v1/school/permissions` (Returns list grouped by module).
* **List Roles**: `GET /api/v1/school/roles`
* **Update Role Permissions**: `PUT /api/v1/school/roles/{id}/permissions`
  * Body: `{ "permissions": ["classes.view", "attendance.view"], "password": "<caller_password>" }` (Password step-up required; revokes tokens of all holders).

