import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _openingChange = false;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  String _tr(String ar, String en) => _isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(currentShopProvider);
    final subscription = ref.watch(currentMerchantSubscriptionProvider);
    final plans = ref.watch(merchantPlansProvider);
    final pending = ref.watch(merchantPendingPlanChangeProvider);

    return Scaffold(
      backgroundColor: Shop.paper,
      appBar: AppBar(
        backgroundColor: Shop.sign,
        foregroundColor: Colors.white,
        title: Text(_tr('الاشتراك', 'Subscription')),
      ),
      body: RefreshIndicator(
        color: Shop.jade,
        onRefresh: _refresh,
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
              loading: () => const _LoadingCard(height: 190),
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
            pending.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (request) => request == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: Gap.md),
                      child: _PendingRequestCard(
                        request: request,
                        isArabic: _isArabic,
                      ),
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
                  _LoadingCard(height: 240),
                  SizedBox(height: Gap.md),
                  _LoadingCard(height: 240),
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
                final current = subscription.valueOrNull;
                final hasPending = pending.valueOrNull != null;
                return Column(
                  children: [
                    for (final plan in items) ...[
                      _PlanCard(
                        plan: plan,
                        period: _period,
                        isArabic: _isArabic,
                        currentPlanId: current?.plan.id,
                        blocked: hasPending || _openingChange,
                        onChoose: current == null
                            ? null
                            : () => _startChange(current, plan),
                        onChooseWeb: current == null
                            ? _openWebPlans
                            : null,
                      ),
                      const SizedBox(height: Gap.md),
                    ],
                  ],
                );
              },
            ),
            _ApprovalNote(isArabic: _isArabic),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(currentMerchantSubscriptionProvider);
    ref.invalidate(merchantPlansProvider);
    ref.invalidate(merchantPendingPlanChangeProvider);
    await Future.wait([
      ref.read(currentMerchantSubscriptionProvider.future),
      ref.read(merchantPlansProvider.future),
      ref.read(merchantPendingPlanChangeProvider.future),
    ]);
  }

  Future<void> _openWebPlans() async {
    final uri = Uri.parse('https://daliil.app/subscriptions/plans/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startChange(
    MerchantSubscription subscription,
    MerchantPlan target,
  ) async {
    if (_openingChange || subscription.plan.id == target.id) return;
    setState(() => _openingChange = true);
    try {
      final preview = await ref
          .read(merchantSubscriptionRepositoryProvider)
          .previewChange(
            subscriptionId: subscription.id,
            targetPlanId: target.id,
            billingPeriod: _period,
          );
      if (!mounted) return;
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PlanChangeReviewPage(
            subscription: subscription,
            targetPlan: target,
            preview: preview,
          ),
        ),
      );
      if (submitted == true && mounted) {
        await _refresh();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _openingChange = false);
    }
  }
}

class PlanChangeReviewPage extends ConsumerStatefulWidget {
  const PlanChangeReviewPage({
    super.key,
    required this.subscription,
    required this.targetPlan,
    required this.preview,
  });

  final MerchantSubscription subscription;
  final MerchantPlan targetPlan;
  final PlanChangePreview preview;

  @override
  ConsumerState<PlanChangeReviewPage> createState() =>
      _PlanChangeReviewPageState();
}

