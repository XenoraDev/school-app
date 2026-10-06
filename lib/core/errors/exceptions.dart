import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/failures.dart';

/// Exception thrown when the API returns an error response.
class ApiException implements Exception {
  final String message;
  final ApiErrorCode errorCode;
  final int? statusCode;
  final Map<String, List<String>>? errors;
  final String? requestId;

  const ApiException({
    required this.message,
    required this.errorCode,
    this.statusCode,
    this.errors,
    this.requestId,
  });

  /// Maps the technical [ApiException] to an appropriate domain [Failure].
  Failure toFailure() {
    return switch (errorCode) {
      ApiErrorCode.validationFailed || ApiErrorCode.idempotencyMismatch =>
        ValidationFailure(
          message: message,
          errors: errors ?? const {},
          requestId: requestId,
        ),
      ApiErrorCode.unauthenticated =>
        UnauthorizedFailure(message: message, requestId: requestId),
      ApiErrorCode.forbidden =>
        ForbiddenFailure(message: message, isSuspended: false, requestId: requestId),
      ApiErrorCode.schoolSuspended =>
        ForbiddenFailure(message: message, isSuspended: true, requestId: requestId),
      ApiErrorCode.notFound =>
        NotFoundFailure(message: message, requestId: requestId),
      ApiErrorCode.conflict =>
        ConflictFailure(message: message, isInvalidState: false, requestId: requestId),
      ApiErrorCode.invalidState =>
        ConflictFailure(message: message, isInvalidState: true, requestId: requestId),
      ApiErrorCode.rateLimited =>
        RateLimitedFailure(message: message, requestId: requestId),
      _ => ServerFailure(
          message: message,
          errorCode: errorCode,
          statusCode: statusCode,
          requestId: requestId,
        ),
    };
  }

  @override
  String toString() =>
      'ApiException(code: ${errorCode.value}, status: $statusCode, message: $message, requestId: $requestId)';
}

/// Exception thrown on network transport or socket failure.
class NetworkException implements Exception {
  final String message;
  final String? requestId;

  const NetworkException(this.message, {this.requestId});

  Failure toFailure() => NetworkFailure(message: message, requestId: requestId);

  @override
  String toString() => 'NetworkException: $message';
}

