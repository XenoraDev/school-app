/// Machine-readable error codes matching the Laravel backend ErrorCode enum.
///
/// See `D:\Projects\school-api\app\Http\Api\ErrorCode.php`
enum ApiErrorCode {
  badRequest('bad_request', 400, 'Bad request.'),
  unauthenticated('unauthenticated', 401, 'Unauthenticated.'),
  forbidden('forbidden', 403, 'This action is unauthorized.'),
  notFound('not_found', 404, 'Not found.'),
  conflict('conflict', 409, 'The request conflicts with the current state.'),
  invalidState('invalid_state', 409, 'The resource is not in a state that allows this action.'),
  validationFailed('validation_failed', 422, 'The given data was invalid.'),
  idempotencyMismatch('idempotency_mismatch', 422, 'This idempotency key was already used with a different request.'),
  rateLimited('rate_limited', 429, 'Too many requests.'),
  schoolSuspended('school_suspended', 403, 'This school account is not active.'),
  serverError('server_error', 500, 'Server error.');

  final String value;
  final int defaultStatus;
  final String defaultMessage;

  const ApiErrorCode(this.value, this.defaultStatus, this.defaultMessage);

  /// Resolves an [ApiErrorCode] from backend string code or fallback HTTP status code.
  static ApiErrorCode fromValue(String? value, {int? statusCode}) {
    if (value != null) {
      for (final code in ApiErrorCode.values) {
        if (code.value == value) {
          return code;
        }
      }
    }
    if (statusCode != null) {
      return forStatus(statusCode);
    }
    return ApiErrorCode.badRequest;
  }

  /// Fallback error code resolution from HTTP status code.
  static ApiErrorCode forStatus(int status) {
    return switch (status) {
      401 => ApiErrorCode.unauthenticated,
      403 => ApiErrorCode.forbidden,
      404 => ApiErrorCode.notFound,
      409 => ApiErrorCode.conflict,
      422 => ApiErrorCode.validationFailed,
      429 => ApiErrorCode.rateLimited,
      >= 500 => ApiErrorCode.serverError,
      _ => ApiErrorCode.badRequest,
    };
  }
}