class _PlanChangeReviewPageState
    extends ConsumerState<PlanChangeReviewPage> {
  final Set<int> _businessIds = {};
  final Set<int> _productIds = {};
  bool _submitting = false;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;

  PlanChangePreview get _preview => widget.preview;
  bool get _isDowngrade => _preview.changeType == 'downgrade';

  List<PlanChangeBusiness> get _activeBusinesses =>
      _preview.businesses.where((item) => item.isActive).toList();

  List<PlanChangeProduct> get _availableProductsForKeptBusinesses =>
      _preview.products
          .where(
            (item) =>
                item.isAvailable && _businessIds.contains(item.businessId),
          )
          .toList();

  bool get _needsBusinessSelection =>
      _isDowngrade &&
      _preview.maxBusinesses > 0 &&
      _activeBusinesses.length > _preview.maxBusinesses;

  bool get _needsProductSelection {
    final available = _availableProductsForKeptBusinesses.length;
    return _isDowngrade &&
        _preview.maxProducts > 0 &&
        available > _preview.maxProducts;
  }

  int get _requiredBusinesses => _needsBusinessSelection
      ? _preview.maxBusinesses
      : _activeBusinesses.length;

  int get _requiredProducts {
    final available = _availableProductsForKeptBusinesses.length;
    if (!_needsProductSelection) return available;
    return available < _preview.maxProducts ? available : _preview.maxProducts;
  }

  int get _dynamicProductsToSuspend {
    if (!_needsProductSelection) return 0;
    return _availableProductsForKeptBusinesses.length - _requiredProducts;
  }

  bool get _selectionValid {
    final businessesValid =
        !_needsBusinessSelection || _businessIds.length == _requiredBusinesses;
    final productsValid =
        !_needsProductSelection || _productIds.length == _requiredProducts;
    return businessesValid && productsValid;
  }

  @override
  void initState() {
    super.initState();

    if (!_isDowngrade) {
      _businessIds.addAll(_activeBusinesses.map((item) => item.id));
      _productIds.addAll(
        _preview.products
            .where((item) => item.isAvailable && _businessIds.contains(item.businessId))
            .map((item) => item.id),
      );
      return;
    }

    final businessLimit = _preview.maxBusinesses == 0
        ? _activeBusinesses.length
        : (_activeBusinesses.length < _preview.maxBusinesses
            ? _activeBusinesses.length
            : _preview.maxBusinesses);
    _businessIds.addAll(_activeBusinesses.take(businessLimit).map((e) => e.id));
    _syncProductSelection();
  }

  void _syncProductSelection() {
    final available = _availableProductsForKeptBusinesses;
    final availableIds = available.map((item) => item.id).toSet();
    _productIds.removeWhere((id) => !availableIds.contains(id));

    if (!_needsProductSelection) {
      _productIds
        ..clear()
        ..addAll(availableIds);
      return;
    }

    final required = _requiredProducts;
    if (_productIds.length > required) {
      final keep = _productIds.take(required).toSet();
      _productIds
        ..clear()
        ..addAll(keep);
    }
    for (final product in available) {
      if (_productIds.length >= required) break;
      _productIds.add(product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Shop.paper,
      appBar: AppBar(
        backgroundColor: Shop.sign,
        foregroundColor: Colors.white,
        title: Text(
          _isDowngrade
              ? _tr('مراجعة تخفيض الخطة', 'Review downgrade')
              : _tr('مراجعة ترقية الخطة', 'Review upgrade'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 110),
        children: [
          _ChangeSummary(
            current: widget.subscription.plan,
            target: widget.targetPlan,
            preview: _preview,
            isArabic: _isArabic,
          ),
          if (_isDowngrade &&
              (_preview.businessesToSuspend > 0 ||
                  _dynamicProductsToSuspend > 0 ||
                  _preview.disabledFeatures.isNotEmpty)) ...[
            const SizedBox(height: Gap.md),
            _ImpactWarning(
              preview: _preview,
              isArabic: _isArabic,
              productsToSuspend: _dynamicProductsToSuspend,
            ),
          ],
          if (!_isDowngrade) ...[
            const SizedBox(height: Gap.md),
            _UpgradeNote(isArabic: _isArabic),
          ],
          if (_needsBusinessSelection) ...[
            const SizedBox(height: Gap.xl),
            _SelectionHeading(
              title: _tr(
                'اختار المحلات اللي هتفضل شغالة',
                'Choose businesses to keep active',
              ),
              selected: _businessIds.length,
              requiredCount: _requiredBusinesses,
              isArabic: _isArabic,
            ),
            const SizedBox(height: Gap.sm),
            for (final business in _activeBusinesses) ...[
              _SelectCard(
                title: business.name(_isArabic),
                subtitle: _tr('نشاط حالي', 'Current business'),
                selected: _businessIds.contains(business.id),
                onTap: () => _toggleBusiness(business),
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: Gap.sm),
            ],
          ],
          if (_needsProductSelection) ...[
            const SizedBox(height: Gap.xl),
            _SelectionHeading(
              title: _tr(
                'اختار المنتجات اللي هتفضل ظاهرة',
                'Choose products to keep visible',
              ),
              selected: _productIds.length,
              requiredCount: _requiredProducts,
              isArabic: _isArabic,
            ),
            const SizedBox(height: Gap.sm),
            for (final product in _availableProductsForKeptBusinesses) ...[
              _SelectCard(
                title: product.name(_isArabic),
                subtitle: _businessName(product.businessId),
                selected: _productIds.contains(product.id),
                onTap: () => _toggleProduct(product),
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: Gap.sm),
            ],
          ] else if (_isDowngrade && _businessIds.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            _WithinLimitNote(
              currentProducts: _availableProductsForKeptBusinesses.length,
              planLimit: _preview.maxProducts,
              isArabic: _isArabic,
            ),
          ],
          const SizedBox(height: Gap.xl),
          _NoImmediateChangeNote(isArabic: _isArabic),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(Gap.lg),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: Shop.jade,
          ),
          onPressed: _submitting || !_selectionValid ? null : _confirmAndSubmit,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _submitting
                ? _tr('جاري الإرسال...', 'Sending...')
                : _tr('إرسال الطلب للإدارة', 'Send request for approval'),
          ),
        ),
      ),
    );
  }

  String _businessName(int id) {
    for (final business in _preview.businesses) {
      if (business.id == id) return business.name(_isArabic);
    }
    return '';
  }

  void _toggleBusiness(PlanChangeBusiness business) {
    if (!_needsBusinessSelection) return;
    setState(() {
      if (_businessIds.contains(business.id)) {
        _businessIds.remove(business.id);
      } else {
        if (_businessIds.length >= _requiredBusinesses) return;
        _businessIds.add(business.id);
      }
      _syncProductSelection();
    });
  }

  void _toggleProduct(PlanChangeProduct product) {
    if (!_needsProductSelection) return;
    setState(() {
      if (_productIds.contains(product.id)) {
        _productIds.remove(product.id);
      } else {
        if (_productIds.length >= _requiredProducts) return;
        _productIds.add(product.id);
      }
    });
  }

  Future<void> _confirmAndSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('تأكيد طلب تغيير الخطة', 'Confirm plan change request')),
        content: Text(
          _tr(
            _isDowngrade
                ? 'الطلب هيروح للإدارة للمراجعة. مش هيتوقف أي محل أو منتج قبل موافقة الإدارة وتطبيق الخطة الجديدة.'
                : 'الترقية لا تحتاج منك اختيار محلات أو منتجات. الطلب هيروح للإدارة للمراجعة وتأكيد الدفع ثم تفعيل المزايا الجديدة.',
            _isDowngrade
                ? 'The request will be reviewed by administration. No business or product will be suspended before approval and activation of the new plan.'
                : 'Upgrades do not require business or product selection. Administration will review the request, confirm payment when needed, then activate the new benefits.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('رجوع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('تأكيد وإرسال', 'Confirm & send')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(merchantSubscriptionRepositoryProvider).requestChange(
            subscriptionId: widget.subscription.id,
            targetPlanId: widget.targetPlan.id,
            billingPeriod: _preview.billingPeriod,
            keepBusinessIds: _businessIds,
            keepProductIds: _productIds,
          );
      ref.invalidate(merchantPendingPlanChangeProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.hourglass_top_rounded, color: Shop.brass),
          title: Text(_tr('تم إرسال الطلب', 'Request sent')),
          content: Text(
            _tr(
              'طلبك وصل للإدارة وبقى بانتظار المراجعة. هيوصلك إشعار أول ما يتم القبول أو الرفض.',
              'Your request is now pending review. You will receive a notification once it is approved or rejected.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('تمام', 'Done')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.shopName, required this.isArabic});
  final String shopName;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
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
                        ? 'غيّر خطتك براحتك واعرف تأثير التغيير قبل ما تأكد.'
                        : 'Compare plans and see the exact impact before you confirm.',
                    style: const TextStyle(color: Color(0xFFC8D6D0), height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.subscription, required this.isArabic});
  final MerchantSubscription subscription;
  final bool isArabic;
  String _tr(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) => Container(
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
                      Text(_tr('خطتك الحالية', 'Current plan')),
                      const SizedBox(height: 3),
                      Text(
                        subscription.plan.displayName(isArabic),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                _Badge(
                  label: subscription.isActive
                      ? _tr('نشط', 'Active')
                      : subscription.status,
                  tone: subscription.isActive ? Shop.jade : Shop.brass,
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                _MiniMetric(
                  label: _tr('الأيام المتبقية', 'Days left'),
                  value: '${subscription.daysRemaining}',
                ),
                _MiniMetric(
                  label: _tr('المنتجات', 'Products'),
                  value: subscription.plan.maxProducts == 0
                      ? '∞'
                      : '${subscription.plan.maxProducts}',
                ),
                _MiniMetric(
                  label: _tr('المحلات', 'Businesses'),
                  value: subscription.plan.maxBusinesses == 0
                      ? '∞'
                      : '${subscription.plan.maxBusinesses}',
                ),
              ],
            ),
          ],
        ),
      );
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({required this.request, required this.isArabic});
  final MerchantPlanChangeRequest request;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.brassWash,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Shop.brass.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Shop.brass),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'طلب تغيير قيد المراجعة' : 'Plan change under review',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${request.currentPlan.displayName(isArabic)} → '
                    '${request.targetPlan.displayName(isArabic)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isArabic
                        ? 'لن تتغير أي بيانات أو مزايا قبل اعتماد الإدارة.'
                        : 'Nothing changes until administration approves the request.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
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
    required this.blocked,
    required this.onChoose,
    this.onChooseWeb,
  });
  final MerchantPlan plan;
  final String period;
  final bool isArabic;
  final int? currentPlanId;
  final bool blocked;
  final VoidCallback? onChoose;
  final VoidCallback? onChooseWeb;
  String _tr(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final current = currentPlanId == plan.id;
    final price = plan.priceFor(period);
    // لما التاجر مالوش اشتراك: onChoose=null و onChooseWeb=callback
    final hasNoSubscription = onChoose == null && onChooseWeb != null;
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
                        _tr('خطتك الحالية', 'Current plan'),
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
                style: MerchantTheme.figure(size: 21, color: Shop.jade),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          _Feature(
            text: plan.maxBusinesses == 0
                ? _tr('محلات غير محدودة', 'Unlimited businesses')
                : _tr('${plan.maxBusinesses} محل', '${plan.maxBusinesses} businesses'),
          ),
          _Feature(
            text: plan.maxProducts == 0
                ? _tr('منتجات غير محدودة', 'Unlimited products')
                : _tr('${plan.maxProducts} منتج أو خدمة', '${plan.maxProducts} products or services'),
          ),
          _Feature(
            text: _tr('إنشاء العروض', 'Create deals'),
            enabled: plan.canCreateDeals,
          ),
          _Feature(
            text: _tr('التحليلات', 'Analytics'),
            enabled: plan.hasAnalytics,
          ),
          _Feature(
            text: _tr('أولوية في البحث', 'Search priority'),
            enabled: plan.featuredInSearch,
          ),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            onPressed: current || blocked
                ? null
                : (onChoose ?? onChooseWeb),
            icon: Icon(
              current
                  ? Icons.check_circle_outline
                  : hasNoSubscription
                      ? Icons.open_in_browser_rounded
                      : Icons.swap_horiz_rounded,
            ),
            label: Text(
              current
                  ? _tr('الخطة الحالية', 'Current plan')
                  : blocked
                      ? _tr('يوجد طلب قيد المراجعة', 'Request already pending')
                      : hasNoSubscription
                          ? _tr('اختر الخطة', 'Select plan')
                          : _tr('طلب تغيير للخطة', 'Request plan change'),
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

class _ChangeSummary extends StatelessWidget {
  const _ChangeSummary({
    required this.current,
    required this.target,
    required this.preview,
    required this.isArabic,
  });
  final MerchantPlan current;
  final MerchantPlan target;
  final PlanChangePreview preview;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Shop.sign,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _PlanName(plan: current, isArabic: isArabic)),
                const Icon(Icons.arrow_forward_rounded, color: Shop.brass),
                Expanded(child: _PlanName(plan: target, isArabic: isArabic)),
              ],
            ),
            const SizedBox(height: Gap.md),
            const Divider(color: Color(0xFF49675C)),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: _HeroValue(
                    label: isArabic ? 'المحلات' : 'Businesses',
                    value: preview.maxBusinesses == 0 ? '∞' : '${preview.maxBusinesses}',
                  ),
                ),
                Expanded(
                  child: _HeroValue(
                    label: isArabic ? 'المنتجات' : 'Products',
                    value: preview.maxProducts == 0 ? '∞' : '${preview.maxProducts}',
                  ),
                ),
                Expanded(
                  child: _HeroValue(
                    label: isArabic ? 'السعر' : 'Price',
                    value: '${_money(preview.price)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  String _money(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

class _PlanName extends StatelessWidget {
  const _PlanName({required this.plan, required this.isArabic});
  final MerchantPlan plan;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Text(
        plan.displayName(isArabic),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      );
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: MerchantTheme.figure(size: 20, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF9DB5AB), fontSize: 11)),
        ],
      );
}

