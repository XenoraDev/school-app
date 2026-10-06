import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/network/interceptors/error_interceptor.dart';

void main() {
  late ErrorInterceptor interceptor;

  setUp(() {
    interceptor = ErrorInterceptor();
  });

  group('ErrorInterceptor', () {
    test('deserializes backend 422 validation error envelope into ApiException', () async {
      final requestOptions = RequestOptions(path: '/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 422,
          data: {
            'message': 'The given data was invalid.',
            'code': 'validation_failed',
            'errors': {
              'identifier': ['The identifier field is required.'],
            },
            'request_id': '01J9XVALIDATION123',
          },
        ),
      );

      final handler = _TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.rejectedException, isNotNull);
      final error = handler.rejectedException!.error;
      expect(error, isA<ApiException>());

      final apiException = error as ApiException;
      expect(apiException.message, 'The given data was invalid.');
      expect(apiException.errorCode, ApiErrorCode.validationFailed);
      expect(apiException.statusCode, 422);
      expect(apiException.requestId, '01J9XVALIDATION123');
      expect(apiException.errors?['identifier'], [
        'The identifier field is required.',
      ]);
    });

    test('deserializes backend 401 unauthenticated envelope into ApiException', () async {
      final requestOptions = RequestOptions(path: '/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
          data: {
            'message': 'Invalid credentials.',
            'code': 'unauthenticated',
            'request_id': '01J9XAUTH401',
          },
        ),
      );

      final handler = _TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.rejectedException, isNotNull);
      final error = handler.rejectedException!.error;
      expect(error, isA<ApiException>());

      final apiException = error as ApiException;
      expect(apiException.errorCode, ApiErrorCode.unauthenticated);
      expect(apiException.statusCode, 401);
      expect(apiException.requestId, '01J9XAUTH401');
    });

    test('deserializes backend 403 school_suspended code into ApiException', () async {
      final requestOptions = RequestOptions(path: '/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 403,
          data: {
            'message': 'This school account is not active.',
            'code': 'school_suspended',
            'request_id': '01J9XSUSPENDED',
          },
        ),
      );

      final handler = _TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.rejectedException, isNotNull);
      final error = handler.rejectedException!.error;
      expect(error, isA<ApiException>());

      final apiException = error as ApiException;
      expect(apiException.errorCode, ApiErrorCode.schoolSuspended);
      expect(apiException.statusCode, 403);
    });

    test('maps connection timeout to NetworkException', () async {
      final requestOptions = RequestOptions(path: '/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
      );

      final handler = _TestErrorInterceptorHandler();
      interceptor.onError(dioException, handler);

      expect(handler.rejectedException, isNotNull);
      final error = handler.rejectedException!.error;
      expect(error, isA<NetworkException>());
      expect(
        (error as NetworkException).message,
        'Connection timed out while reaching the server.',
      );
    });
  });
}

class _TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  DioException? rejectedException;

  @override
  void reject(DioException error, [bool callNext = false]) {
    rejectedException = error;
  }
}
