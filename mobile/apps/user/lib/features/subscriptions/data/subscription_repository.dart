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

final class MerchantOnboardingState {
  const MerchantOnboardingState({
    required this.status,
    required this.progress,
    required this.nextAction,
    required this.paymentRequired,
    required this.paymentStatus,
    required this.billingPeriod,
    required this.selectedPrice,
    required this.selectedPlan,
    required this.business,
  });

  final String status;
  final int progress;
  final String nextAction;
  final bool paymentRequired;
  final String paymentStatus;
  final String billingPeriod;
  final double selectedPrice;
  final Map<String, dynamic>? selectedPlan;
  final Map<String, dynamic>? business;

  bool get hasBusiness => business != null;

  factory MerchantOnboardingState.fromJson(Map<String, dynamic> json) =>
      MerchantOnboardingState(
        status: '${json['status'] ?? 'draft'}',
        progress: json['progress'] as int? ?? 0,
        nextAction: '${json['next_action'] ?? 'select_plan'}',
        paymentRequired: json['payment_required'] as bool? ?? false,
        paymentStatus: '${json['payment_status'] ?? 'not_required'}',
        billingPeriod: '${json['billing_period'] ?? 'monthly'}',
        selectedPrice: double.tryParse('${json['selected_price'] ?? 0}') ?? 0,
        selectedPlan: json['selected_plan'] is Map<String, dynamic>
            ? json['selected_plan'] as Map<String, dynamic>
            : null,
        business: json['business'] is Map<String, dynamic>
            ? json['business'] as Map<String, dynamic>
            : null,
      );
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

  Future<MerchantOnboardingState> onboarding() async {
    final response = await _dio.get<Map<String, dynamic>>('onboarding/');
    return MerchantOnboardingState.fromJson(response.data ?? const {});
  }

  /// يطلب رابط دخول لمرة واحدة ينقل المستخدم لجلسة ويب بنفس حسابه.
  ///
  /// تطبيق أصحاب الأنشطة ليس مبنيًا لمنصة موبايل أصلية بعد، فإكمال
  /// اختيار الخطة وإنشاء النشاط يتم على الويب. هذا الرابط يجعل الانتقال
  /// بلا كتابة بيانات دخول من جديد — نفس الحساب، جلسة جديدة فقط.
  Future<String> requestWebHandoff() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'onboarding/handoff/',
    );
    final url = response.data?['url'] as String?;
    if (url == null) {
      throw StateError('لم يصل رابط الدخول من الخادم.');
    }
    return url;
  }

  Future<MerchantOnboardingState> selectPlan({
    required int planId,
    required String billingPeriod,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'onboarding/select-plan/',
      data: <String, dynamic>{
        'plan_id': planId,
        'billing_period': billingPeriod,
      },
    );
    return MerchantOnboardingState.fromJson(response.data ?? const {});
  }
}
