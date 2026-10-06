import 'package:dio/dio.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';

/// Intercepts non-2xx Dio responses and deserializes the backend error envelope
/// into typed [ApiException] or [NetworkException].
///
/// See `API_CONTRACT.md §1.4` and `ApiResponse::error` in backend.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;

    if (response != null && response.data is Map<String, dynamic>) {
      final json = response.data as Map<String, dynamic>;
      final rawCode = json['code'] as String?;
      final rawMessage = json['message'] as String?;
      final requestId = json['request_id'] as String?;

      Map<String, List<String>>? validationErrors;
      if (json['errors'] is Map) {
        final rawErrors = json['errors'] as Map;
        validationErrors = rawErrors.map((key, val) {
          final messages = val is List
              ? val.map((e) => e.toString()).toList()
              : [val.toString()];
          return MapEntry(key.toString(), messages);
        });
      }

      final errorCode = ApiErrorCode.fromValue(
        rawCode,
        statusCode: response.statusCode,
      );

      final message = rawMessage ?? errorCode.defaultMessage;

      final apiException = ApiException(
        message: message,
        errorCode: errorCode,
        statusCode: response.statusCode,
        errors: validationErrors,
        requestId: requestId,
      );

      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: response,
          type: err.type,
          error: apiException,
          message: message,
        ),
      );
    }

    // Network / Transport level errors
    final (networkMessage, requestId) = _resolveNetworkErrorMessage(err);
    final networkException = NetworkException(networkMessage, requestId: requestId);

    return handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: response,
        type: err.type,
        error: networkException,
        message: networkMessage,
      ),
    );
  }

  (String, String?) _resolveNetworkErrorMessage(DioException err) {
    String? requestId;
    final headers = err.response?.headers;
    if (headers != null) {
      final val = headers['x-request-id'] ?? headers['X-Request-ID'];
      if (val != null && val.isNotEmpty) {
        requestId = val.first;
      }
    }

    final message = switch (err.type) {
      DioExceptionType.connectionTimeout =>
        'Connection timed out while reaching the server.',
      DioExceptionType.sendTimeout =>
        'Send request timed out.',
      DioExceptionType.receiveTimeout =>
        'Server took too long to respond.',
      DioExceptionType.badCertificate =>
        'Security certificate verification failed.',
      DioExceptionType.connectionError =>
        'Unable to connect to the server. Please check your connection.',
      DioExceptionType.cancel =>
        'Request was cancelled.',
      _ => err.message ?? 'An unexpected network error occurred.',
    };

    return (message, requestId);
  }
}

