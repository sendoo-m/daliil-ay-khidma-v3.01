/// صفحة نتائج من DRF: {count, next, previous, results}
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.total,
    this.next,
    this.previous,
  });

  final List<T> items;
  final int total;
  final String? next;
  final String? previous;

  bool get hasMore => next != null;

  static Paginated<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final raw = json['results'];
    final rows = raw is List ? raw : const [];
    return Paginated<T>(
      items: rows
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false),
      total: (json['count'] as num?)?.toInt() ?? rows.length,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );
  }

  static Paginated<T> empty<T>() =>
      Paginated<T>(items: List<T>.unmodifiable(const []), total: 0);
}
