import 'package:dio/dio.dart';

import '../../../core/network/paginated_result.dart';
import 'catalog_models.dart';
import 'deal_claim.dart';

final class CatalogRepository {
  CatalogRepository(this._dio);
  final Dio _dio;

  Future<ProductDetail> productDetail(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>('products/$slug/');
    return ProductDetail.fromJson(response.data!);
  }

  Future<void> incrementProductView(String slug) async {
    await _dio.post<void>('products/$slug/increment_view/');
  }

  Future<List<ProductSummary>> searchProducts(
    String query, {
    int? categoryId,
    int? businessId,
    int? governorateId,
    String? productType,
    double? minPrice,
    double? maxPrice,
    String ordering = 'price',
    int pageSize = 50,
  }) async {
    final page = await searchProductsPage(
      query,
      categoryId: categoryId,
      businessId: businessId,
      governorateId: governorateId,
      productType: productType,
      minPrice: minPrice,
      maxPrice: maxPrice,
      ordering: ordering,
      pageSize: pageSize,
    );
    return page.items;
  }

  Future<PaginatedResult<ProductSummary>> searchProductsPage(
    String query, {
    int? categoryId,
    int? businessId,
    int? governorateId,
    String? productType,
    double? minPrice,
    double? maxPrice,
    String ordering = 'price',
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'products/',
      queryParameters: {
        if (query.isNotEmpty) 'search': query,
        if (categoryId != null) 'category': categoryId,
        if (businessId != null) 'business': businessId,
        if (governorateId != null) 'governorate': governorateId,
        if (productType != null) 'product_type': productType,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        'ordering': ordering,
        'page': page,
        'page_size': pageSize,
      },
      cancelToken: cancelToken,
    );
    return PaginatedResult<ProductSummary>.fromJson(
      response.data ?? const <String, dynamic>{},
      page: page,
      parser: ProductSummary.fromJson,
    );
  }

  Future<List<DealSummary>> deals({
    String search = '',
    String ordering = '-created_at',
    int? businessId,
    int pageSize = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'deals/',
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (businessId != null) 'business': businessId,
        'ordering': ordering,
        'page_size': pageSize,
      },
    );
    final results = response.data?['results'] as List<dynamic>? ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(DealSummary.fromJson)
        .toList(growable: false);
  }

  Future<DealDetail> dealDetail(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>('deals/$slug/');
    return DealDetail.fromJson(response.data!);
  }

  Future<void> incrementDealView(String slug) async {
    await _dio.post<void>('deals/$slug/increment_view/');
  }

  Future<DealClaimResult> claimDeal(String slug) async {
    final response = await _dio.post<Map<String, dynamic>>('deals/$slug/claim/');
    return DealClaimResult.fromJson(response.data!);
  }

  Future<List<DealClaim>> dealClaims({bool? isUsed}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'deal-claims/',
      queryParameters: {
        if (isUsed != null) 'is_used': isUsed,
        'ordering': '-claimed_at',
        'page_size': 100,
      },
    );
    final results = response.data?['results'] as List<dynamic>? ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(DealClaim.fromJson)
        .toList(growable: false);
  }
}
