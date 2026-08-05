import 'package:dio/dio.dart';

import '../../catalog/data/catalog_models.dart';
import '../../directory/data/business.dart';

/// مستودع المفضّلة.
///
/// الأنشطة تُحفظ على الخادم (`/favorites/`) فتتبع الحساب عبر الأجهزة.
/// المنتجات والعروض ليس لها نقطة على الخادم بعد، فتُحفظ في الذاكرة
/// خلال الجلسة فقط — تختفي عند إغلاق التطبيق.
///
/// لجعلها دائمة: أضف `shared_preferences` إلى pubspec، وأضف `toJson`
/// إلى `ProductSummary` و`DealSummary`، ثم استبدل القائمتين أدناه
/// بقراءة وكتابة من التخزين. الواجهة نفسها لن تتغير.
class FavoritesRepository {
  FavoritesRepository(this._dio);

  final Dio _dio;

  List<ProductSummary> _products = const [];
  List<DealSummary> _deals = const [];

  /// `GET /favorites/` — يرجّع سجلات المفضّلة، كل واحد بداخله النشاط.
  Future<List<Business>> businesses() async {
    try {
      final response = await _dio.get<dynamic>('favorites/');
      final data = response.data;

      // الرد قد يكون مصفوفة مباشرة أو صفحة DRF فيها results.
      final rows = switch (data) {
        List<dynamic> list => list,
        Map<String, dynamic> map when map['results'] is List =>
          map['results'] as List<dynamic>,
        _ => const <dynamic>[],
      };

      return rows
          .whereType<Map<String, dynamic>>()
          .map((row) => row['business'])
          .whereType<Map<String, dynamic>>()
          .map(Business.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      // زائر غير مسجّل: لا مفضّلة، وليس خطأ يستحق شاشة حمراء.
      if (error.response?.statusCode == 401) return const [];
      rethrow;
    }
  }

  /// `POST /favorites/toggle/` — يرجّع الحالة بعد التبديل.
  Future<bool> toggleBusiness(int businessId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'favorites/toggle/',
      data: {'business_id': businessId},
    );
    return response.data?['is_favorite'] as bool? ?? false;
  }

  Future<List<ProductSummary>> products() async => _products;

  Future<List<DealSummary>> deals() async => _deals;

  Future<void> saveProducts(List<ProductSummary> items) async {
    _products = List.unmodifiable(items);
  }

  Future<void> saveDeals(List<DealSummary> items) async {
    _deals = List.unmodifiable(items);
  }
}
