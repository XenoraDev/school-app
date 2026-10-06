# Phase Implementation Tracker

This document tracks progress and completion gates across both backend delivery and Flutter mobile application development.

---

## 1. Master Phase Tracker

| Phase | Phase Name | Backend Implemented | API Verified | Flutter Implemented | Flutter Tested | Overall Phase Status |
|---|---|:---:|:---:|:---:|:---:|:---:|
| **Phase 0** | **Foundation & Network Core** | [x] | [x] | [ ] | [ ] | **READY TO IMPLEMENT** |
| **Phase 1** | **Authentication, Session & MFA** | [x] | [x] | [x] | [x] | **COMPLETE** |
| **Phase 2A** | **Teacher Workspace (Sections/Subjects)** | [x] | [x] | [ ] | [ ] | **READY TO IMPLEMENT** |
| **Phase 2B** | **School Structure & Staff Directory** | [x] | [x] | [ ] | [ ] | **READY TO IMPLEMENT** |
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
* [ ] **Flutter Implementation**:
  * [ ] Configure `Dio` network client with base URLs and timeouts.
  * [ ] Implement `AuthInterceptor` (attaches Bearer token, handles JSON headers).
  * [ ] Implement `ErrorInterceptor` (deserializes `ApiResponse::error` into typed `Failure` objects).
  * [ ] Implement `ListQuery` helper for cursor pagination query parameters.
  * [ ] Implement `AppConfig` repository consuming `GET /api/v1/app-config`.
* [ ] **Flutter Testing**:
  * [ ] Unit test: `ApiResponse` envelope parsing.
  * [ ] Unit test: `ErrorCode` mapping (400, 401, 403, 404, 409, 422, 429, 500).
  * [ ] Widget test: Network error banner rendering.

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
  * [ ] Logout-all and change-password UI (repository/API support exists; deferred to account settings work).
* [x] **Flutter Testing**:
  * [x] Unit test: pending-token login state and secure storage.
  * [x] Unit test: forced 401 event clears local auth data.
  * [x] Widget test: login required-field validation and error message rendering.

---

### Phase 2A: Teacher Workspace (Sections & Subjects)
* [x] **Backend Completion**: Teaching assignments, `TeacherScope`, active sections and subjects routes (`routes/api.php`, `MyScopeController.php`).
* [x] **API Verification**: Verified against `school-api` source code.
* [ ] **Flutter Implementation**:
  * [ ] Teacher Dashboard Shell (`StatefulShellRoute`).
  * [ ] My Sections Screen (`GET /teacher/my/sections`).
  * [ ] Section Card widget (name, room, grade level, lead teacher badge, subject chips).
  * [ ] My Subjects Screen (`GET /teacher/my/subjects`).
  * [ ] Empty state view for teachers with no active teaching assignments.
* [ ] **Flutter Testing**:
  * [ ] Unit test: Parsing `TeacherSection` and `TeacherSubject` JSON DTOs.
  * [ ] Widget test: Rendering sections list, empty state, and error retry.

---

### Phase 2B: School Administration Setup & Structure
* [x] **Backend Completion**: School profile/settings, academic years (activate/close), terms, grade levels, sections, subjects, staff directory, roles & permissions (`routes/api.php`, `SchoolApiController.php`).
* [x] **API Verification**: Verified against `school-api` source code.
* [ ] **Flutter Implementation**:
  * [ ] Admin Dashboard Shell.
  * [ ] Setup Checklist Screen (`GET /school/setup`).
  * [ ] Academic Years Screen (`GET/POST /school/academic-years`, activate, close).
  * [ ] Sections Management Screen (`GET/POST /school/sections`, assign class teacher).
  * [ ] Staff Directory Screen (`GET/POST /school/staff`, disable/enable login).
  * [ ] Roles & Permissions Screen (`GET /school/roles`, update permissions with step-up password).
* [ ] **Flutter Testing**:
  * [ ] Unit test: Academic Year activate/close state logic.
  * [ ] Widget test: Step-up password dialog validation.

---

### Phases 3–12: Future Phases
* **Status**: **BLOCKED BY BACKEND**. Implementation will be unblocked phase-by-phase when corresponding backend PRs are merged.

