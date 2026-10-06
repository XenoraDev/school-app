import 'package:school_app/features/app_config/domain/entities/app_config_entity.dart';

/// Repository interface for app configuration and backend health checks.
abstract interface class AppConfigRepository {
  /// Fetches public app branding and metadata.
  Future<AppConfigEntity> getAppConfig();

  /// Verifies connectivity to the backend /health endpoint.
  Future<bool> checkHealth();
}

