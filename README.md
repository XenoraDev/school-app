# School App

Flutter client for the School API. Phase 0 provides the shared network and error-handling foundation. Phase 1 implements school-slug login, secure session storage, MFA verification and enrollment, `/common/me` profile and ability loading, logout, and forced local logout after an unauthorized response.

## Configure and run

The development API defaults to `http://localhost:8000/api/v1`. Override it at build or run time when needed:

```sh
flutter run --dart-define=API_BASE_URL=https://your-api-host/api/v1
```

Staging and production URLs remain intentionally unconfigured until deployment endpoints are provided.

## Verify

```sh
flutter analyze
flutter test
```

See [docs/PHASE_TRACKER.md](docs/PHASE_TRACKER.md) for implementation status and [docs/API_CONTRACT.md](docs/API_CONTRACT.md) for the API request and response contracts.
