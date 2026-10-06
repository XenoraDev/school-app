import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/errors/api_error_code.dart';

void main() {
  group('ApiErrorCode', () {
    test('contains all error codes matching backend ErrorCode.php', () {
      expect(ApiErrorCode.badRequest.value, 'bad_request');
      expect(ApiErrorCode.badRequest.defaultStatus, 400);

      expect(ApiErrorCode.unauthenticated.value, 'unauthenticated');
      expect(ApiErrorCode.unauthenticated.defaultStatus, 401);

      expect(ApiErrorCode.forbidden.value, 'forbidden');
      expect(ApiErrorCode.forbidden.defaultStatus, 403);

      expect(ApiErrorCode.schoolSuspended.value, 'school_suspended');
      expect(ApiErrorCode.schoolSuspended.defaultStatus, 403);

      expect(ApiErrorCode.notFound.value, 'not_found');
      expect(ApiErrorCode.notFound.defaultStatus, 404);

      expect(ApiErrorCode.conflict.value, 'conflict');
      expect(ApiErrorCode.conflict.defaultStatus, 409);

      expect(ApiErrorCode.invalidState.value, 'invalid_state');
      expect(ApiErrorCode.invalidState.defaultStatus, 409);

      expect(ApiErrorCode.validationFailed.value, 'validation_failed');
      expect(ApiErrorCode.validationFailed.defaultStatus, 422);

      expect(ApiErrorCode.idempotencyMismatch.value, 'idempotency_mismatch');
      expect(ApiErrorCode.idempotencyMismatch.defaultStatus, 422);

      expect(ApiErrorCode.rateLimited.value, 'rate_limited');
      expect(ApiErrorCode.rateLimited.defaultStatus, 429);

      expect(ApiErrorCode.serverError.value, 'server_error');
      expect(ApiErrorCode.serverError.defaultStatus, 500);
    });

    test('resolves correctly fromValue with exact code strings', () {
      expect(
        ApiErrorCode.fromValue('validation_failed'),
        ApiErrorCode.validationFailed,
      );
      expect(
        ApiErrorCode.fromValue('unauthenticated'),
        ApiErrorCode.unauthenticated,
      );
      expect(
        ApiErrorCode.fromValue('school_suspended'),
        ApiErrorCode.schoolSuspended,
      );
      expect(
        ApiErrorCode.fromValue('not_found'),
        ApiErrorCode.notFound,
      );
    });

    test('falls back to status code when code string is unknown or null', () {
      expect(
        ApiErrorCode.fromValue('unknown_custom_code', statusCode: 401),
        ApiErrorCode.unauthenticated,
      );
      expect(
        ApiErrorCode.fromValue(null, statusCode: 403),
        ApiErrorCode.forbidden,
      );
      expect(
        ApiErrorCode.fromValue(null, statusCode: 404),
        ApiErrorCode.notFound,
      );
      expect(
        ApiErrorCode.fromValue(null, statusCode: 409),
        ApiErrorCode.conflict,
      );
      expect(
        ApiErrorCode.fromValue(null, statusCode: 422),
        ApiErrorCode.validationFailed,
      );
      expect(
        ApiErrorCode.fromValue(null, statusCode: 429),
        ApiErrorCode.rateLimited,
      );
      expect(
        ApiErrorCode.fromValue(null, statusCode: 502),
        ApiErrorCode.serverError,
      );
    });
  });
}

