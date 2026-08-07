/// نماذج رحلة التجهيز — تطابق `GET /api/v2/onboarding/`.
library;

/// خطوة واحدة في قائمة التجهيز.
class OnboardingItem {
  const OnboardingItem({
    required this.key,
    required this.label,
    required this.weight,
    required this.state,
    required this.applicable,
  });

  final String key;
  final String label;
  final int weight;

  /// `done` · `pending` · `not_applicable`
  final String state;
  final bool applicable;

  bool get isDone => state == 'done';
  bool get isPending => state == 'pending';

  factory OnboardingItem.fromJson(Map<String, dynamic> json) => OnboardingItem(
        key: json['key'] as String? ?? '',
        label: json['label_ar'] as String? ?? json['label_en'] as String? ?? '',
        weight: (json['weight'] as num?)?.toInt() ?? 0,
        state: json['state'] as String? ?? 'pending',
        applicable: json['applicable'] as bool? ?? true,
      );
}

class OnboardingPlan {
  const OnboardingPlan({
    required this.id,
    required this.name,
    required this.canCreateDeals,
  });

  final int id;
  final String name;
  final bool canCreateDeals;

  factory OnboardingPlan.fromJson(Map<String, dynamic> json) => OnboardingPlan(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['display_name_ar'] as String? ??
            json['name'] as String? ??
            '',
        canCreateDeals: json['can_create_deals'] as bool? ?? false,
      );
}

class OnboardingBusiness {
  const OnboardingBusiness({
    required this.id,
    required this.nameAr,
    required this.isVerified,
  });

  final int id;
  final String nameAr;
  final bool isVerified;

  factory OnboardingBusiness.fromJson(Map<String, dynamic> json) =>
      OnboardingBusiness(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nameAr: json['name_ar'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
      );
}

/// حالة الرحلة كاملة.
///
/// الخادم هو مصدر الحقيقة الوحيد: النسبة والخطوة التالية تُحسبان هناك
/// من البيانات الفعلية، لا من حالة محفوظة في التطبيق. لذلك يفتح التاجر
/// الويب أو الموبايل فيجد نفس الرقم ونفس الخطوة — بلا مزامنة.
class OnboardingState {
  const OnboardingState({
    required this.progress,
    required this.status,
    required this.nextAction,
    required this.checklist,
    this.plan,
    this.business,
    this.paymentRequired = false,
    this.paymentStatus = '',
  });

  final int progress;
  final String status;
  final String nextAction;
  final List<OnboardingItem> checklist;
  final OnboardingPlan? plan;
  final OnboardingBusiness? business;
  final bool paymentRequired;
  final String paymentStatus;

  bool get isComplete => status == 'completed' || progress >= 100;
  bool get hasBusiness => business != null;

  /// الخطوات التي تخص التاجر داخل التطبيق — لا الدفع ولا مراجعة الإدارة.
  List<OnboardingItem> get shopSteps => checklist
      .where(
        (i) =>
            i.applicable &&
            const {
              'logo_added',
              'cover_added',
              'location_added',
              'working_hours_added',
              'contact_added',
              'first_product',
              'first_deal',
            }.contains(i.key),
      )
      .toList(growable: false);

  int get remaining => shopSteps.where((i) => i.isPending).length;

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['selected_plan'];
    final rawBusiness = json['business'];

    return OnboardingState(
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      nextAction: json['next_action'] as String? ?? '',
      paymentRequired: json['payment_required'] as bool? ?? false,
      paymentStatus: json['payment_status'] as String? ?? '',
      plan: rawPlan is Map<String, dynamic>
          ? OnboardingPlan.fromJson(rawPlan)
          : null,
      business: rawBusiness is Map<String, dynamic>
          ? OnboardingBusiness.fromJson(rawBusiness)
          : null,
      checklist: (json['checklist'] is List
              ? json['checklist'] as List
              : const [])
          .whereType<Map<String, dynamic>>()
          .map(OnboardingItem.fromJson)
          .toList(growable: false),
    );
  }
}
