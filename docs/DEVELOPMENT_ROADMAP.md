# Flutter Mobile Application Development Roadmap

This roadmap is synchronized directly with the backend roadmap of `school-api`.

### Status Indicators
* `[IMPLEMENTED BACKEND]` — Backend database, routes, policies, and tests are complete and verified.
* `[FLUTTER READY]` — Flutter implementation is unblocked and ready to start.
* `[BLOCKED BY BACKEND]` — Flutter implementation must wait until the corresponding backend phase is merged.
* `[PLANNED]` — Scheduled for later releases (V1.5 / V2).

---

## Phase 0: Core Network & Error Handling Infrastructure
* **Backend Status**: `[IMPLEMENTED BACKEND]`
* **Flutter Status**: `[FLUTTER READY]`
* **Scope**:
  * Set up strict lint rules (`analysis_options.yaml`).
  * Configure environment flavors (`dev`, `staging`, `prod`) with compile-time base URLs.
  * Implement `ApiClient` using `Dio`:
    * Base response wrapper decoding `data` and `meta.request_id` (`ApiResponse`).
    * Error interceptor parsing `ErrorCode` and field-level validation bags (`errors`).
    * Request timeout handling (connect, receive, send).
  * Implement `ListQuery` helper supporting cursor pagination (`cursor`, `per_page`, `filter[...]`, `sort`).
  * Implement `AppConfig` service loading `GET /api/v1/app-config`.
* **Exit Criteria**: Smoke test connecting to local/staging Laravel `/api/v1/health` and `/api/v1/app-config` passes.

---

## Phase 1: Authentication, Tenant Session & MFA Engine
* **Backend Status**: `[IMPLEMENTED BACKEND]`
* **Flutter Status**: `[FLUTTER READY]`
* **Scope**:
  * **Secure Storage**: Setup `flutter_secure_storage` for token persistence and `shared_preferences` for non-sensitive preferences.
  * **School Slug Selection Screen**: Prompt user for school identifier; cache selected school slug.
  * **Login Screen**: Form inputs for `school`, `identifier`, and `password`; integrates with `POST /api/v1/auth/login`.
  * **MFA Handling**:
    * `state == 'mfa_required'`: MFA verification screen accepting 6-digit TOTP or recovery code (`POST /auth/mfa/verify`).
    * `state == 'mfa_enrollment_required'`: MFA setup screen displaying QR/secret, verifying setup code, and displaying one-time recovery codes (`POST /auth/mfa/confirm`).
  * **Session Engine (`AuthBloc`)**:
    * App startup session restoration: Reads stored token $\rightarrow$ calls `GET /api/v1/common/me` $\rightarrow$ parses user type and abilities.
    * Automatic logout on HTTP 401 unauthenticated response.
  * **Profile & Security Screen**:
    * View active device tokens (`GET /auth/tokens`) and sign out other sessions (`DELETE /auth/tokens/{id}`) — implemented in Account security > Active sessions; see `PHASE_TRACKER.md`.
    * Change password (`POST /auth/password/change`).
    * Logout from this device (`POST /auth/logout`) or all devices (`POST /auth/logout-all`).
* **Exit Criteria**: End-to-end authentication, MFA challenge, and session restoration verified against local backend.

---

## Phase 2: Teacher Workspace & Academic Structure
* **Backend Status**: `[IMPLEMENTED BACKEND]`
* **Flutter Status**: `[PHASE 2A AND PHASE 2B IMPLEMENTED]`
* **Sub-Phase 2A (Teacher Workspace) — Implemented**:
  * Ability-aware Teacher Workspace Shell with persistent bottom navigation.
  * My Sections: consumes `GET /api/v1/teacher/my/sections`, displays caller-scoped sections, rooms, and class-teacher indicator.
  * My Subjects: consumes `GET /api/v1/teacher/my/subjects`, displays assigned subjects and corresponding sections.
  * Section detail is rendered from fields returned by the scoped sections endpoint.
  * Loading, retryable error, and empty states for unassigned teachers.
