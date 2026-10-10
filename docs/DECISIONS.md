# Architectural Decisions & Open Verifications

This document records architectural decisions inherited from the Laravel backend (`school-api/docs/DECISIONS.md`), mobile-specific architectural choices, and items currently marked as **TO BE VERIFIED**.

---

## 1. Inherited Backend Decisions (Established & Binding)

| ID | Topic | Decision Outcome | Impact on Flutter Mobile App |
|---|---|---|---|
| **D-01** | **Entity Identifiers** | BigInt internal PK + 26-character ULID `public_id`. | Flutter models consume and serialize ULID strings in all URL paths and request bodies (e.g., `academic_year: "01J9X..."`). Internal database IDs are never exposed or expected. |
| **D-02** | **Transport & Tokens** | Web panel uses HttpOnly cookie bridge; Mobile apps use Sanctum Bearer tokens (`sch_` prefix, max 30-day TTL). | Flutter uses Bearer token authorization on all `/api/v1/*` endpoints. Tokens are stored securely in hardware-backed storage (`flutter_secure_storage`). |
| **D-03** | **Identity Realms** | Platform users are segregated in `platform_users`; School users are in `users`. | The mobile application supports **only the school realm** (`auth:sanctum`). Platform console operations (`/platform/*`) are out of mobile scope. |
| **D-04** | **Login Identifier** | Per-school unique `login_identifier` (`users.login_identifier`), scoped by `school_id`. | Login requires `school` (slug) + `identifier` (lowercased email/username) + `password`. Global uniqueness is not assumed. |
| **D-05** | **Archival Policy** | Master data is archived via `status: "archived"`; no Laravel `SoftDeletes`. | Flutter displays archived records with a read-only badge; deletion of master records is not supported in the UI (except terms). |
| **D-08** | **Transactional Mail** | `EMAIL_AUTH_ENABLED=false` until a mail provider is integrated. Password reset routes return HTTP 503. | Password reset flow on mobile is disabled until a live mailer is configured on the backend. |
| **D-14** | **List Pagination** | Cursor pagination for all collections (`per_page`, `cursor`, `has_more`, `next_cursor`). | Flutter list views consume cursor pagination. Unbounded lists are prohibited by the backend (400 if `per_page > 100`). |
| **D-17** | **Money & Dates** | Money represented in integer minor units (paise); Instants stored in UTC. | Flutter parses all financial amounts as minor units (e.g., `50000` paise = ₹500.00). Dates formatted to user locale on device. |
| **D-22** | **Roles & Permissions** | Seven seeded default roles cannot be deleted or renamed; permissions are editable inside no-escalation. | Flutter UI respects immutable default roles and dynamically evaluates `abilities` array from `GET /common/me`. |

---

## 2. Established Flutter Mobile Architecture Decisions

| # | Topic | Decision | Rationale |
|---|---|---|---|
| **F-01** | **Architecture Pattern** | Feature-First Clean Architecture (`core/`, `features/`, `shared/`). | Enforces strict separation of concerns, testability, and isolated domain slices matching backend modules. |
| **F-02** | **State Management** | `flutter_bloc` (Bloc & Cubit). | Predictable unidirectional state transitions, explicit state models (`Initial`, `Loading`, `Success`, `Failure`), and auditability. |
| **F-03** | **HTTP Client** | `dio` with dedicated interceptors. | Native support for interceptors, request cancellation, timeouts, and error handling. |
| **F-04** | **Token Storage** | `flutter_secure_storage` (Android EncryptedSharedPreferences / iOS Keychain). | Guarantees hardware-backed encryption at rest for authentication tokens and sensitive credentials. |
| **F-05** | **Design System** | Material 3 (`useMaterial3: true`) with domain-specific `ThemeExtension`. | Modern design tokens with semantic status colors (attendance, fees, grades). |

---

## 3. Unknowns / TO BE VERIFIED (Requiring Product/Backend Approval)

| # | Item | Current State | Question / Decision Needed |
|---|---|---|---|
| **TBV-01** | **School Discovery on Mobile** | `POST /auth/login` requires exact `school` slug (e.g., `"springfield"`). | Should Flutter prompt users for a manual school code/slug, or will the backend expose a public discovery endpoint (e.g., `GET /api/v1/schools/lookup?slug=...`)? |
| **TBV-02** | **Parent Login Credential** | Decision `D-04` reserves phone/OTP login for parents in Phase 3. | When Phase 3 ships, will parent login use password authentication, SMS OTP, or email credentials? |
| **TBV-03** | **Push Notification Delivery** | In-app notifications ship in Phase 6; mobile push is scheduled for V2 / Phase 32. | Will Firebase Cloud Messaging (FCM) device token registration be introduced in Phase 6 for mobile alerts, or strictly in V2? |
| **TBV-04** | **Offline Attendance Sync Rules** | Teachers may experience connectivity drops during attendance marking. | If Flutter caches attendance submissions offline, what conflict-resolution rules apply if another staff member marks the same section concurrently? |
| **TBV-05** | **Workspace landing signal for staff** | **RESOLVED (teaching signal).** Laravel PR #10 added a boolean `is_teaching` to the school `/common/me` (`TeacherScope::profileFor($user) !== null`). Flutter reads it as the nullable `AccountProfile.isTeaching`: a staff account with `false` (for example a Receptionist) lands on `/profile` and the teacher route guard agrees; `true` keeps the Teacher workspace; a missing field (older API) keeps the previous behavior. Teacher-type logins and the admin gate are unchanged. | **Still open:** the Accountant holds `staff.view`, which opens the admin gate, so it keeps landing in the read-only Admin. Landing it on `/profile` needs a separate decision (a server-side admin-landing signal, or a landing rule not based on `staff.view`). The signal does not say whether a teacher has assignments. |