class _ImpactWarning extends StatelessWidget {
  const _ImpactWarning({
    required this.preview,
    required this.isArabic,
    required this.productsToSuspend,
  });
  final PlanChangePreview preview;
  final bool isArabic;
  final int productsToSuspend;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (preview.businessesToSuspend > 0) {
      lines.add(
        isArabic
            ? 'سيتم إيقاف ${preview.businessesToSuspend} محل بعد الموافقة.'
            : '${preview.businessesToSuspend} business(es) will be suspended after approval.',
      );
    }
    if (productsToSuspend > 0) {
      lines.add(
        isArabic
            ? 'سيتم إيقاف $productsToSuspend منتج/خدمة من المحلات التي أبقيتها بعد الموافقة.'
            : '$productsToSuspend product(s) in the kept businesses will be suspended after approval.',
      );
    }
    for (final feature in preview.disabledFeatures) {
      final value = '${feature[isArabic ? 'ar' : 'en'] ?? ''}';
      if (value.isNotEmpty) {
        lines.add(isArabic ? 'ستتوقف ميزة: $value.' : 'Feature disabled: $value.');
      }
    }
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.clay.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Shop.clay.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Shop.clay),
              const SizedBox(width: Gap.sm),
              Text(
                isArabic ? 'تأثير التخفيض' : 'Downgrade impact',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('• $line'),
            ),
          Text(
            isArabic
                ? 'لن نحذف أي بيانات، ويمكن استعادة العناصر عند الترقية لاحقًا.'
                : 'No data will be deleted. Suspended items can be restored after a future upgrade.',
            style: const TextStyle(color: Shop.jade, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _UpgradeNote extends StatelessWidget {
  const _UpgradeNote({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.jadeWash,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Shop.jade.withValues(alpha: .24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.trending_up_rounded, color: Shop.jade),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                isArabic
                    ? 'دي ترقية: مش محتاج تختار محلات أو منتجات. بياناتك الحالية تفضل كما هي، وبعد موافقة الإدارة تتفتح لك الحدود والمزايا الجديدة.'
                    : 'This is an upgrade: no business or product selection is required. Your current data stays active and the new limits and benefits unlock after approval.',
              ),
            ),
          ],
        ),
      );
}

