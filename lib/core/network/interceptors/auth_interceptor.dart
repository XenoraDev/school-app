import 'package:dio/dio.dart';

/// Optional token supplier interface for Bearer token injection.
///
/// Implemented by [SecureStorageService].
abstract interface class AuthTokenProvider {
  Future<String?> getToken();
}

/// Dio interceptor that handles request authentication headers and
/// triggers forced logout on HTTP 401 responses.
///
/// Responsibilities:
/// - Attaches `Authorization: Bearer <token>` if a token is available.
/// - Attaches `Accept: application/json` to every request.
/// - On HTTP 401 response: invokes [onUnauthorized] callback so [AuthBloc]
///   can clear storage and redirect to login — without a circular dependency.
class AuthInterceptor extends Interceptor {
  final AuthTokenProvider? tokenProvider;

  /// Called when any API response returns HTTP 401 (unauthenticated).
  ///
  /// The callback should trigger an `AuthForced401` event on [AuthBloc].
  final void Function()? onUnauthorized;

  AuthInterceptor({this.tokenProvider, this.onUnauthorized});

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
        // Token retrieval failure must not block the request.
      }
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 && onUnauthorized != null) {
      onUnauthorized!();
    }
    handler.next(err);
  }
}
