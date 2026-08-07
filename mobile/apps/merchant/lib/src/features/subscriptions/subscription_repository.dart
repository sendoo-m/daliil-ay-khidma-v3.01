import 'package:dalil_core/dalil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _asMoney(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

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
    required this.maxBusinesses,
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

  factory MerchantPlan.fromJson(Map<String, dynamic> json) => MerchantPlan(
        id: _asInt(json['id']),
        name: '${json['name'] ?? ''}',
        displayNameAr: '${json['display_name_ar'] ?? ''}',
        displayNameEn: '${json['display_name_en'] ?? ''}',
        descriptionAr: '${json['description_ar'] ?? ''}',
        descriptionEn: '${json['description_en'] ?? ''}',
        priceMonthly: _asMoney(json['price_monthly']),
        priceQuarterly: _asMoney(json['price_quarterly']),
        priceSemiAnnual: _asMoney(json['price_semi_annual']),
        priceAnnual: _asMoney(json['price_annual']),
        maxProducts: _asInt(json['max_products']),
        maxBusinesses: _asInt(json['max_businesses']),
        maxImagesPerProduct: _asInt(json['max_images_per_product']),
        maxBusinessImages: _asInt(json['max_business_images']),
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
  final int maxBusinesses;
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

  factory MerchantSubscription.fromJson(Map<String, dynamic> json) =>
      MerchantSubscription(
        id: _asInt(json['id']),
        businessId: _asInt(json['business']),
        plan: MerchantPlan.fromJson(
          (json['plan'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        status: '${json['status'] ?? ''}',
        startDate: DateTime.tryParse('${json['start_date'] ?? ''}'),
        endDate: DateTime.tryParse('${json['end_date'] ?? ''}'),
        autoRenew: json['auto_renew'] as bool? ?? false,
        amountPaid: _asMoney(json['amount_paid']),
        paymentMethod: '${json['payment_method'] ?? ''}',
        transactionId: '${json['transaction_id'] ?? ''}',
        isActive: json['is_active'] as bool? ?? false,
        daysRemaining: _asInt(json['days_remaining']),
        isExpiringSoon: json['is_expiring_soon'] as bool? ?? false,
      );

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

final class PlanChangeBusiness {
  const PlanChangeBusiness({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.isActive,
  });

  factory PlanChangeBusiness.fromJson(Map<String, dynamic> json) =>
      PlanChangeBusiness(
        id: _asInt(json['id']),
        nameAr: '${json['name_ar'] ?? ''}',
        nameEn: '${json['name_en'] ?? ''}',
        isActive: json['is_active'] as bool? ?? false,
      );

  final int id;
  final String nameAr;
  final String nameEn;
  final bool isActive;

  String name(bool arabic) => arabic
      ? (nameAr.isNotEmpty ? nameAr : nameEn)
      : (nameEn.isNotEmpty ? nameEn : nameAr);
}

final class PlanChangeProduct {
  const PlanChangeProduct({
    required this.id,
    required this.businessId,
    required this.nameAr,
    required this.nameEn,
    required this.isAvailable,
  });

  factory PlanChangeProduct.fromJson(Map<String, dynamic> json) =>
      PlanChangeProduct(
        id: _asInt(json['id']),
        businessId: _asInt(json['business_id']),
        nameAr: '${json['name_ar'] ?? ''}',
        nameEn: '${json['name_en'] ?? ''}',
        isAvailable: json['is_available'] as bool? ?? false,
      );

  final int id;
  final int businessId;
  final String nameAr;
  final String nameEn;
  final bool isAvailable;

  String name(bool arabic) => arabic
      ? (nameAr.isNotEmpty ? nameAr : nameEn)
      : (nameEn.isNotEmpty ? nameEn : nameAr);
}

final class PlanChangePreview {
  const PlanChangePreview({
    required this.changeType,
    required this.currentPlanId,
    required this.targetPlanId,
    required this.billingPeriod,
    required this.price,
    required this.maxBusinesses,
    required this.maxProducts,
    required this.activeBusinesses,
    required this.activeProducts,
    required this.businessesToSuspend,
    required this.productsToSuspend,
    required this.disabledFeatures,
    required this.businesses,
    required this.products,
  });

  factory PlanChangePreview.fromJson(Map<String, dynamic> json) {
    final limits = (json['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    final impact = (json['impact'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawFeatures = impact['disabled_features'] as List? ?? const [];
    return PlanChangePreview(
      changeType: '${json['change_type'] ?? ''}',
      currentPlanId: _asInt(json['current_plan_id']),
      targetPlanId: _asInt(json['target_plan_id']),
      billingPeriod: '${json['billing_period'] ?? 'monthly'}',
      price: _asMoney(json['price']),
      maxBusinesses: _asInt(limits['max_businesses']),
      maxProducts: _asInt(limits['max_products']),
      activeBusinesses: _asInt(impact['active_businesses']),
      activeProducts: _asInt(impact['active_products']),
      businessesToSuspend: _asInt(impact['businesses_to_suspend']),
      productsToSuspend: _asInt(impact['products_to_suspend']),
      disabledFeatures: rawFeatures
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false),
      businesses: (json['businesses'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PlanChangeBusiness.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      products: (json['products'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PlanChangeProduct.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  final String changeType;
  final int currentPlanId;
  final int targetPlanId;
  final String billingPeriod;
  final double price;
  final int maxBusinesses;
  final int maxProducts;
  final int activeBusinesses;
  final int activeProducts;
  final int businessesToSuspend;
  final int productsToSuspend;
  final List<Map<String, dynamic>> disabledFeatures;
  final List<PlanChangeBusiness> businesses;
  final List<PlanChangeProduct> products;

  bool get needsBusinessSelection => businessesToSuspend > 0 && maxBusinesses > 0;
  bool get needsProductSelection => productsToSuspend > 0 && maxProducts > 0;
}

final class MerchantPlanChangeRequest {
  const MerchantPlanChangeRequest({
    required this.id,
    required this.status,
    required this.changeType,
    required this.billingPeriod,
    required this.currentPlan,
    required this.targetPlan,
    required this.preview,
    required this.requestedAmount,
    required this.rejectionReason,
    required this.createdAt,
  });

  factory MerchantPlanChangeRequest.fromJson(Map<String, dynamic> json) =>
      MerchantPlanChangeRequest(
        id: _asInt(json['id']),
        status: '${json['status'] ?? ''}',
        changeType: '${json['change_type'] ?? ''}',
        billingPeriod: '${json['billing_period'] ?? ''}',
        currentPlan: MerchantPlan.fromJson(
          (json['current_plan'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        targetPlan: MerchantPlan.fromJson(
          (json['target_plan'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        preview: (json['preview'] as Map?)?.cast<String, dynamic>() ?? const {},
        requestedAmount: _asMoney(json['requested_amount']),
        rejectionReason: '${json['rejection_reason'] ?? ''}',
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      );

  final int id;
  final String status;
  final String changeType;
  final String billingPeriod;
  final MerchantPlan currentPlan;
  final MerchantPlan targetPlan;
  final Map<String, dynamic> preview;
  final double requestedAmount;
  final String rejectionReason;
  final DateTime? createdAt;
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

final merchantPendingPlanChangeProvider =
    FutureProvider.autoDispose<MerchantPlanChangeRequest?>((ref) async {
  final subscription = await ref.watch(currentMerchantSubscriptionProvider.future);
  if (subscription == null) return null;
  final requests = await ref.watch(merchantSubscriptionRepositoryProvider).changeRequests();
  for (final request in requests) {
    if (request.status == 'pending' &&
        request.currentPlan.id == subscription.plan.id) {
      return request;
    }
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

  Future<List<MerchantPlanChangeRequest>> changeRequests() async {
    final page = await _api.getPage<MerchantPlanChangeRequest>(
      'subscription-change-requests/',
      MerchantPlanChangeRequest.fromJson,
      query: const {'page_size': 100},
    );
    return page.items;
  }

  Future<PlanChangePreview> previewChange({
    required int subscriptionId,
    required int targetPlanId,
    required String billingPeriod,
  }) async {
    final json = await _api.post(
      'subscription-change-requests/preview/',
      body: {
        'subscription_id': subscriptionId,
        'target_plan_id': targetPlanId,
        'billing_period': billingPeriod,
      },
    );
    return PlanChangePreview.fromJson(json);
  }

  Future<MerchantPlanChangeRequest> requestChange({
    required int subscriptionId,
    required int targetPlanId,
    required String billingPeriod,
    required Iterable<int> keepBusinessIds,
    required Iterable<int> keepProductIds,
  }) async {
    final json = await _api.post(
      'subscription-change-requests/',
      body: {
        'subscription_id': subscriptionId,
        'target_plan_id': targetPlanId,
        'billing_period': billingPeriod,
        'keep_business_ids': keepBusinessIds.toSet().toList(),
        'keep_product_ids': keepProductIds.toSet().toList(),
      },
    );
    return MerchantPlanChangeRequest.fromJson(json);
  }
}
