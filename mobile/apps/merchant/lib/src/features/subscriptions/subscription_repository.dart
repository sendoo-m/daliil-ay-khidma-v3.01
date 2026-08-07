import 'package:dalil_core/dalil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';

final class MerchantPlan {
  const MerchantPlan({
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
    required this.canUploadImages,
    required this.canShowPrices,
    required this.hasDeliveryOptions,
    required this.hasAnalytics,
    required this.featuredInSearch,
    required this.canCreateDeals,
    required this.hasSocialMediaLinks,
    required this.hasVerifiedBadge,
    required this.isPopular,
  });

  factory MerchantPlan.fromJson(Map<String, dynamic> json) {
    double money(String key) => double.tryParse('${json[key] ?? 0}') ?? 0;
    return MerchantPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: '${json['name'] ?? ''}',
      displayNameAr: '${json['display_name_ar'] ?? ''}',
      displayNameEn: '${json['display_name_en'] ?? ''}',
      descriptionAr: '${json['description_ar'] ?? ''}',
      descriptionEn: '${json['description_en'] ?? ''}',
      priceMonthly: money('price_monthly'),
      priceQuarterly: money('price_quarterly'),
      priceSemiAnnual: money('price_semi_annual'),
      priceAnnual: money('price_annual'),
      maxProducts: (json['max_products'] as num?)?.toInt() ?? 0,
      maxImagesPerProduct:
          (json['max_images_per_product'] as num?)?.toInt() ?? 1,
      maxBusinessImages:
          (json['max_business_images'] as num?)?.toInt() ?? 0,
      canUploadImages: json['can_upload_images'] as bool? ?? false,
      canShowPrices: json['can_show_prices'] as bool? ?? false,
      hasDeliveryOptions: json['has_delivery_options'] as bool? ?? false,
      hasAnalytics: json['has_analytics'] as bool? ?? false,
      featuredInSearch: json['featured_in_search'] as bool? ?? false,
      canCreateDeals: json['can_create_deals'] as bool? ?? false,
      hasSocialMediaLinks: json['has_social_media_links'] as bool? ?? false,
      hasVerifiedBadge: json['has_verified_badge'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }

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
  final bool canUploadImages;
  final bool canShowPrices;
  final bool hasDeliveryOptions;
  final bool hasAnalytics;
  final bool featuredInSearch;
  final bool canCreateDeals;
  final bool hasSocialMediaLinks;
  final bool hasVerifiedBadge;
  final bool isPopular;

  String displayName(bool arabic) => arabic
      ? (displayNameAr.isNotEmpty ? displayNameAr : displayNameEn)
      : (displayNameEn.isNotEmpty ? displayNameEn : displayNameAr);

  String description(bool arabic) => arabic
      ? (descriptionAr.isNotEmpty ? descriptionAr : descriptionEn)
      : (descriptionEn.isNotEmpty ? descriptionEn : descriptionAr);

  double priceFor(String period) => switch (period) {
        'quarterly' => priceQuarterly,
        'semi_annual' => priceSemiAnnual,
        'annual' => priceAnnual,
        _ => priceMonthly,
      };
}

final class MerchantSubscription {
  const MerchantSubscription({
    required this.id,
    required this.businessId,
    required this.plan,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.autoRenew,
    required this.amountPaid,
    required this.paymentMethod,
    required this.transactionId,
    required this.isActive,
    required this.daysRemaining,
    required this.isExpiringSoon,
  });

  factory MerchantSubscription.fromJson(Map<String, dynamic> json) {
    return MerchantSubscription(
      id: (json['id'] as num?)?.toInt() ?? 0,
      businessId: (json['business'] as num?)?.toInt() ?? 0,
      plan: MerchantPlan.fromJson(
        (json['plan'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      status: '${json['status'] ?? ''}',
      startDate: DateTime.tryParse('${json['start_date'] ?? ''}'),
      endDate: DateTime.tryParse('${json['end_date'] ?? ''}'),
      autoRenew: json['auto_renew'] as bool? ?? false,
      amountPaid: double.tryParse('${json['amount_paid'] ?? 0}') ?? 0,
      paymentMethod: '${json['payment_method'] ?? ''}',
      transactionId: '${json['transaction_id'] ?? ''}',
      isActive: json['is_active'] as bool? ?? false,
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      isExpiringSoon: json['is_expiring_soon'] as bool? ?? false,
    );
  }

  final int id;
  final int businessId;
  final MerchantPlan plan;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool autoRenew;
  final double amountPaid;
  final String paymentMethod;
  final String transactionId;
  final bool isActive;
  final int daysRemaining;
  final bool isExpiringSoon;
}

final merchantSubscriptionRepositoryProvider =
    Provider<MerchantSubscriptionRepository>((ref) {
  return MerchantSubscriptionRepository(ref.watch(apiClientProvider));
});

final merchantPlansProvider = FutureProvider.autoDispose<List<MerchantPlan>>((ref) {
  return ref.watch(merchantSubscriptionRepositoryProvider).plans();
});

final currentMerchantSubscriptionProvider =
    FutureProvider.autoDispose<MerchantSubscription?>((ref) async {
  final shop = ref.watch(currentShopProvider);
  if (shop == null) return null;
  final items = await ref.watch(merchantSubscriptionRepositoryProvider).subscriptions();
  for (final item in items) {
    if (item.businessId == shop.id) return item;
  }
  return null;
});

final class MerchantSubscriptionRepository {
  const MerchantSubscriptionRepository(this._api);

  final ApiClient _api;

  Future<List<MerchantPlan>> plans() async {
    final page = await _api.getPage<MerchantPlan>(
      'subscription-plans/',
      MerchantPlan.fromJson,
      query: const {'page_size': 100},
    );
    return page.items;
  }

  Future<List<MerchantSubscription>> subscriptions() async {
    final page = await _api.getPage<MerchantSubscription>(
      'subscriptions/',
      MerchantSubscription.fromJson,
      query: const {'page_size': 100},
    );
    return page.items;
  }
}
