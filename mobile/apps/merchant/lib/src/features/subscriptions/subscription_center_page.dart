import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import 'subscription_repository.dart';

class SubscriptionCenterPage extends ConsumerStatefulWidget {
  const SubscriptionCenterPage({super.key});

  @override
  ConsumerState<SubscriptionCenterPage> createState() =>
      _SubscriptionCenterPageState();
}

class _SubscriptionCenterPageState
    extends ConsumerState<SubscriptionCenterPage> {
  String _period = 'monthly';

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  String _tr(String ar, String en) => _isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(currentShopProvider);
    final subscription = ref.watch(currentMerchantSubscriptionProvider);
    final plans = ref.watch(merchantPlansProvider);

    return Scaffold(
      backgroundColor: Shop.paper,
      appBar: AppBar(
        backgroundColor: Shop.sign,
        foregroundColor: Colors.white,
        title: Text(_tr('الاشتراك', 'Subscription')),
      ),
      body: RefreshIndicator(
        color: Shop.jade,
        onRefresh: () async {
          ref.invalidate(currentMerchantSubscriptionProvider);
          ref.invalidate(merchantPlansProvider);
          await Future.wait([
            ref.read(currentMerchantSubscriptionProvider.future),
            ref.read(merchantPlansProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
          children: [
            _Hero(
              shopName: shop?.nameAr ?? _tr('نشاطك', 'Your business'),
              isArabic: _isArabic,
            ),
            const SizedBox(height: Gap.lg),
            subscription.when(
              loading: () => const _LoadingCard(height: 220),
              error: (error, _) => ShopError(
                failure: ApiFailure.from(error),
                onRetry: () =>
                    ref.invalidate(currentMerchantSubscriptionProvider),
              ),
              data: (current) => current == null
                  ? _NoSubscription(isArabic: _isArabic)
                  : _CurrentPlanCard(
                      subscription: current,
                      isArabic: _isArabic,
                    ),
            ),
            const SizedBox(height: Gap.xl),
            SectionTitle(_tr('قارن الخطط', 'Compare plans')),
            const SizedBox(height: Gap.sm),
            _BillingSelector(
              selected: _period,
              isArabic: _isArabic,
              onChanged: (value) => setState(() => _period = value),
            ),
            const SizedBox(height: Gap.md),
            plans.when(
              loading: () => const Column(
                children: [
                  _LoadingCard(height: 250),
                  SizedBox(height: Gap.md),
                  _LoadingCard(height: 250),
                ],
              ),
              error: (error, _) => ShopError(
                failure: ApiFailure.from(error),
                onRetry: () => ref.invalidate(merchantPlansProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ShopEmpty(
                    title: _tr('لا توجد خطط متاحة', 'No plans available'),
                  );
                }
                return Column(
                  children: [
                    for (final plan in items) ...[
                      _PlanCard(
                        plan: plan,
                        period: _period,
                        isArabic: _isArabic,
                        currentPlanId:
                            subscription.valueOrNull?.plan.id,
                        onChoose: () => _showWebOnlyInfo(plan),
                      ),
                      const SizedBox(height: Gap.md),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: Gap.sm),
            _SystemNote(isArabic: _isArabic),
          ],
        ),
      ),
    );
  }

  void _showWebOnlyInfo(MerchantPlan plan) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.payments_outlined,
                size: 42,
                color: Shop.jade,
              ),
              const SizedBox(height: Gap.md),
              Text(
                _tr(
                  'إدارة ${plan.displayName(true)}',
                  'Manage ${plan.displayName(false)}',
                ),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                _tr(
                  'الـAPI الحالي يعرض الاشتراكات والخطط فقط، ولا يحتوي حتى الآن على عملية دفع أو ترقية من التطبيق. لذلك لن ننفذ زر دفع شكلي. إتمام الترقية أو التجديد متاح حاليًا من لوحة النشاط على الويب.',
                  'The current API exposes plans and subscriptions as read-only and does not yet provide in-app payment or upgrade actions. Renewal and upgrades are currently completed from the web dashboard.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.lg),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_tr('تمام', 'Got it')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.shopName, required this.isArabic});

  final String shopName;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.sign,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'اشتراك $shopName' : '$shopName subscription',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  isArabic
                      ? 'تابع خطتك الحالية واعرف حدودها وقارنها بباقي الخطط.'
                      : 'Track your current plan, limits and available upgrades.',
                  style: const TextStyle(
                    color: Color(0xFFC8D6D0),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.subscription, required this.isArabic});

  final MerchantSubscription subscription;
  final bool isArabic;

  String _tr(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final tone = subscription.isActive ? Shop.jade : Shop.clay;
    final status = switch (subscription.status) {
      'active' => _tr('نشط', 'Active'),
      'pending' => _tr('بانتظار الدفع', 'Pending payment'),
      'expired' => _tr('منتهي', 'Expired'),
      'cancelled' => _tr('ملغي', 'Cancelled'),
      _ => subscription.status,
    };

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Shop.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr('خطتك الحالية', 'Current plan'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subscription.plan.displayName(isArabic),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              _StatusChip(label: status, tone: tone),
            ],
          ),
          if (subscription.isExpiringSoon) ...[
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: Shop.brassWash,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Shop.brass),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      _tr(
                        'اشتراكك ينتهي خلال ${subscription.daysRemaining} أيام.',
                        'Your subscription expires in ${subscription.daysRemaining} days.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Gap.lg),
          _ProgressDays(subscription: subscription, isArabic: isArabic),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              _InfoTile(
                icon: Icons.calendar_today_outlined,
                label: _tr('البداية', 'Started'),
                value: _date(subscription.startDate),
              ),
              _InfoTile(
                icon: Icons.event_available_outlined,
                label: _tr('النهاية', 'Ends'),
                value: _date(subscription.endDate),
              ),
              _InfoTile(
                icon: Icons.payments_outlined,
                label: _tr('المدفوع', 'Paid'),
                value: '${_money(subscription.amountPaid)} ${_tr('ج.م', 'EGP')}',
              ),
              _InfoTile(
                icon: Icons.autorenew_rounded,
                label: _tr('التجديد التلقائي', 'Auto renew'),
                value: subscription.autoRenew
                    ? _tr('مفعّل', 'Enabled')
                    : _tr('غير مفعّل', 'Off'),
              ),
            ],
          ),
          if (subscription.paymentMethod.isNotEmpty ||
              subscription.transactionId.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            const Divider(height: 1),
            const SizedBox(height: Gap.md),
            if (subscription.paymentMethod.isNotEmpty)
              _DetailRow(
                label: _tr('وسيلة الدفع', 'Payment method'),
                value: subscription.paymentMethod,
              ),
            if (subscription.transactionId.isNotEmpty)
              _DetailRow(
                label: _tr('رقم العملية', 'Transaction ID'),
                value: subscription.transactionId,
              ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)}';
  }

  String _money(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _ProgressDays extends StatelessWidget {
  const _ProgressDays({required this.subscription, required this.isArabic});

  final MerchantSubscription subscription;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final start = subscription.startDate;
    final end = subscription.endDate;
    double progress = 0;
    if (start != null && end != null && end.isAfter(start)) {
      final total = end.difference(start).inSeconds;
      final used = DateTime.now().difference(start).inSeconds;
      progress = (used / total).clamp(0, 1).toDouble();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isArabic ? 'مدة الاشتراك' : 'Subscription period',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              isArabic
                  ? '${subscription.daysRemaining} يوم متبقي'
                  : '${subscription.daysRemaining} days left',
              style: const TextStyle(
                color: Shop.jade,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: subscription.isExpiringSoon ? Shop.brass : Shop.jade,
            backgroundColor: Shop.rule,
          ),
        ),
      ],
    );
  }
}

class _NoSubscription extends StatelessWidget {
  const _NoSubscription({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Shop.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Shop.rule),
        ),
        child: Column(
          children: [
            const Icon(Icons.layers_clear_outlined, size: 42, color: Shop.brass),
            const SizedBox(height: Gap.md),
            Text(
              isArabic ? 'لا يوجد اشتراك مسجل لهذا النشاط' : 'No subscription for this business',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              isArabic
                  ? 'قارن الخطط المتاحة بالأسفل واختر الأنسب لنشاطك.'
                  : 'Compare the available plans below and choose what fits your business.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _BillingSelector extends StatelessWidget {
  const _BillingSelector({
    required this.selected,
    required this.isArabic,
    required this.onChanged,
  });

  final String selected;
  final bool isArabic;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final periods = [
      ('monthly', 'شهري', 'Monthly'),
      ('quarterly', 'ربع سنوي', 'Quarterly'),
      ('semi_annual', 'نصف سنوي', 'Semi-annual'),
      ('annual', 'سنوي', 'Annual'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in periods)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Gap.sm),
              child: ChoiceChip(
                selected: selected == item.$1,
                label: Text(isArabic ? item.$2 : item.$3),
                onSelected: (_) => onChanged(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.isArabic,
    required this.currentPlanId,
    required this.onChoose,
  });

  final MerchantPlan plan;
  final String period;
  final bool isArabic;
  final int? currentPlanId;
  final VoidCallback onChoose;

  String _tr(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final current = currentPlanId == plan.id;
    final price = plan.priceFor(period);
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: current || plan.isPopular ? Shop.jade : Shop.rule,
          width: current || plan.isPopular ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.displayName(isArabic),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (current)
                      Text(
                        _tr('خطتك الحالية', 'Your current plan'),
                        style: const TextStyle(
                          color: Shop.jade,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (plan.isPopular)
                      Text(
                        _tr('الأكثر اختيارًا', 'Most popular'),
                        style: const TextStyle(
                          color: Shop.brass,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${_money(price)} ${_tr('ج.م', 'EGP')}',
                style: MerchantTheme.figure(size: 22, color: Shop.jade),
              ),
            ],
          ),
          if (plan.description(isArabic).isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(
              plan.description(isArabic),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: Gap.md),
          _Feature(
            text: plan.maxProducts == 0
                ? _tr('منتجات وخدمات غير محدودة', 'Unlimited products and services')
                : _tr('${plan.maxProducts} منتج أو خدمة', '${plan.maxProducts} products or services'),
          ),
          _Feature(
            text: _tr(
              '${plan.maxImagesPerProduct} صورة لكل منتج',
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
          _Feature(text: _tr('إنشاء العروض', 'Create deals'), enabled: plan.canCreateDeals),
          _Feature(text: _tr('التحليلات', 'Analytics'), enabled: plan.hasAnalytics),
          _Feature(text: _tr('أولوية في البحث', 'Search priority'), enabled: plan.featuredInSearch),
          _Feature(text: _tr('شارة التوثيق', 'Verified badge'), enabled: plan.hasVerifiedBadge),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            onPressed: current ? null : onChoose,
            icon: Icon(current ? Icons.check_circle_outline : Icons.arrow_forward_rounded),
            label: Text(
              current ? _tr('الخطة الحالية', 'Current plan') : _tr('اختيار الخطة', 'Choose plan'),
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text, this.enabled = true});
  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
              size: 18,
              color: enabled ? Shop.jade : Shop.inkSoft,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: enabled ? Shop.ink : Shop.inkSoft,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 145,
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Shop.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: Shop.jade),
            const SizedBox(height: Gap.sm),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(width: Gap.md),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tone,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.brassWash,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Shop.brass),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                isArabic
                    ? 'سجل الاشتراك الحالي يعرض مبلغ العملية ووسيلة الدفع ورقمها إن كانت مسجلة. لا يوجد حتى الآن نموذج فواتير مستقل أو API دفع داخل التطبيق.'
                    : 'The current subscription record shows the paid amount, payment method and transaction ID when available. There is not yet a separate invoice model or in-app payment API.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Shop.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Shop.rule),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}
