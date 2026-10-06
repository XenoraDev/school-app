import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/network/list_query.dart';

void main() {
  group('ListQuery', () {
    test('produces empty query parameters when no options provided', () {
      const query = ListQuery();
      expect(query.toQueryParams(), isEmpty);
    });

    test('serializes per_page and cursor correctly', () {
      const query = ListQuery(
        perPage: 50,
        cursor: 'eyJpZCI6MTAxfQ',
      );

      final params = query.toQueryParams();
      expect(params['per_page'], 50);
      expect(params['cursor'], 'eyJpZCI6MTAxfQ');
    });

    test('serializes filters in filter[x]=val format', () {
      const query = ListQuery(
        filters: {
          'status': 'active',
          'q': 'math',
          'academic_year': '01J9X11111',
        },
      );

      final params = query.toQueryParams();
      expect(params['filter[status]'], 'active');
      expect(params['filter[q]'], 'math');
      expect(params['filter[academic_year]'], '01J9X11111');
    });

    test('serializes sort columns joined by comma', () {
      const query = ListQuery(
        sorts: ['name', '-created_at'],
      );

      final params = query.toQueryParams();
      expect(params['sort'], 'name,-created_at');
    });

    test('throws ArgumentError if per_page is greater than maxPerPage (100)', () {
      const query = ListQuery(perPage: 101);
      expect(() => query.toQueryParams(), throwsArgumentError);
    });

    test('throws ArgumentError if per_page is less than 1', () {
      const query = ListQuery(perPage: 0);
      expect(() => query.toQueryParams(), throwsArgumentError);
    });

    test('combines all query parameters together', () {
      const query = ListQuery(
        perPage: 25,
        cursor: 'cur_abc',
        filters: {'status': 'open'},
        sorts: ['-id'],
      );

      final params = query.toQueryParams();
      expect(params, {
        'per_page': 25,
        'cursor': 'cur_abc',
        'filter[status]': 'open',
        'sort': '-id',
      });
    });
  });
}

