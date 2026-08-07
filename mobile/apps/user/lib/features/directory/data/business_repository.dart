import 'package:dio/dio.dart';

import '../../../core/network/paginated_result.dart';
import 'business.dart';

final class BusinessRepository {
  BusinessRepository(this._dio);
  final Dio _dio;

  Future<List<Business>> search(
    String query, {
    int? categoryId,
    int? governorateId,
    int? cityId,
    int? districtId,
    String? businessType,
    double? minRating,
    String ordering = '-is_featured',
  }) async {
    final page = await searchPage(
      query,
      categoryId: categoryId,
      governorateId: governorateId,
      cityId: cityId,
      districtId: districtId,
      businessType: businessType,
      minRating: minRating,
      ordering: ordering,
      pageSize: 50,
    );
    return page.items;
  }

  Future<PaginatedResult<Business>> searchPage(
    String query, {
    int? categoryId,
    int? governorateId,
    int? cityId,
    int? districtId,
    String? businessType,
    double? minRating,
    String ordering = '-is_featured',
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'businesses/',
      queryParameters: {
        if (query.isNotEmpty) 'search': query,
        if (categoryId != null) 'category': categoryId,
        if (governorateId != null) 'governorate': governorateId,
        if (cityId != null) 'city': cityId,
        if (districtId != null) 'district': districtId,
        if (businessType != null) 'business_type': businessType,
        if (minRating != null) 'min_rating': minRating,
        'ordering': ordering,
        'page': page,
        'page_size': pageSize,
      },
      cancelToken: cancelToken,
    );
    return PaginatedResult<Business>.fromJson(
      response.data ?? const <String, dynamic>{},
      page: page,
      parser: Business.fromJson,
    );
  }

  Future<Business> detail(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>('businesses/$slug/');
    return Business.fromJson(response.data!);
  }

  Future<void> incrementView(String slug) async {
    await _dio.post<void>('businesses/$slug/increment_view/');
  }

  Future<void> incrementClick(String slug) async {
    await _dio.post<void>('businesses/$slug/increment_click/');
  }

  Future<bool> toggleFavorite(int businessId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'favorites/toggle/',
      data: {'business_id': businessId},
    );
    return response.data?['is_favorite'] as bool? ?? false;
  }

  Future<List<Business>> favorites() async {
    final response = await _dio.get<Map<String, dynamic>>('favorites/');
    final results = response.data?['results'] as List<dynamic>? ?? const [];
    return results
        .cast<Map<String, dynamic>>()
        .map(
          (item) => Business.fromJson(
            item['business'] as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<List<Business>> nearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String query = '',
    int? categoryId,
    int? governorateId,
    int? cityId,
    int? districtId,
    String? businessType,
    double? minRating,
    bool featuredOnly = false,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      'businesses/nearby/',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        if (query.trim().isNotEmpty) 'search': query.trim(),
        if (categoryId != null) 'category': categoryId,
        if (governorateId != null) 'governorate': governorateId,
        if (cityId != null) 'city': cityId,
        if (districtId != null) 'district': districtId,
        if (businessType != null) 'business_type': businessType,
        if (minRating != null) 'min_rating': minRating,
        if (featuredOnly) 'is_featured': true,
      },
      cancelToken: cancelToken,
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Business.fromJson)
        .toList(growable: false);
  }
}
