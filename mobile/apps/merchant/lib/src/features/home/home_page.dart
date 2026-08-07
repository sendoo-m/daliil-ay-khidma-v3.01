import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.onOpenTab});

  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final shop = ref.watch(currentShopProvider);
    final dashboard = ref.watch(dashboardProvider);

    if (shop == null) {
      return const ShopEmpty(
        title: 'مفيش نشاط على الحساب ده',
        hint: 'كلّم الدعم عشان نسجّل محلك أو خدمتك.',
      );
    }

    return RefreshIndicator(
      color: Shop.sign,
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await ref.read(sessionProvider.notifier).refreshShops();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          ShopSign(
            shop: shop,
            rating: dashboard.valueOrNull?.totals.averageRating,
            onSwitch: session.hasMultipleShops
                ? () => _pickShop(context, ref, session)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.lg,
              Gap.lg,
              Gap.lg,
              Gap.xl,
            ),
            child: dashboard.when(
              loading: () => const _DashboardSkeleton(),
              error: (error, _) => ShopError(
                failure: ApiFailure.from(error),
                onRetry: () => ref.invalidate(dashboardProvider),
              ),
              data: (data) => _DashboardBody(
                data: data,
                shop: shop,
                ownerName: session.fullName,
                onOpenTab: onOpenTab,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickShop(BuildContext context, WidgetRef ref, MerchantSession session) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Shop.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختار النشاط',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.sm),
            for (final business in session.shops)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Shop.jadeWash,
                  child: business.logo == null
                      ? const Icon(
                          Icons.storefront_outlined,
                          color: Shop.jade,
                        )
                      : ClipOval(
                          child: Image.network(
                            business.logo!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.storefront_outlined,
                              color: Shop.jade,
                            ),
                          ),
                        ),
                ),
                title: Text(business.nameAr),
                subtitle: business.placeLine.isEmpty
                    ? null
                    : Text(business.placeLine),
                trailing: business.id == ref.read(selectedShopProvider)
                    ? const Icon(Icons.check, color: Shop.jade, size: 20)
                    : null,
                onTap: () {
                  ref.read(selectedShopProvider.notifier).state = business.id;
                  ref.invalidate(dashboardProvider);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: Gap.md),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.shop,
    required this.ownerName,
    required this.onOpenTab,
  });

  final MerchantDashboard data;
  final ShopSummary shop;
  final String ownerName;
  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final profile = _ProfileHealth.from(shop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WelcomeCard(
          ownerName: ownerName,
          shop: shop,
          profile: profile,
          onCompleteProfile: () => onOpenTab(3),
        ),
        const SizedBox(height: Gap.lg),
        SectionTitle(
          'إجراءات سريعة',
          trailing: Text(
            'اختصارات يومك',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        _QuickActions(
          onReviews: () => onOpenTab(1),
          onCatalog: () => onOpenTab(2),
          onBusiness: () => onOpenTab(3),
        ),
        const SizedBox(height: Gap.xl),
        _AttentionSection(
          attention: data.attention,
          onOpenTab: onOpenTab,
        ),
        const SizedBox(height: Gap.xl),
        SectionTitle(
          'أداء نشاطك',
          trailing: _StatusPill(
            label: shop.isActive ? 'ظاهر للعملاء' : 'غير نشط',
            icon: shop.isActive
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            tone: shop.isActive ? Shop.jade : Shop.clay,
          ),
        ),
        _PerformanceGrid(totals: data.totals),
        const SizedBox(height: Gap.md),
        _EngagementCard(totals: data.totals),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.ownerName,
    required this.shop,
    required this.profile,
    required this.onCompleteProfile,
  });

  final String ownerName;
  final ShopSummary shop;
  final _ProfileHealth profile;
  final VoidCallback onCompleteProfile;

  @override
  Widget build(BuildContext context) {
    final trimmedName = ownerName.trim();
    final firstName = trimmedName.isEmpty
        ? 'صاحب النشاط'
        : trimmedName.split(RegExp(r'\s+')).first;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Shop.rule),
        boxShadow: [
          BoxShadow(
            color: Shop.sign.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلًا $firstName',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'دي لقطة سريعة على حالة ${shop.nameAr} النهارده.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _VerificationBadge(shop: shop),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'اكتمال بيانات النشاط',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${profile.percent}%',
                style: MerchantTheme.figure(
                  size: 21,
                  color: profile.isComplete ? Shop.jade : Shop.brass,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: profile.percent / 100,
              minHeight: 8,
              color: profile.isComplete ? Shop.jade : Shop.brass,
              backgroundColor: Shop.rule,
            ),
          ),
          const SizedBox(height: Gap.sm),
          if (profile.isComplete)
            const Text(
              'بيانات النشاط الأساسية مكتملة وجاهزة للظهور بشكل قوي.',
              style: TextStyle(color: Shop.jade, fontSize: 12.5),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ناقص ${profile.missingCount} عناصر أساسية. كمّلها عشان صفحة نشاطك تبان أفضل.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                TextButton(
                  onPressed: onCompleteProfile,
                  child: const Text('كمّل البيانات'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.shop});

  final ShopSummary shop;

  @override
  Widget build(BuildContext context) {
    final verified = shop.isVerified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: verified ? Shop.jadeWash : Shop.brassWash,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            size: 16,
            color: verified ? Shop.jade : Shop.brass,
          ),
          const SizedBox(width: 5),
          Text(
            verified ? 'موثّق' : 'قيد المراجعة',
            style: TextStyle(
              color: verified ? Shop.jade : Shop.brass,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onReviews,
    required this.onCatalog,
    required this.onBusiness,
  });

  final VoidCallback onReviews;
  final VoidCallback onCatalog;
  final VoidCallback onBusiness;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.rate_review_outlined,
              label: 'التقييمات',
              hint: 'رد على العملاء',
              onTap: onReviews,
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _QuickAction(
              icon: Icons.inventory_2_outlined,
              label: 'المنتجات',
              hint: 'عدّل وعرض',
              onTap: onCatalog,
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: _QuickAction(
              icon: Icons.store_mall_directory_outlined,
              label: 'بياناتي',
              hint: 'حدّث النشاط',
              onTap: onBusiness,
            ),
          ),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm,
              vertical: Gap.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: Shop.rule),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Shop.jadeWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Shop.jade, size: 21),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      );
}

