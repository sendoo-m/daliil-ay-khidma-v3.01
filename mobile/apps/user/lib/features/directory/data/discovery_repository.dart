import 'package:dio/dio.dart';

import '../../catalog/data/catalog_models.dart';
import 'business.dart';

final class DiscoveryData {
  const DiscoveryData({
    required this.trendingBusinesses,
    required this.recommendedBusinesses,
    required this.popularProducts,
    required this.popularSearchesAr,
    required this.popularSearchesEn,
  });

  final List<Business> trendingBusinesses;
  final List<Business> recommendedBusinesses;
  final List<ProductSummary> popularProducts;
  final List<String> popularSearchesAr;
  final List<String> popularSearchesEn;
}

final class DiscoveryRepository {
  DiscoveryRepository(this._dio);

  final Dio _dio;

  static const _cacheDuration = Duration(minutes: 5);
  DiscoveryData? _cachedData;
  DateTime? _cachedAt;
  Future<DiscoveryData>? _inFlight;

  Future<DiscoveryData> fetch({bool forceRefresh = false}) {
    final cached = _cachedData;
    final cachedAt = _cachedAt;
    final cacheIsFresh = cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration;

    if (!forceRefresh && cacheIsFresh) {
      return Future.value(cached);
    }

    final pending = _inFlight;
    if (!forceRefresh && pending != null) return pending;

    final request = _fetchRemote();
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  void clearCache() {
    _cachedData = null;
    _cachedAt = null;
  }

  Future<DiscoveryData> _fetchRemote() async {
    final results = await Future.wait<dynamic>([
      _businesses(ordering: '-view_count'),
      _businesses(ordering: '-average_rating'),
      _products(ordering: '-view_count'),
      _popularSearches(),
    ]);

    final searches = results[3] as Map<String, List<String>>;
    final data = DiscoveryData(
      trendingBusinesses: results[0] as List<Business>,
      recommendedBusinesses: results[1] as List<Business>,
      popularProducts: results[2] as List<ProductSummary>,
      popularSearchesAr: searches['ar'] ?? _fallbackAr,
      popularSearchesEn: searches['en'] ?? _fallbackEn,
    );

    _cachedData = data;
    _cachedAt = DateTime.now();
    return data;
  }

  Future<List<Business>> _businesses({required String ordering}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'businesses/',
        queryParameters: {
          'ordering': ordering,
          'page_size': 10,
        },
      );
      return (response.data?['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Business.fromJson)
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<List<ProductSummary>> _products({required String ordering}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'products/',
        queryParameters: {
          'ordering': ordering,
          'page_size': 10,
        },
      );
      return (response.data?['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProductSummary.fromJson)
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<Map<String, List<String>>> _popularSearches() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('search/popular/');
      final json = response.data ?? const <String, dynamic>{};
      return {
        'ar': _strings(json['ar'], _fallbackAr),
        'en': _strings(json['en'], _fallbackEn),
      };
    } on DioException {
      return {'ar': _fallbackAr, 'en': _fallbackEn};
    }
  }

  List<String> _strings(dynamic value, List<String> fallback) {
    final items = (value as List<dynamic>? ?? const [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .take(12)
        .toList(growable: false);
    return items.isEmpty ? fallback : items;
  }

  static const _fallbackAr = <String>[
    'مطاعم',
    'كافيهات',
    'صيدليات',
    'سباك',
    'كهربائي',
    'عروض',
  ];

  static const _fallbackEn = <String>[
    'Restaurants',
    'Cafes',
    'Pharmacies',
    'Plumber',
    'Electrician',
    'Deals',
  ];
}
