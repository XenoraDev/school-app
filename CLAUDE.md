# School App (Flutter)

Flutter client for the multi-school School SaaS API. Laravel is the source of
truth for data, validation, tenant isolation and permissions. This app only
reflects what the API allows. Never rely on a Flutter check as security.

## Commands (run from this folder)
- `flutter analyze` and `flutter test` must both be clean before work is called done.
- Run with a different API: `flutter run --dart-define=API_BASE_URL=https://host/api/v1`.
- Staging and production URLs are not configured here. Do not add them without approval.

## Where things live
- `lib/core/` network, errors, config, `core/router/app_route_policy.dart` (route guard).
- `lib/shared/` shared widgets. `lib/features/<name>/` feature-first clean architecture
  (data / domain / presentation, Bloc or Cubit state).
- Routing and landing rules are pure functions with tests: `app_route_policy.dart`,
  `workspace_landing_policy.dart`, `teacher_route_policy.dart`. Change them only together with tests.

## Rules
- Permissions: use `profile.can('module.action')` only to show or hide UI. The API enforces access.
- Do not invent API fields or formats. Check `docs/API_CONTRACT.md` and the Laravel
  resource or test first. If unsure, ask.
- Never log or print tokens, passwords, `.env` values or personal data.
- Tests must be deterministic. Dispose routers, Cubits and controllers (`addTearDown`).
- Keep diffs focused. No unrelated reformatting. Files use LF line endings.
- Ask before: dependency changes or upgrades, Git operations (stage, commit, push,
  pull, merge, branch), deploys, anything touching staging or production.
- A feature is done only when its requirement has a test and `analyze` and `test` pass.

## Docs
- Architecture: docs/ARCHITECTURE.md · API: docs/API_CONTRACT.md · RBAC: docs/AUTH_RBAC.md
- Decisions and open questions: docs/DECISIONS.md · Roadmap: docs/DEVELOPMENT_ROADMAP.md
  · Status: docs/PHASE_TRACKER.md · Backend mapping: docs/BACKEND_FLUTTER_PHASE_MAP.md
- API repo (local): D:\Projects\school-api (see its CLAUDE.md and docs/AUTHORIZATION.md)