class _AttentionSection extends StatelessWidget {
  const _AttentionSection({
    required this.attention,
    required this.onOpenTab,
  });

  final NeedsAttention attention;
  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final tasks = <Widget>[
      if (attention.reviewsWithoutReply > 0)
        TaskCard(
          count: attention.reviewsWithoutReply,
          label: 'تقييم لسه من غير رد',
          action: 'الرد السريع بيفرق مع العميل الجاي',
          tone: Shop.clay,
          onTap: () => onOpenTab(1),
        ),
      if (attention.dealsExpiringSoon > 0)
        TaskCard(
          count: attention.dealsExpiringSoon,
          label: 'عرض بيخلص قريب',
          action: 'راجعه أو جهّز عرض جديد',
          tone: Shop.brass,
          onTap: () => onOpenTab(2),
        ),
      if (attention.awaitingVerification > 0)
        TaskCard(
          count: attention.awaitingVerification,
          label: 'نشاط مستني التوثيق',
          action: 'راجع بيانات النشاط المطلوبة',
          tone: Shop.inkSoft,
          onTap: () => onOpenTab(3),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'محتاج إيدك',
          trailing: attention.total == 0
              ? const _StatusPill(
                  label: 'كله تمام',
                  icon: Icons.check_circle_outline,
                  tone: Shop.jade,
                )
              : _StatusPill(
                  label: '${attention.total} مهمة',
                  icon: Icons.notifications_none_rounded,
                  tone: Shop.clay,
                ),
        ),
        if (tasks.isEmpty)
          const _AllClear()
        else
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: task,
            ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: tone,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Shop.jadeWash,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: Shop.jade.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Shop.jade,
              size: 24,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'كل حاجة تمام. مفيش حاجة مستنياك دلوقتي.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Shop.jade),
              ),
            ),
          ],
        ),
      );
}

class _PerformanceGrid extends StatelessWidget {
  const _PerformanceGrid({required this.totals});

  final ShopTotals totals;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Gap.sm,
        crossAxisSpacing: Gap.sm,
        childAspectRatio: 1.55,
        children: [
          _MetricCard(
            icon: Icons.visibility_outlined,
            value: _compact(totals.views),
            label: 'مشاهدة للنشاط',
            tone: Shop.sign,
          ),
          _MetricCard(
            icon: Icons.touch_app_outlined,
            value: _compact(totals.clicks),
            label: 'تفاعل مع بياناتك',
            tone: Shop.jade,
          ),
          _MetricCard(
            icon: Icons.star_outline_rounded,
            value: totals.averageRating > 0
                ? totals.averageRating.toStringAsFixed(1)
                : '—',
            label: '${totals.reviews} تقييم',
            tone: Shop.brass,
          ),
          _MetricCard(
            icon: Icons.inventory_2_outlined,
            value: '${totals.products}',
            label: 'منتج أو خدمة',
            tone: Shop.signSoft,
          ),
        ],
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: Shop.rule),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: tone),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: MerchantTheme.figure(size: 23, color: tone),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({required this.totals});

  final ShopTotals totals;

  @override
  Widget build(BuildContext context) {
    final rate = totals.views == 0
        ? 0.0
        : (totals.clicks / totals.views * 100).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.sign,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'معدل التفاعل',
                  style: TextStyle(
                    color: Color(0xFFBFD1CA),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totals.views == 0
                      ? 'ابدأ بجذب مشاهدات لصفحة نشاطك'
                      : '${rate.toStringAsFixed(1)}% من المشاهدات تحولت لتفاعل',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (totals.views > 0)
            Text(
              '${rate.toStringAsFixed(0)}%',
              style: MerchantTheme.figure(size: 26, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var index = 0; index < 3; index++) ...[
            Container(
              height: index == 0 ? 180 : 110,
              decoration: BoxDecoration(
                color: Shop.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: Shop.rule),
              ),
            ),
            if (index < 2) const SizedBox(height: Gap.md),
          ],
        ],
      );
}

class _ProfileHealth {
  const _ProfileHealth({
    required this.percent,
    required this.missingCount,
  });

  final int percent;
  final int missingCount;

  bool get isComplete => missingCount == 0;

  factory _ProfileHealth.from(ShopSummary shop) {
    final checks = <bool>[
      shop.logo != null && shop.logo!.isNotEmpty,
      shop.descriptionAr.trim().isNotEmpty,
      shop.categoryName.trim().isNotEmpty,
      shop.cityName.trim().isNotEmpty,
      shop.addressAr.trim().isNotEmpty,
      shop.phone.trim().isNotEmpty,
      shop.whatsapp.trim().isNotEmpty,
      shop.workingHoursAr.trim().isNotEmpty,
    ];
    final complete = checks.where((value) => value).length;
    final missing = checks.length - complete;
    return _ProfileHealth(
      percent: ((complete / checks.length) * 100).round(),
      missingCount: missing,
    );
  }
}

String _compact(int number) {
  if (number < 1000) return '$number';
  if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)} ألف';
  return '${(number / 1000000).toStringAsFixed(1)} مليون';
}
