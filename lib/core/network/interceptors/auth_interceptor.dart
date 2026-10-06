import 'package:dio/dio.dart';

/// Optional token supplier interface for future Phase 1 authentication integration.
///
/// NOTE: Token storage and session management are strictly Phase 1 and are not
/// implemented in Phase 0.
abstract interface class AuthTokenProvider {
  Future<String?> getToken();
}

/// Dio interceptor for request headers.
///
/// - Attaches `Accept: application/json` to every request.
/// - Sets `Content-Type: application/json` for requests with JSON body if not present.
/// - Optionally queries [AuthTokenProvider] for an existing Bearer token.
class AuthInterceptor extends Interceptor {
  final AuthTokenProvider? tokenProvider;

  AuthInterceptor({this.tokenProvider});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = 'application/json';

    if (tokenProvider != null) {
      try {
        final token = await tokenProvider!.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
        // Token retrieval failure should not crash request setup in Phase 0
      }
    }

    return handler.next(options);
  }
}

