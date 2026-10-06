import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/errors/api_error_code.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/app_config/data/datasources/app_config_remote_data_source.dart';
import 'package:school_app/features/app_config/data/models/app_config_model.dart';
import 'package:school_app/features/app_config/data/repositories/app_config_repository_impl.dart';
import 'package:school_app/features/app_config/domain/entities/app_config_entity.dart';

class _FakeDataSource implements AppConfigRemoteDataSource {
  AppConfigModel? appConfigToReturn;
  bool? healthToReturn;
  Exception? exceptionToThrow;

  @override
  Future<AppConfigModel> getAppConfig() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return appConfigToReturn!;
  }

  @override
  Future<bool> checkHealth() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return healthToReturn!;
  }
}

void main() {
  late _FakeDataSource fakeDataSource;
  late AppConfigRepositoryImpl repository;

  setUp(() {
    fakeDataSource = _FakeDataSource();
    repository = AppConfigRepositoryImpl(remoteDataSource: fakeDataSource);
  });

  group('AppConfigRepositoryImpl', () {
    test('getAppConfig returns AppConfigEntity on success', () async {
      fakeDataSource.appConfigToReturn = const AppConfigModel(
        name: 'Springfield High',
        tagline: 'Motto',
        supportEmail: 'info@springfield.edu',
        primaryColor: '#1E40AF',
        logoUrl: null,
      );

      final result = await repository.getAppConfig();

      expect(result, isA<AppConfigEntity>());
      expect(result.name, 'Springfield High');
      expect(result.tagline, 'Motto');
      expect(result.supportEmail, 'info@springfield.edu');
    });

    test('checkHealth returns true on backend 200 ok', () async {
      fakeDataSource.healthToReturn = true;

      final result = await repository.checkHealth();
      expect(result, isTrue);
    });

    test('rethrows ApiException as mapped domain Failure', () async {
      fakeDataSource.exceptionToThrow = const ApiException(
        message: 'Server error.',
        errorCode: ApiErrorCode.serverError,
        statusCode: 500,
      );

      expect(
        () => repository.getAppConfig(),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('rethrows NetworkException as mapped NetworkFailure', () async {
      fakeDataSource.exceptionToThrow = const NetworkException(
        'Connection refused',
      );

      expect(
        () => repository.getAppConfig(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}