class _WithinLimitNote extends StatelessWidget {
  const _WithinLimitNote({
    required this.currentProducts,
    required this.planLimit,
    required this.isArabic,
  });
  final int currentProducts;
  final int planLimit;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final unlimited = planLimit == 0;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.jadeWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Shop.jade),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              isArabic
                  ? unlimited
                      ? 'كل المنتجات الحالية ستظل فعالة؛ الخطة الجديدة لا تضع حدًا للمنتجات.'
                      : 'المحلات التي اخترتها فيها $currentProducts منتج/خدمة فقط، وهي داخل حد الخطة ($planLimit). مش محتاج تختار عدد إضافي.'
                  : unlimited
                      ? 'All current products remain active; the new plan has no product limit.'
                      : 'Your kept businesses contain $currentProducts product(s), which is within the plan limit of $planLimit. You do not need to fill the remaining capacity.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionHeading extends StatelessWidget {
  const _SelectionHeading({
    required this.title,
    required this.selected,
    required this.requiredCount,
    required this.isArabic,
  });
  final String title;
  final int selected;
  final int requiredCount;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          _Badge(
            label: '$selected / $requiredCount',
            tone: selected == requiredCount ? Shop.jade : Shop.brass,
          ),
        ],
      );
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: selected ? Shop.jadeWash : Shop.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: selected ? Shop.jade : Shop.rule),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? Shop.jade : Shop.inkSoft),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? Shop.jade : Shop.inkFaint,
                ),
              ],
            ),
          ),
        ),
      );
}

