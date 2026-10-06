import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/network/api_response.dart';

void main() {
  group('ApiResponse', () {
    test('parses single resource success envelope correctly', () {
      final json = {
        'data': {
          'id': '01J9XABCDEF123456789012345',
          'name': 'Springfield High',
        },
        'meta': {
          'request_id': '01J9XABCDEF123456789012345',
        },
      };

      final response = ApiResponse.fromJson(
        json,
        (data) => data as Map<String, dynamic>,
      );

      expect(response.data['id'], '01J9XABCDEF123456789012345');
      expect(response.data['name'], 'Springfield High');
      expect(response.meta.requestId, '01J9XABCDEF123456789012345');
    });

    test('handles empty or missing meta gracefully', () {
      final json = {
        'data': 'simple_string',
      };

      final response = ApiResponse.fromJson(
        json,
        (data) => data as String,
      );

      expect(response.data, 'simple_string');
      expect(response.meta.requestId, isNull);
    });
  });

  group('PaginatedResponse', () {
    test('parses cursor paginated collection envelope correctly', () {
      final json = {
        'data': [
          {'id': '01J9X1', 'name': 'Item 1'},
          {'id': '01J9X2', 'name': 'Item 2'},
        ],
        'meta': {
          'request_id': '01J9XREQ123',
          'per_page': 25,
          'next_cursor': 'eyJpZCI6MTAxfQ',
          'has_more': true,
        },
        'links': {
          'next': 'https://api.school.internal/api/v1/resource?cursor=eyJpZCI6MTAxfQ',
          'prev': null,
        },
      };

      final paginated = PaginatedResponse.fromJson(
        json,
        (item) => item['name'] as String,
      );

      expect(paginated.data, ['Item 1', 'Item 2']);
      expect(paginated.meta.requestId, '01J9XREQ123');
      expect(paginated.meta.perPage, 25);
      expect(paginated.meta.nextCursor, 'eyJpZCI6MTAxfQ');
      expect(paginated.meta.hasMore, isTrue);
      expect(
        paginated.links?.next,
        'https://api.school.internal/api/v1/resource?cursor=eyJpZCI6MTAxfQ',
      );
      expect(paginated.links?.prev, isNull);
    });

    test('handles empty data list in paginated response', () {
      final json = {
        'data': [],
        'meta': {
          'request_id': '01J9XREQ999',
          'per_page': 25,
          'next_cursor': null,
          'has_more': false,
        },
      };

      final paginated = PaginatedResponse.fromJson(
        json,
        (item) => item,
      );

      expect(paginated.data, isEmpty);
      expect(paginated.meta.hasMore, isFalse);
      expect(paginated.meta.nextCursor, isNull);
      expect(paginated.links, isNull);
    });
  });
}

