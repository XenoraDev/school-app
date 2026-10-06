/// Envelope for successful single-resource API responses.
///
/// See `API_CONTRACT.md §1.2`
class ApiResponse<T> {
  final T data;
  final ResponseMeta meta;

  const ApiResponse({
    required this.data,
    required this.meta,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    return ApiResponse(
      data: fromJsonT(json['data']),
      meta: ResponseMeta.fromJson(
        json['meta'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// Metadata included in standard and paginated API responses.
class ResponseMeta {
  final String? requestId;
  final int? perPage;
  final String? nextCursor;
  final bool? hasMore;

  const ResponseMeta({
    this.requestId,
    this.perPage,
    this.nextCursor,
    this.hasMore,
  });

  factory ResponseMeta.fromJson(Map<String, dynamic> json) {
    return ResponseMeta(
      requestId: json['request_id'] as String?,
      perPage: json['per_page'] as int?,
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool?,
    );
  }
}

/// Pagination navigation links.
class ResponseLinks {
  final String? next;
  final String? prev;

  const ResponseLinks({
    this.next,
    this.prev,
  });

  factory ResponseLinks.fromJson(Map<String, dynamic> json) {
    return ResponseLinks(
      next: json['next'] as String?,
      prev: json['prev'] as String?,
    );
  }
}

/// Envelope for cursor-paginated collection API responses.
///
/// See `API_CONTRACT.md §1.3`
class PaginatedResponse<T> {
  final List<T> data;
  final ResponseMeta meta;
  final ResponseLinks? links;

  const PaginatedResponse({
    required this.data,
    required this.meta,
    this.links,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    final rawList = json['data'] as List<dynamic>? ?? const [];
    return PaginatedResponse(
      data: rawList.map((item) => fromJsonT(item)).toList(),
      meta: ResponseMeta.fromJson(
        json['meta'] as Map<String, dynamic>? ?? const {},
      ),
      links: json['links'] != null
          ? ResponseLinks.fromJson(json['links'] as Map<String, dynamic>)
          : null,
    );
  }
}

