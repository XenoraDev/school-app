import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/features/app_config/data/datasources/app_config_remote_data_source.dart';
import 'package:school_app/features/app_config/domain/entities/app_config_entity.dart';
import 'package:school_app/features/app_config/domain/repositories/app_config_repository.dart';

class AppConfigRepositoryImpl implements AppConfigRepository {
  final AppConfigRemoteDataSource _remoteDataSource;

  AppConfigRepositoryImpl({
    required AppConfigRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<AppConfigEntity> getAppConfig() async {
    try {
      final model = await _remoteDataSource.getAppConfig();
      return model.toEntity();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }

  @override
  Future<bool> checkHealth() async {
    try {
      return await _remoteDataSource.checkHealth();
    } on ApiException catch (e) {
      throw e.toFailure();
    } on NetworkException catch (e) {
      throw e.toFailure();
    }
  }
}