class _NoImmediateChangeNote extends StatelessWidget {
  const _NoImmediateChangeNote({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.jadeWash,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: Shop.jade),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                isArabic
                    ? 'اختياراتك هنا تحفظ كجزء من الطلب فقط. الإيقاف أو التفعيل يحصل بعد موافقة الإدارة، وتوصلك النتيجة في الإشعارات.'
                    : 'Your selections are saved with the request only. Activation or suspension happens after admin approval, and you will be notified of the result.',
              ),
            ),
          ],
        ),
      );
}

class _ApprovalNote extends StatelessWidget {
  const _ApprovalNote({required this.isArabic});
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
            const Icon(Icons.admin_panel_settings_outlined, color: Shop.brass),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                isArabic
                    ? 'تغيير الخطة لا يتم فورًا. بعد اختيارك ترسل الطلب للإدارة للمراجعة وتأكيد الدفع، ثم يتم تطبيق حدود الخطة تلقائيًا.'
                    : 'Plan changes are not immediate. Your request is reviewed by administration, payment is confirmed when needed, then the new plan limits are applied automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
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
        child: Text(
          isArabic
              ? 'لا يوجد اشتراك مسجل لهذا النشاط.'
              : 'No subscription is registered for this business.',
          textAlign: TextAlign.center,
        ),
      );
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 128,
        padding: const EdgeInsets.all(Gap.sm),
        decoration: BoxDecoration(
          color: Shop.paper,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Shop.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: MerchantTheme.figure(size: 18, color: Shop.sign)),
          ],
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(color: tone, fontWeight: FontWeight.w700, fontSize: 12),
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
