import 'package:dio/dio.dart';

import '../../catalog/data/catalog_models.dart';
import '../../directory/data/business.dart';

final class HomeData {
  const HomeData({
    required this.businesses,
    required this.categories,
    required this.governorates,
    required this.products,
    required this.deals,
  });

  final List<Business> businesses;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> governorates;
  final List<ProductSummary> products;
  final List<DealSummary> deals;
}

final class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  Future<HomeData> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('home/');
    final json = response.data ?? const <String, dynamic>{};
    final featuredDeals = _parseDeals(json['featured_deals']);

    var deals = featuredDeals;
    try {
      final dealsResponse = await _dio.get<Map<String, dynamic>>(
        'deals/',
        queryParameters: const {
          'ordering': '-created_at',
          'page_size': 50,
        },
      );
      final allDeals = _parseDeals(dealsResponse.data?['results']);
      if (allDeals.isNotEmpty) deals = allDeals;
    } on DioException {
      // Keep the featured home payload as a graceful fallback.
    }

    return HomeData(
      businesses: (json['featured_businesses'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Business.fromJson)
          .toList(growable: false),
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      governorates: (json['governorates'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      products: (json['featured_products'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ProductSummary.fromJson)
          .toList(growable: false),
      deals: deals,
    );
  }

  List<DealSummary> _parseDeals(dynamic value) =>
      (value as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DealSummary.fromJson)
          .toList(growable: false);
}
