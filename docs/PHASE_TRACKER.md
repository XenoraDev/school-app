# Phase Implementation Tracker

This document tracks progress and completion gates across both backend delivery and Flutter mobile application development.

---

## 1. Master Phase Tracker

| Phase | Phase Name | Backend Implemented | API Verified | Flutter Implemented | Flutter Tested | Overall Phase Status |
|---|---|:---:|:---:|:---:|:---:|:---:|
| **Phase 0** | **Foundation & Network Core** | [x] | [x] | [x] | [x] | **COMPLETE** |
| **Phase 1** | **Authentication, Session & MFA** | [x] | [x] | [x] | [x] | **COMPLETE** |
| **Phase 2A** | **Teacher Workspace (Sections/Subjects)** | [x] | [x] | [x] | [x] | **COMPLETE** |
| **Phase 2B** | **School Structure & Staff Directory** | [x] | [x] | [x] | [x] | **COMPLETE (core scope; deferred items below stay open)** |
| **Phase 3** | **Students, Guardians & Admissions** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |
| **Phase 4** | **Teachers' Attendance Workspace** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |
| **Phase 5** | **Fees Ledger & Offline Collection** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |
| **Phase 6** | **Notices & In-App Notifications** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |
| **Phase 7** | **Reports & Asynchronous Exports** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |
| **Phase 8** | **Exams & Results (V1.5)** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |
| **Phase 9** | **Timetable & Homework (V1.5)** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |
| **Phase 10** | **Online Payments (V1.5)** | [ ] | [ ] | [ ] | [ ] | **BLOCKED BY BACKEND** |

---

## 2. Detailed Task Tracker for Active Phases

### Phase 0: Foundation & Network Core
* [x] **Backend Completion**: API envelope, error codes, cursor pagination, rate limiting (`routes/api.php`, `ApiResponse.php`, `ListQuery.php`).
* [x] **API Verification**: Verified against `school-api` source code and test suite.
* [x] **Flutter Implementation**:
  * [x] Configure `Dio` network client with base URLs and timeouts.
  * [x] Implement `AuthInterceptor` (attaches Bearer token, handles JSON headers).
  * [x] Implement `ErrorInterceptor` (deserializes `ApiResponse::error` into typed `Failure` objects).
  * [x] Implement `ListQuery` helper for cursor pagination query parameters.
  * [x] Implement `AppConfig` repository consuming `GET /api/v1/app-config`.
* [x] **Flutter Testing**:
  * [x] Unit test: `ApiResponse` envelope parsing.
  * [x] Unit test: `ErrorCode` mapping (400, 401, 403, 404, 409, 422, 429, 500).
  * [x] Widget test: Network error banner rendering (`ErrorStateView`).

---

### Phase 1: Authentication, Session & MFA Engine
* [x] **Backend Completion**: Multi-tenant login by slug, Sanctum Bearer tokens, MFA TOTP + recovery codes, session revocation (`routes/api.php`, `LoginController.php`, `MfaController.php`, `SessionController.php`).
* [x] **API Verification**: Verified against `school-api` source code.
* [x] **Flutter Implementation**:
  * [x] Secure Bearer token persistence and school slug cache in secure storage.
  * [x] Login screen and `POST /auth/login` flow.
  * [x] MFA verification with TOTP and recovery codes.
  * [x] MFA enrollment, confirmation, QR display, and one-time recovery code display.
  * [x] Startup session restoration and `/common/me` profile/abilities loading.
  * [x] Current-device logout and local session clearing.
  * [x] Forced local logout after any HTTP 401 response.
  * [x] Logout-all and change-password UI (Account security at `/profile/security`: change password and sign out of all devices; both end the local session after the server revokes every token).
* [x] **Flutter Testing**:
  * [x] Unit test: pending-token login state and secure storage.
  * [x] Unit test: forced 401 event clears local auth data.
  * [x] Widget test: login required-field validation and error message rendering.
  * [x] Account security: cubit, session-end and widget tests (change password, server field errors, sign-out everywhere, failure keeps the session).
  * [x] Active sessions (Account security > Active sessions): list of device tokens with created, last-used and expiry dates, current session marked, sign out of other sessions with confirmation, list refresh, 404 message, loading, empty, error/retry and saving states.
  * [x] Active sessions: cubit and widget tests (load, retry, revoke, current session never revoked, one change at a time, 404, stale list answer).

---

### Phase 2A: Teacher Workspace (Sections & Subjects)
* [x] **Backend Completion**: Teaching assignments, `TeacherScope`, active sections and subjects routes (`routes/api.php`, `MyScopeController.php`).
* [x] **API Verification**: Verified against `school-api` source code.
* [x] **Flutter Implementation**:
  * [x] Ability-aware teacher workspace shell with separate Sections and Subjects destinations.
  * [x] My Sections screen (`GET /teacher/my/sections`) and section detail from the returned scoped data.
  * [x] Section cards with room, grade/year, class-teacher badge, and subject chips.
  * [x] My Subjects screen (`GET /teacher/my/subjects`) with assigned sections.
  * [x] Independent loading, error/retry, and unassigned empty states.
  * [x] Route entry requires teacher/staff audience plus `classes.view` or `subjects.view`; each destination is limited by its specific ability.
* [x] **Flutter Testing**:
  * [x] Unit tests: Teacher section and subject DTO/entity mapping.
  * [x] Unit tests: Ability-aware workspace eligibility and independent BLoC loading/retry.
  * [x] Widget tests: Section/subject empty states and section badge/subject rendering.

---

### Phase 2B: School Administration Setup & Structure
* [x] **Backend Completion**: School profile/settings, academic years (activate/close), terms, grade levels, sections, subjects, staff directory, roles & permissions (`routes/api.php`, `SchoolApiController.php`).
* [x] **API Verification**: Verified against `school-api` source code.
* [x] **Flutter Implementation**:
  * [x] Separate Admin shell with staff-and-ability route guard and ability-filtered navigation; no routing to Admin from `user_type` alone.
  * [x] School setup checklist, school profile, and versioned settings (`/school/setup`, `/school/profile`, `/school/settings`).
  * [x] Academic years create/update/activate/step-up close and terms create/update/delete.
  * [x] Grade level CRUD/archive/reorder; section CRUD/close/reopen/class-teacher assignment.
  * [x] Subject CRUD/archive and curriculum replacement.
  * [x] Staff directory create/update/archive and enable/disable existing logins.
  * [x] Teaching assignments (`/admin/teaching-assignments`): list with status filter, assign teacher, end and reactivate; needs `classes.view`, changes need `teaching_assignments.manage`.
  * [x] Role and permission catalogue viewing and permission replacement with password confirmation.
  * [x] Cursor pagination plus loading, empty, retryable error, and backend error handling through the shared interceptors.
  * [ ] Invitation/provisioning, custom role create/rename/delete, staff role assignment, and offline mutations remain deferred.
* [x] **Flutter Testing**:
  * [x] Unit tests: endpoint constants, response DTO parsing, and admin/teacher workspace ability eligibility.
  * [x] Cubit tests: checklist failure/retry and successful loading.
  * [x] Teaching assignments: `fetchAll` paging, screen list/filter/empty/error states, assign (choices, validation, server rejection), end with confirmation, reactivate, read-only view, busy guard.
  * [x] Widget test: setup checklist rendering.

---

### Phases 3–12: Future Phases
* **Status**: **BLOCKED BY BACKEND**. Implementation will be unblocked phase-by-phase when corresponding backend PRs are merged.

