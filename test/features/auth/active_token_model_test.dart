import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/features/auth/data/models/active_token_model.dart';

void main() {
  group('ActiveTokenModel', () {
    test('parses an item of GET /auth/tokens as the API returns it', () {
      final model = ActiveTokenModel.fromJson({
        'id': 42,
        'name': 'login',
        'current': true,
        'created_at': '2026-10-06T15:00:00+00:00',
        'last_used_at': '2026-10-06T16:00:00+00:00',
        'expires_at': '2026-10-07T03:00:00+00:00',
      });

      expect(model.id, 42);
      expect(model.name, 'login');
      expect(model.isCurrent, isTrue);
      expect(model.createdAt, DateTime.utc(2026, 10, 6, 15));
      expect(model.lastUsedAt, DateTime.utc(2026, 10, 6, 16));
      expect(model.expiresAt, DateTime.utc(2026, 10, 7, 3));
    });

    test('a token that was never used has no last-used date', () {
      final model = ActiveTokenModel.fromJson({
        'id': 7,
        'name': 'login',
        'current': false,
        'created_at': '2026-10-06T15:00:00+00:00',
        'last_used_at': null,
        'expires_at': '2026-10-07T03:00:00+00:00',
      });

      expect(model.isCurrent, isFalse);
      expect(model.lastUsedAt, isNull);
      expect(model.toEntity().lastUsedAt, isNull);
    });
  });
}
