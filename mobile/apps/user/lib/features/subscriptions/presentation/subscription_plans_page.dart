import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../data/subscription_repository.dart';

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>(
  (ref) => ref.watch(subscriptionRepositoryProvider).plans(),
);

enum _PlanFilter { all, free, popular, analytics, verified, searchPriority }

class SubscriptionPlansPage extends ConsumerStatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  ConsumerState<SubscriptionPlansPage> createState() =>
      _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState
    extends ConsumerState<SubscriptionPlansPage> {
  String _period = 'monthly';
  _PlanFilter _filter = _PlanFilter.all;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  String _tr(String ar, String en) => _isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(subscriptionPlansProvider);
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        title: Text(_tr('خطط الاشتراك', 'Subscription plans')),
        actions: [
          IconButton(
            tooltip: _tr('تحديث', 'Refresh'),
            onPressed: () => ref.invalidate(subscriptionPlansProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(subscriptionPlansProvider.future),
        child: plans.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorState(
            isArabic: _isArabic,
            onRetry: () => ref.invalidate(subscriptionPlansProvider),
          ),
          data: (items) {
            final filtered = items.where(_matchesFilter).toList(growable: false);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _PricingHero(isArabic: _isArabic),
                const SizedBox(height: 18),
                _BillingSelector(
                  isArabic: _isArabic,
                  selected: _period,
                  onChanged: (value) => setState(() => _period = value),
                ),
                const SizedBox(height: 14),
                _PlanFilters(
                  isArabic: _isArabic,
                  selected: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr(
                          '${filtered.length} باقة متاحة',
                          '${filtered.length} available plans',
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (_filter != _PlanFilter.all)
                      TextButton.icon(
                        onPressed: () => setState(() => _filter = _PlanFilter.all),
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: Text(_tr('مسح الفلتر', 'Clear filter')),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  _EmptyPlans(isArabic: _isArabic)
                else
                  ...filtered.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlanCard(
                        plan: plan,
                        period: _period,
                        isArabic: _isArabic,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _matchesFilter(SubscriptionPlan plan) => switch (_filter) {
        _PlanFilter.free => plan.priceMonthly == 0,
        _PlanFilter.popular => plan.isPopular,
        _PlanFilter.analytics => plan.hasAnalytics,
        _PlanFilter.verified => plan.hasVerifiedBadge,
        _PlanFilter.searchPriority => plan.featuredInSearch,
        _ => true,
      };
}

class _PricingHero extends StatelessWidget {
  const _PricingHero({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .24),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isArabic
                  ? 'اختر الخطة التي تنمّي نشاطك'
                  : 'Choose the plan that grows your business',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'قارن الأسعار والمزايا وحدد مدة الفوترة المناسبة لك.'
                  : 'Compare prices and features, then choose your billing period.',
              style: const TextStyle(
                color: Color(0xFFF0EFFF),
                height: 1.7,
              ),
            ),
          ],
        ),
      );
}

class _BillingSelector extends StatelessWidget {
  const _BillingSelector({
    required this.isArabic,
    required this.selected,
    required this.onChanged,
  });

  final bool isArabic;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final periods = <(String, String, String)>[
      ('monthly', 'شهري', 'Monthly'),
      ('quarterly', 'ربع سنوي', 'Quarterly'),
      ('semi_annual', 'نصف سنوي', 'Semi-annual'),
      ('annual', 'سنوي', 'Annual'),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods
              .map(
                (item) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    selected: selected == item.$1,
                    label: Text(isArabic ? item.$2 : item.$3),
                    onSelected: (_) => onChanged(item.$1),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PlanFilters extends StatelessWidget {
  const _PlanFilters({
    required this.isArabic,
    required this.selected,
    required this.onChanged,
  });

  final bool isArabic;
  final _PlanFilter selected;
  final ValueChanged<_PlanFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <(_PlanFilter, IconData, String, String)>[
      (_PlanFilter.all, Icons.apps_rounded, 'الكل', 'All'),
      (_PlanFilter.free, Icons.savings_outlined, 'مجاني', 'Free'),
      (_PlanFilter.popular, Icons.local_fire_department_rounded, 'الأشهر', 'Popular'),
      (_PlanFilter.analytics, Icons.query_stats_rounded, 'تحليلات', 'Analytics'),
      (_PlanFilter.verified, Icons.verified_rounded, 'موثّق', 'Verified'),
      (_PlanFilter.searchPriority, Icons.trending_up_rounded, 'أولوية بحث', 'Search priority'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (item) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: FilterChip(
                  selected: selected == item.$1,
                  avatar: Icon(item.$2, size: 18),
                  label: Text(isArabic ? item.$3 : item.$4),
                  onSelected: (_) => onChanged(item.$1),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.isArabic,
  });

  final SubscriptionPlan plan;
  final String period;
  final bool isArabic;

  String _tr(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final language = isArabic ? 'ar' : 'en';
    final price = plan.priceFor(period);
    final number = NumberFormat('#,##0.##', isArabic ? 'ar_EG' : 'en_US');
    return Card(
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: plan.isPopular ? AppColors.primary : AppColors.border,
          width: plan.isPopular ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: plan.isPopular ? AppColors.brandGradient : null,
                    color: plan.isPopular ? null : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    plan.isPopular
                        ? Icons.auto_awesome_rounded
                        : Icons.layers_rounded,
                    color: plan.isPopular ? Colors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.displayNameFor(language),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      if (plan.isPopular)
                        Text(
                          _tr('الأكثر اختيارًا', 'Most popular'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              plan.descriptionFor(language),
              style: const TextStyle(color: AppColors.muted, height: 1.65),
            ),
            const SizedBox(height: 18),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 7,
              children: [
                Text(
                  number.format(price),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _tr('ج.م / ${_periodLabel()}', 'EGP / ${_periodLabel()}'),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Feature(
              text: plan.maxProducts == 0
                  ? _tr('منتجات غير محدودة', 'Unlimited products')
                  : _tr('${plan.maxProducts} منتج', '${plan.maxProducts} products'),
            ),
            _Feature(
              text: _tr(
                '${plan.maxImagesPerProduct} صور لكل منتج',
                '${plan.maxImagesPerProduct} images per product',
              ),
            ),
            _Feature(
              text: _tr(
                '${plan.maxBusinessImages} صور لمعرض النشاط',
                '${plan.maxBusinessImages} business gallery images',
              ),
            ),
            _Feature(text: _tr('إظهار الأسعار', 'Display prices'), enabled: plan.canShowPrices),
            _Feature(text: _tr('إنشاء العروض', 'Create offers'), enabled: plan.canCreateDeals),
            _Feature(text: _tr('لوحة التحليلات', 'Analytics dashboard'), enabled: plan.hasAnalytics),
            _Feature(text: _tr('أولوية في البحث', 'Priority in search'), enabled: plan.featuredInSearch),
            _Feature(text: _tr('شارة موثّق', 'Verified badge'), enabled: plan.hasVerifiedBadge),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showSubscribeInfo(context),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  price == 0 ? _tr('ابدأ مجانًا', 'Start free') : _tr('اختر الخطة', 'Choose plan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel() => switch (period) {
        'quarterly' => _tr('ربع سنة', 'quarter'),
        'semi_annual' => _tr('نصف سنة', 'half-year'),
        'annual' => _tr('سنة', 'year'),
        _ => _tr('شهر', 'month'),
      };

  void _showSubscribeInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _tr(
                  'الاشتراك في ${plan.displayNameFor('ar')}',
                  'Subscribe to ${plan.displayNameFor('en')}',
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                _tr(
                  'اخترت فوترة ${_periodLabel()}. إتمام الاشتراك والدفع متاح حاليًا من لوحة نشاطك على الموقع.',
                  'You selected ${_periodLabel()} billing. Subscription and payment are currently completed from your business dashboard on the website.',
                ),
                style: const TextStyle(color: AppColors.muted, height: 1.7),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_tr('حسنًا', 'Got it')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text, this.enabled = true});
  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Icon(
              enabled
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline_rounded,
              size: 20,
              color: enabled ? AppColors.success : AppColors.muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: enabled ? AppColors.text : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            children: [
              const Icon(
                Icons.filter_alt_off_rounded,
                size: 52,
                color: AppColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                isArabic
                    ? 'لا توجد خطط تطابق الفلتر المحدد'
                    : 'No plans match the selected filter',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.isArabic, required this.onRetry});
  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 110),
          const Icon(Icons.cloud_off_rounded, size: 58, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'تعذر تحميل خطط الاشتراك' : 'Could not load subscription plans',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(isArabic ? 'إعادة المحاولة' : 'Try again'),
            ),
          ),
        ],
      );
}
