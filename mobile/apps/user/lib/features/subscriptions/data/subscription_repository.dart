import 'package:dio/dio.dart';

final class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.displayNameAr,
    required this.displayNameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.priceMonthly,
    required this.priceQuarterly,
    required this.priceSemiAnnual,
    required this.priceAnnual,
    required this.maxProducts,
    required this.maxImagesPerProduct,
    required this.maxBusinessImages,
    required this.canShowPrices,
    required this.hasAnalytics,
    required this.featuredInSearch,
    required this.canCreateDeals,
    required this.hasVerifiedBadge,
    required this.isPopular,
    required this.color,
  });

  final int id;
  final String name;
  final String displayNameAr;
  final String displayNameEn;
  final String descriptionAr;
  final String descriptionEn;
  final double priceMonthly;
  final double priceQuarterly;
  final double priceSemiAnnual;
  final double priceAnnual;
  final int maxProducts;
  final int maxImagesPerProduct;
  final int maxBusinessImages;
  final bool canShowPrices;
  final bool hasAnalytics;
  final bool featuredInSearch;
  final bool canCreateDeals;
  final bool hasVerifiedBadge;
  final bool isPopular;
  final String color;

  String get displayName => displayNameFor('ar');
  String get description => descriptionFor('ar');

  String displayNameFor(String languageCode) => languageCode == 'ar'
      ? (displayNameAr.isNotEmpty ? displayNameAr : displayNameEn)
      : (displayNameEn.isNotEmpty ? displayNameEn : displayNameAr);

  String descriptionFor(String languageCode) => languageCode == 'ar'
      ? (descriptionAr.isNotEmpty ? descriptionAr : descriptionEn)
      : (descriptionEn.isNotEmpty ? descriptionEn : descriptionAr);

  double priceFor(String period) => switch (period) {
        'quarterly' => priceQuarterly,
        'semi_annual' => priceSemiAnnual,
        'annual' => priceAnnual,
        _ => priceMonthly,
      };

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    double money(String key) => double.tryParse('${json[key] ?? 0}') ?? 0;
    return SubscriptionPlan(
      id: json['id'] as int? ?? 0,
      name: '${json['name'] ?? ''}',
      displayNameAr: '${json['display_name_ar'] ?? ''}',
      displayNameEn: '${json['display_name_en'] ?? ''}',
      descriptionAr: '${json['description_ar'] ?? ''}',
      descriptionEn: '${json['description_en'] ?? ''}',
      priceMonthly: money('price_monthly'),
      priceQuarterly: money('price_quarterly'),
      priceSemiAnnual: money('price_semi_annual'),
      priceAnnual: money('price_annual'),
      maxProducts: json['max_products'] as int? ?? 0,
      maxImagesPerProduct: json['max_images_per_product'] as int? ?? 1,
      maxBusinessImages: json['max_business_images'] as int? ?? 0,
      canShowPrices: json['can_show_prices'] as bool? ?? false,
      hasAnalytics: json['has_analytics'] as bool? ?? false,
      featuredInSearch: json['featured_in_search'] as bool? ?? false,
      canCreateDeals: json['can_create_deals'] as bool? ?? false,
      hasVerifiedBadge: json['has_verified_badge'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      color: '${json['color'] ?? '#667EEA'}',
    );
  }
}

final class SubscriptionRepository {
  const SubscriptionRepository(this._dio);
  final Dio _dio;

  Future<List<SubscriptionPlan>> plans() async {
    final response = await _dio.get<dynamic>('subscription-plans/');
    final data = response.data;
    final List<dynamic> rows = data is Map<String, dynamic>
        ? data['results'] as List<dynamic>? ?? const []
        : data is List<dynamic>
            ? data
            : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromJson)
        .toList(growable: false);
  }
}
