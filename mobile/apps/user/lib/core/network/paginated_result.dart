final class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.totalCount,
  });

  final List<T> items;
  final int page;
  final bool hasNext;
  final int totalCount;

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json, {
    required int page,
    required T Function(Map<String, dynamic>) parser,
  }) {
    final raw = json['results'] as List<dynamic>? ?? const [];
    return PaginatedResult<T>(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(parser)
          .toList(growable: false),
      page: page,
      hasNext: json['next'] != null,
      totalCount: (json['count'] as num?)?.toInt() ?? raw.length,
    );
  }
}
