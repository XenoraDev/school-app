import 'package:school_app/core/errors/api_error_code.dart';

/// Base class for all domain-level failures.
sealed class Failure {
  final String message;
  final String? requestId;

  const Failure({
    required this.message,
    this.requestId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          requestId == other.requestId;

  @override
  int get hashCode => Object.hash(runtimeType, message, requestId);

  @override
  String toString() => '$runtimeType(message: $message, requestId: $requestId)';
}

/// Network transport failure (timeouts, no internet, connection refused).
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.requestId,
  });
}

/// Server or generic API failure with backend error code.
class ServerFailure extends Failure {
  final ApiErrorCode errorCode;
  final int? statusCode;

  const ServerFailure({
    required super.message,
    required this.errorCode,
    this.statusCode,
    super.requestId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          requestId == other.requestId &&
          errorCode == other.errorCode &&
          statusCode == other.statusCode;

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, requestId, errorCode, statusCode);

  @override
  String toString() =>
      'ServerFailure(message: $message, code: ${errorCode.value}, status: $statusCode, requestId: $requestId)';
}

/// Validation failure containing field-level error messages.
class ValidationFailure extends Failure {
  final Map<String, List<String>> errors;

  const ValidationFailure({
    required super.message,
    required this.errors,
    super.requestId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ValidationFailure ||
        runtimeType != other.runtimeType ||
        message != other.message ||
        requestId != other.requestId) {
      return false;
    }
    if (errors.length != other.errors.length) return false;
    for (final entry in errors.entries) {
      final otherVal = other.errors[entry.key];
      if (otherVal == null || otherVal.length != entry.value.length) {
        return false;
      }
      for (var i = 0; i < entry.value.length; i++) {
        if (entry.value[i] != otherVal[i]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, requestId, errors.length);

  @override
  String toString() =>
      'ValidationFailure(message: $message, errors: $errors, requestId: $requestId)';
}

/// Authentication failure (HTTP 401 unauthenticated).
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    required super.message,
    super.requestId,
  });
}

/// Authorization failure (HTTP 403 forbidden or school_suspended).
class ForbiddenFailure extends Failure {
  final bool isSuspended;

  const ForbiddenFailure({
    required super.message,
    this.isSuspended = false,
    super.requestId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForbiddenFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          requestId == other.requestId &&
          isSuspended == other.isSuspended;

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, requestId, isSuspended);

  @override
  String toString() =>
      'ForbiddenFailure(message: $message, isSuspended: $isSuspended, requestId: $requestId)';
}

/// Resource not found (HTTP 404).
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.requestId,
  });
}

/// State or conflict failure (HTTP 409 conflict or invalid_state).
class ConflictFailure extends Failure {
  final bool isInvalidState;

  const ConflictFailure({
    required super.message,
    this.isInvalidState = false,
    super.requestId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          requestId == other.requestId &&
          isInvalidState == other.isInvalidState;

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, requestId, isInvalidState);

  @override
  String toString() =>
      'ConflictFailure(message: $message, isInvalidState: $isInvalidState, requestId: $requestId)';
}

/// Rate limiting failure (HTTP 429).
class RateLimitedFailure extends Failure {
  const RateLimitedFailure({
    required super.message,
    super.requestId,
  });
}
