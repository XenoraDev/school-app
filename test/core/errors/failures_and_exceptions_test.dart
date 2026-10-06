import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/errors/failures.dart';

void main() {
  group('ApiException to Failure mapping', () {
    test('validation_failed maps to ValidationFailure with error bag', () {
      const exception = ApiException(
        message: 'The given data was invalid.',
        errorCode: ApiErrorCode.validationFailed,
        statusCode: 422,
        errors: {
          'email': ['The email field is required.'],
          'password': ['Password must be at least 8 characters.'],
        },
        requestId: 'req_123',
      );

      final failure = exception.toFailure();

      expect(failure, isA<ValidationFailure>());
      final validationFailure = failure as ValidationFailure;
      expect(validationFailure.message, 'The given data was invalid.');
      expect(validationFailure.requestId, 'req_123');
      expect(validationFailure.errors['email'], ['The email field is required.']);
      expect(validationFailure.errors['password'], ['Password must be at least 8 characters.']);
    });

    test('unauthenticated maps to UnauthorizedFailure', () {
      const exception = ApiException(
        message: 'Unauthenticated.',
        errorCode: ApiErrorCode.unauthenticated,
        statusCode: 401,
        requestId: 'req_401',
      );

      final failure = exception.toFailure();

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.message, 'Unauthenticated.');
      expect(failure.requestId, 'req_401');
    });

    test('forbidden maps to ForbiddenFailure with isSuspended=false', () {
      const exception = ApiException(
        message: 'This action is unauthorized.',
        errorCode: ApiErrorCode.forbidden,
        statusCode: 403,
      );

      final failure = exception.toFailure();

      expect(failure, isA<ForbiddenFailure>());
      final forbiddenFailure = failure as ForbiddenFailure;
      expect(forbiddenFailure.isSuspended, isFalse);
    });

    test('school_suspended maps to ForbiddenFailure with isSuspended=true', () {
      const exception = ApiException(
        message: 'This school account is not active.',
        errorCode: ApiErrorCode.schoolSuspended,
        statusCode: 403,
      );

      final failure = exception.toFailure();

      expect(failure, isA<ForbiddenFailure>());
      final forbiddenFailure = failure as ForbiddenFailure;
      expect(forbiddenFailure.isSuspended, isTrue);
    });

    test('not_found maps to NotFoundFailure', () {
      const exception = ApiException(
        message: 'Not found.',
        errorCode: ApiErrorCode.notFound,
        statusCode: 404,
      );

      final failure = exception.toFailure();
      expect(failure, isA<NotFoundFailure>());
    });

    test('conflict maps to ConflictFailure with isInvalidState=false', () {
      const exception = ApiException(
        message: 'The request conflicts with the current state.',
        errorCode: ApiErrorCode.conflict,
        statusCode: 409,
      );

      final failure = exception.toFailure();
      expect(failure, isA<ConflictFailure>());
      expect((failure as ConflictFailure).isInvalidState, isFalse);
    });

    test('invalid_state maps to ConflictFailure with isInvalidState=true', () {
      const exception = ApiException(
        message: 'The resource is not in a state that allows this action.',
        errorCode: ApiErrorCode.invalidState,
        statusCode: 409,
      );

      final failure = exception.toFailure();
      expect(failure, isA<ConflictFailure>());
      expect((failure as ConflictFailure).isInvalidState, isTrue);
    });

    test('rate_limited maps to RateLimitedFailure', () {
      const exception = ApiException(
        message: 'Too many requests.',
        errorCode: ApiErrorCode.rateLimited,
        statusCode: 429,
      );

      final failure = exception.toFailure();
      expect(failure, isA<RateLimitedFailure>());
    });

    test('server_error maps to ServerFailure with errorCode', () {
      const exception = ApiException(
        message: 'Server error.',
        errorCode: ApiErrorCode.serverError,
        statusCode: 500,
        requestId: 'req_500',
      );

      final failure = exception.toFailure();
      expect(failure, isA<ServerFailure>());
      final serverFailure = failure as ServerFailure;
      expect(serverFailure.errorCode, ApiErrorCode.serverError);
      expect(serverFailure.statusCode, 500);
      expect(serverFailure.requestId, 'req_500');
    });

    test('NetworkException maps to NetworkFailure', () {
      const exception = NetworkException(
        'Connection timed out',
        requestId: 'req_net',
      );

      final failure = exception.toFailure();
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, 'Connection timed out');
      expect(failure.requestId, 'req_net');
    });
  });

  group('Failure value equality', () {
    test('compares failures of same type and attributes correctly', () {
      const f1 = UnauthorizedFailure(message: 'Login failed', requestId: '1');
      const f2 = UnauthorizedFailure(message: 'Login failed', requestId: '1');
      const f3 = UnauthorizedFailure(message: 'Other message', requestId: '1');

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1, isNot(equals(f3)));
    });

    test('compares ValidationFailure error map equality', () {
      const v1 = ValidationFailure(
        message: 'Invalid',
        errors: {
          'name': ['Required'],
        },
      );
      const v2 = ValidationFailure(
        message: 'Invalid',
        errors: {
          'name': ['Required'],
        },
      );
      const v3 = ValidationFailure(
        message: 'Invalid',
        errors: {
          'name': ['Must be string'],
        },
      );

      expect(v1, equals(v2));
      expect(v1, isNot(equals(v3)));
    });
  });
}

