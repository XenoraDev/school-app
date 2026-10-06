import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/features/app_config/data/models/app_config_model.dart';
import 'package:school_app/features/app_config/domain/entities/app_config_entity.dart';

void main() {
  group('AppConfigModel', () {
    test('parses JSON matching GET /api/v1/app-config backend response', () {
      final json = {
        'name': 'Springfield Academy',
        'tagline': 'Excellence in Education',
        'support_email': 'support@springfield.edu',
        'primary_color': '#1E40AF',
        'logo_url': 'https://cdn.school.internal/logo.png',
      };

      final model = AppConfigModel.fromJson(json);

      expect(model.name, 'Springfield Academy');
      expect(model.tagline, 'Excellence in Education');
      expect(model.supportEmail, 'support@springfield.edu');
      expect(model.primaryColor, '#1E40AF');
      expect(model.logoUrl, 'https://cdn.school.internal/logo.png');
    });

    test('serializes to JSON correctly', () {
      const model = AppConfigModel(
        name: 'School App',
        tagline: 'Next Generation',
        supportEmail: 'admin@school.internal',
        primaryColor: '#2563EB',
        logoUrl: null,
      );

      final json = model.toJson();

      expect(json['name'], 'School App');
      expect(json['tagline'], 'Next Generation');
      expect(json['support_email'], 'admin@school.internal');
      expect(json['primary_color'], '#2563EB');
      expect(json['logo_url'], isNull);
    });

    test('converts to domain AppConfigEntity', () {
      const model = AppConfigModel(
        name: 'Springfield Academy',
        tagline: 'Tagline',
        supportEmail: 'help@school.internal',
        primaryColor: '#000000',
        logoUrl: null,
      );

      final entity = model.toEntity();

      expect(entity, isA<AppConfigEntity>());
      expect(entity.name, 'Springfield Academy');
      expect(entity.tagline, 'Tagline');
      expect(entity.supportEmail, 'help@school.internal');
      expect(entity.primaryColor, '#000000');
      expect(entity.logoUrl, isNull);
    });
  });
}

