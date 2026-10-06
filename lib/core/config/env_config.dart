/// Application deployment environments.
enum AppEnvironment {
  dev,
  staging,
  prod,
}

/// Environment configuration holder.
///
/// In accordance with the project architecture:
/// - [dev] defaults to the verified local development URL `http://localhost:8000/api/v1`
///   (customizable via compile-time define `API_BASE_URL`).
/// - [staging] and [prod] URLs are not invented and remain "TO BE CONFIGURED"
///   until verified backend deployments are provided.
class EnvConfig {
  final AppEnvironment environment;
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  const EnvConfig._({
    required this.environment,
    required this.baseUrl,
  })  : connectTimeout = const Duration(seconds: 15),
        receiveTimeout = const Duration(seconds: 30),
        sendTimeout = const Duration(seconds: 15);

  /// Verified local development environment.
  factory EnvConfig.dev({String? baseUrl}) {
    return EnvConfig._(
      environment: AppEnvironment.dev,
      baseUrl: baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8000/api/v1',
          ),
    );
  }

  /// Staging environment - URL is TO BE CONFIGURED.
  factory EnvConfig.staging({String? baseUrl}) {
    return EnvConfig._(
      environment: AppEnvironment.staging,
      baseUrl: baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'TO_BE_CONFIGURED',
          ),
    );
  }

  /// Production environment - URL is TO BE CONFIGURED.
  factory EnvConfig.prod({String? baseUrl}) {
    return EnvConfig._(
      environment: AppEnvironment.prod,
      baseUrl: baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'TO_BE_CONFIGURED',
          ),
    );
  }

  bool get isConfigured => baseUrl != 'TO_BE_CONFIGURED' && baseUrl.isNotEmpty;
}