* **Sub-Phase 2B (School Admin Setup & Structure) — Implemented**:
  * Separate Admin shell with ability-filtered navigation; staff without an admin read ability remain at `/profile` and staff type alone never grants Admin entry.
  * Setup checklist, school profile and versioned settings editing.
  * Academic years and terms; year activation/step-up close, term create/update/delete.
  * Grade levels (including archive/unarchive and ordering), sections (create/update/close/reopen/class-teacher assignment), subjects and curriculum replacement.
  * Staff directory CRUD/status actions and login enable/disable. Login/invitation creation and invitation lifecycle remain deferred.
  * Role and permission catalogue viewing and permission replacement with password confirmation. Custom role CRUD and staff role assignment remain deferred.
  * Cursor-paged resource lists, loading/empty/error/retry states, and standard API handling for 401, 403, 409 and 422 responses.
* **Exit Criteria**: Verified read/write operations for both Teacher and School Admin roles according to backend permissions.

---

## Phase 3: Students, Guardians & Admissions
* **Backend Status**: `[NOT YET IMPLEMENTED]`
* **Flutter Status**: `[BLOCKED BY BACKEND]`
* **Scope (When Unblocked)**:
  * Student directory with search and status filtering.
  * Student detail profile with enrollment history and section assignments.
  * Guardian link cards and emergency contact info.
  * Admission application status pipeline.
* **Backend Gate**: Backend Phase 3 routes (`/school/students*`, `/school/guardians*`, `/school/enrollments*`) merged and tested in `school-api`.

---

## Phase 4: Attendance Marking Workflow
* **Backend Status**: `[NOT YET IMPLEMENTED]`
* **Flutter Status**: `[BLOCKED BY BACKEND]`
* **Scope (When Unblocked)**:
  * Teacher section daily attendance marking grid (Present / Absent / Late / Half-Day / Leave).
  * Bulk submission transaction (`PUT /school/attendance-sessions/{id}/records`).
  * Attendance corrections log with reason entry.
  * Parent attendance view (read-only calendar showing child attendance).
* **Backend Gate**: Backend Phase 4 routes (`/teacher/my/attendance*`, `/school/attendance*`) merged and verified.

---

## Phase 5: Fees & Payments (Counter Collection & Parent Statements)
* **Backend Status**: `[NOT YET IMPLEMENTED]`
* **Flutter Status**: `[BLOCKED BY BACKEND]`
* **Scope (When Unblocked)**:
  * Student fee statement view (breakdown of tuition, term fees, discounts).
  * Cashier offline counter collection form with `Idempotency-Key` header.
  * Receipt viewing and PDF download.
  * Parent fee dues overview.
* **Backend Gate**: Backend Phase 5 fee ledger and receipt generation endpoints merged and verified.

---

## Phase 6: Notices & In-App Notifications
* **Backend Status**: `[NOT YET IMPLEMENTED]`
* **Flutter Status**: `[BLOCKED BY BACKEND]`
* **Scope (When Unblocked)**:
  * School noticeboard feed with audience-targeted circulars and attachments.
  * In-app notification inbox with unread counts and read-state toggle.
* **Backend Gate**: Backend Phase 6 notification and notice endpoints merged and verified.

---

## Phase 7: Reports & Asynchronous Exports
* **Backend Status**: `[NOT YET IMPLEMENTED]`
* **Flutter Status**: `[BLOCKED BY BACKEND]`
* **Scope (When Unblocked)**:
  * Attendance and fee summary charts.
  * Long-running export poller consuming `/common/operations/{id}` and download triggers.
* **Backend Gate**: Backend Phase 7 reports endpoints merged and verified.

---

## Phases 8–10: Exams, Timetable, Homework & Online Checkout (V1.5)
* **Backend Status**: `[NOT YET IMPLEMENTED]`
* **Flutter Status**: `[BLOCKED BY BACKEND]`
* **Scope (When Unblocked)**:
  * Teacher marks entry grid and published report cards (Phase 8).
  * Daily timetable schedule grid and student homework submissions (Phase 9).
  * Online fee payments via Razorpay/Cashfree SDK (Phase 10).
* **Backend Gate**: Backend V1.5 specifications and endpoints merged and verified.

