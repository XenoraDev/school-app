# Backend → Flutter Phase Mapping

This document provides the definitive phase synchronization between the Laravel backend (`school-api`) and the Flutter mobile client (`school_app`).

The backend is the source of truth. Flutter work is strictly gated by verified backend API delivery.

---

## 1. Master Phase Synchronization Table

| Backend Phase | Backend Status | Backend Scope | Flutter Scope | APIs Needed | Flutter Dependencies | Start Condition | Completion Gate |
|---|---|---|---|---|---|---|---|
| **Phase 0: Foundation Closure** | **IMPLEMENTED** | API envelope (`ApiResponse`), error codes (`ErrorCode`), cursor pagination (`ListQuery`), `Idempotency-Key` middleware, audit engine. | Network infrastructure, Dio client, error mapping, cursor pagination helper, base state classes. | `GET /api/v1/health`<br>`GET /api/v1/app-config` | None | **Can start immediately** | `Dio` client configured; parses `ApiResponse`, `ErrorCode`, and `meta.request_id`; health check test passes. |
| **Phase 1: Authentication & Platform Bootstrap** | **IMPLEMENTED** | School slug login, Bearer tokens via Sanctum, MFA TOTP + recovery codes, session revocation, `GET /common/me`. | School slug selection, Login screen, MFA verification & enrollment UI, Secure token storage, Splash session resume, Profile/Logout. | `POST /auth/login`<br>`POST /auth/mfa/verify`<br>`POST /auth/mfa/enroll`<br>`POST /auth/mfa/confirm`<br>`POST /auth/mfa/disable`<br>`GET /common/me`<br>`POST /auth/logout`<br>`POST /auth/logout-all`<br>`GET /auth/tokens`<br>`DELETE /auth/tokens/{id}`<br>`POST /auth/password/change` | Flutter Phase 0 | **Can start immediately** | Login flow handles complete, `mfa_required`, and `mfa_enrollment_required` states; tokens stored securely; `GET /common/me` parsed. |
| **Phase 2: School Setup & Academic Structure (Teacher Slice)** | **IMPLEMENTED** | Teaching assignments, TeacherScope, class teacher leads, active section and subject scopes. | Teacher Dashboard, My Sections list, My Subjects list, Class detail view with lead teacher badge. | `GET /teacher/my/sections`<br>`GET /teacher/my/subjects` | Flutter Phase 1 | **Can start immediately** | Teacher logs in $\rightarrow$ routes to Teacher Home $\rightarrow$ displays sections and subjects from `/teacher/my/*`; shows empty state if unassigned. |
| **Phase 2: School Setup & Academic Structure (Admin Slice)** | **IMPLEMENTED** | Setup checklist, Academic years (activate/close), terms, grade levels, sections, subjects, staff directory, roles & permissions. | Admin Dashboard, Setup Wizard, Academic Years, Sections, Staff Directory, Roles & Permissions UI with step-up password confirmation. | `/school/setup`<br>`/school/profile`<br>`/school/settings`<br>`/school/academic-years*`<br>`/school/terms*`<br>`/school/grade-levels*`<br>`/school/sections*`<br>`/school/subjects*`<br>`/school/curriculum*`<br>`/school/staff*`<br>`/school/roles*`<br>`/school/permissions` | Flutter Phase 1 | **Can start immediately** | School Admin logs in $\rightarrow$ routes to Admin Shell $\rightarrow$ loads staff roster, academic year list, and sections with full CRUD & step-up password dialog. |
| **Phase 3: Students, Guardians, Admissions & Enrollment** | **NOT YET IMPLEMENTED** | Students table, guardian relationships, admissions pipeline, enrollments per year/section, student documents. | Student directory, Student detail profile, Guardian cards, Enrollment history view, Section roster. | `/school/students*`<br>`/school/guardians*`<br>`/school/admissions*`<br>`/school/enrollments*`<br>`/parent/children*` | Flutter Phase 2 (Teacher & Admin) | **BLOCKED** — Wait for backend Phase 3 PR merge & API contract verification | Backend Phase 3 routes live and tested in `school-api` $\rightarrow$ API contract snapshot verified $\rightarrow$ Flutter Phase 3 commences. |
| **Phase 4: Teachers' Workspace & Attendance** | **NOT YET IMPLEMENTED** | Daily attendance sessions, bulk marking, corrections log, locks, parent attendance read view. | Teacher Attendance Marking Screen, Bulk toggles, Attendance Calendar, Parent Child Attendance View. | `/teacher/my/attendance*`<br>`/school/attendance*`<br>`/parent/children/{id}/attendance` | Flutter Phase 2 (Teacher) & Phase 3 | **BLOCKED** — Wait for backend Phase 4 | Attendance session and bulk submit endpoints live in backend $\rightarrow$ contract verified $\rightarrow$ Flutter Phase 4 commences. |
| **Phase 5: Fees & Payments (Offline First)** | **NOT YET IMPLEMENTED** | Fee heads/structures, installment charges, student ledger entries, receipts, offline cash collection. | Fee statement, Ledger view, Cashier counter collection, Receipt PDF viewer, Parent fee breakdown. | `/school/fee-*`<br>`/school/payments`<br>`/school/receipts*`<br>`/parent/children/{id}/fees` | Flutter Phase 3 | **BLOCKED** — Wait for backend Phase 5 | Backend fee ledger and receipt generation live in backend $\rightarrow$ contract verified $\rightarrow$ Flutter Phase 5 commences. |
| **Phase 6: Notices & In-App Notifications** | **NOT YET IMPLEMENTED** | Notice publishing with audience resolution, in-app notification inbox, read receipts. | Noticeboard feed, Circular viewer, Notification Inbox with unread counters. | `/common/notices`<br>`/common/notifications*`<br>`/school/notices*` | Flutter Phase 1 | **BLOCKED** — Wait for backend Phase 6 | In-app notification endpoints live in backend $\rightarrow$ contract verified $\rightarrow$ Flutter Phase 6 commences. |
| **Phase 7: Reporting, Exports & Dashboards** | **NOT YET IMPLEMENTED** | Attendance/fee reports, asynchronous CSV export jobs (`RequiresSchool`), summary metrics. | Reports viewer, Export status polling (`/common/operations/{id}`), Download manager. | `/school/reports/*`<br>`/common/operations/*` | Flutter Phases 3–5 | **BLOCKED** — Wait for backend Phase 7 | Export worker and report endpoints live in backend $\rightarrow$ contract verified. |
| **Phase 8: Exams & Results (V1.5)** | **NOT YET IMPLEMENTED** | Exam schedules, marks entry per enrollment, grading schemes, result runs, report cards. | Teacher marks entry grid, Report card viewer, Student result summary. | `/school/exams*`<br>`/teacher/my/marks*`<br>`/parent/children/{id}/results` | Flutter Phase 4 | **BLOCKED** — Wait for backend Phase 8 | Exam and marks entry endpoints live in backend $\rightarrow$ contract verified. |
| **Phase 9: Timetable & Homework (V1.5)** | **NOT YET IMPLEMENTED** | Timetables, conflict detection, homework assignments, student submissions. | Daily timetable schedule grid, Homework assignment manager, Homework submission view. | `/school/timetables*`<br>`/teacher/my/timetable*`<br>`/student/me/timetable` | Flutter Phases 2 & 3 | **BLOCKED** — Wait for backend Phase 9 | Timetable and homework endpoints live in backend $\rightarrow$ contract verified. |
| **Phase 10: Online Payments & Parent Portal (V1.5)** | **NOT YET IMPLEMENTED** | Payment gateway integrations (Razorpay/Cashfree), webhook processing, online receipts. | In-app fee checkout, Payment gateway SDK / webview, Instant receipt download. | `/parent/children/{id}/payments/checkout`<br>`/parent/children/{id}/payments/verify` | Flutter Phase 5 | **BLOCKED** — Wait for backend Phase 10 | Payment gateway backend contract verified. |
| **Phase 11: SaaS Billing & Platform Operations** | **NOT YET IMPLEMENTED** | Plan limits, subscription billing, tenant usage. | N/A (Web panel only; mobile app not affected). | `/platform/*` | N/A | **N/A** (Platform console only) | N/A |
| **Phase 12: V2 Features (Transport, Library, Push)** | **NOT YET IMPLEMENTED** | Push notification delivery (FCM), transport tracking, library book issue. | FCM push notification handler, Transport route map, Library book search. | `/notifications/device-tokens`<br>`/transport/*`<br>`/library/*` | Flutter Phase 6 | **BLOCKED** — Wait for backend V2 delivery | Backend V2 endpoints live. |

---

## 2. Gating and Promotion Rule

```
[Backend Phase N]
       │
       ▼
1. Backend implementation complete & green in CI
2. Verify API contract in routes/api.php & tests
3. Document contract updates in API_CONTRACT.md
       │
       ▼
[Flutter Phase N Eligible to Start]
       │
       ▼
4. Implement Flutter Data Layer (DTOs, Repositories)
5. Implement Flutter Domain Layer (Entities, Use Cases)
6. Implement Flutter Presentation Layer (Bloc, UI Screens)
7. Execute Flutter Unit & Widget Test Suite
       │
       ▼
[Flutter Phase N Completion Gate Passed]
       │
       ▼
Move to Next Eligible Phase
```

