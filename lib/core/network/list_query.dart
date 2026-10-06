/// Query parameter builder mirroring Laravel backend's `ListQuery` helper.
///
/// Features supported:
/// - Cursor pagination (`per_page`, `cursor`)
/// - Field filters (`filter[name]=value`)
/// - Sorting (`sort=name,-created_at`)
///
/// See `D:\Projects\school-api\app\Http\Api\ListQuery.php`
class ListQuery {
  static const int defaultPerPage = 25;
  static const int maxPerPage = 100;

  final int? perPage;
  final String? cursor;
  final Map<String, String>? filters;
  final List<String>? sorts;

  const ListQuery({
    this.perPage,
    this.cursor,
    this.filters,
    this.sorts,
  });

  /// Validates and converts the query options to Dio query parameter map.
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};

    if (perPage != null) {
      if (perPage! < 1 || perPage! > maxPerPage) {
        throw ArgumentError(
          'perPage must be a positive integer between 1 and $maxPerPage',
        );
      }
      params['per_page'] = perPage;
    }

    if (cursor != null && cursor!.isNotEmpty) {
      params['cursor'] = cursor;
    }

    if (filters != null && filters!.isNotEmpty) {
      for (final entry in filters!.entries) {
        if (entry.value.isNotEmpty) {
          params['filter[${entry.key}]'] = entry.value;
        }
      }
    }

    if (sorts != null && sorts!.isNotEmpty) {
      params['sort'] = sorts!.join(',');
    }

    return params;
  }
}

