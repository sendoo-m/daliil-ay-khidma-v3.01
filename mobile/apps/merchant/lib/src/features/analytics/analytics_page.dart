import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final shop = ref.watch(currentShopProvider);

    if (shop == null) {
      return const ShopEmpty(
        title: 'مفيش نشاط محدد',
        hint: 'اختار نشاط الأول عشان نعرض أرقامه.',
      );
    }

    return RefreshIndicator(
      color: Shop.sign,
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        await ref.read(sessionProvider.notifier).refreshShops();
      },
      child: dashboard.when(
        loading: () => const _AnalyticsSkeleton(),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            ShopError(
              failure: ApiFailure.from(error),
              onRetry: () => ref.invalidate(dashboardProvider),
            ),
          ],
        ),
        data: (data) => _AnalyticsBody(data: data, shop: shop),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.data, required this.shop});

  final MerchantDashboard data;
  final ShopSummary shop;

  @override
  Widget build(BuildContext context) {
    final totals = data.totals;
    final engagement = totals.views <= 0
        ? 0.0
        : (totals.clicks / totals.views * 100).clamp(0, 100).toDouble();
    final currentEngagement = shop.viewCount <= 0
        ? 0.0
        : (shop.clickCount / shop.viewCount * 100).clamp(0, 100).toDouble();
    final viewShare = totals.views <= 0
        ? 0.0
        : (shop.viewCount / totals.views * 100).clamp(0, 100).toDouble();
    final clickShare = totals.clicks <= 0
        ? 0.0
        : (shop.clickCount / totals.clicks * 100).clamp(0, 100).toDouble();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
      children: [
        _Hero(
          shop: shop,
          engagement: currentEngagement,
          views: shop.viewCount,
          clicks: shop.clickCount,
        ),
        const SizedBox(height: Gap.xl),
        const SectionTitle('أداء الحساب'),
        const SizedBox(height: Gap.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            final width = wide
                ? (constraints.maxWidth - Gap.sm) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.visibility_outlined,
                    label: 'المشاهدات',
                    value: '${totals.views}',
                    hint: 'إجمالي ظهور أنشطتك للعملاء',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.touch_app_outlined,
                    label: 'التفاعلات',
                    value: '${totals.clicks}',
                    hint: 'النقرات والتفاعلات المسجلة',
                    tone: Shop.jade,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.star_rounded,
                    label: 'متوسط التقييم',
                    value: totals.averageRating.toStringAsFixed(1),
                    hint: '${totals.reviews} تقييم',
                    tone: Shop.brass,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'الكتالوج',
                    value: '${totals.products}',
                    hint: 'منتج وخدمة ظاهرين في حسابك',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Gap.xl),
        const SectionTitle('جودة التحويل'),
        const SizedBox(height: Gap.sm),
        _RateCard(
          title: 'معدل التفاعل — كل الحساب',
          value: engagement,
          description: 'نسبة التفاعلات إلى المشاهدات المسجلة لكل أنشطتك.',
          icon: Icons.trending_up_rounded,
        ),
        const SizedBox(height: Gap.sm),
        _RateCard(
          title: 'معدل التفاعل — ${shop.nameAr}',
          value: currentEngagement,
          description: 'يساعدك تعرف هل ظهور النشاط بيتحول لتفاعل فعلي.',
          icon: Icons.storefront_outlined,
          tone: Shop.jade,
        ),
        const SizedBox(height: Gap.xl),
        const SectionTitle('مساهمة النشاط الحالي'),
        const SizedBox(height: Gap.sm),
        _ShareCard(
          label: 'حصة المشاهدات',
          value: viewShare,
          current: shop.viewCount,
          total: totals.views,
          icon: Icons.remove_red_eye_outlined,
        ),
        const SizedBox(height: Gap.sm),
        _ShareCard(
          label: 'حصة التفاعلات',
          value: clickShare,
          current: shop.clickCount,
          total: totals.clicks,
          icon: Icons.ads_click_outlined,
          tone: Shop.jade,
        ),
        const SizedBox(height: Gap.xl),
        _QualityCard(data: data, shop: shop),
        const SizedBox(height: Gap.md),
        Text(
          'الأرقام المعروضة هي البيانات الحالية المسجلة في حسابك. '
          'هنضيف الرسوم حسب الأيام والفترات بمجرد توفر بيانات زمنية من الخادم.',
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.shop,
    required this.engagement,
    required this.views,
    required this.clicks,
  });

  final ShopSummary shop;
  final double engagement;
  final int views;
  final int clicks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.sign,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليلات ${shop.nameAr}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: Gap.xs),
          const Text(
            'لقطة سريعة على الظهور والتفاعل وجودة الأداء.',
            style: TextStyle(color: Color(0xFFC8D6D0), height: 1.5),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(child: _HeroMetric(label: 'مشاهدة', value: '$views')),
              Container(width: 1, height: 38, color: const Color(0xFF49675C)),
              Expanded(child: _HeroMetric(label: 'تفاعل', value: '$clicks')),
              Container(width: 1, height: 38, color: const Color(0xFF49675C)),
              Expanded(
                child: _HeroMetric(
                  label: 'معدل التفاعل',
                  value: '${engagement.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: MerchantTheme.figure(size: 22, color: Colors.white),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Color(0xFF9DB5AB), fontSize: 11.5)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    this.tone = Shop.sign,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.rule),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone, size: 21),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: MerchantTheme.figure(size: 21, color: tone)),
                Text(
                  hint,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    this.tone = Shop.sign,
  });

  final String title;
  final double value;
  final String description;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone, size: 20),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              Text('${value.toStringAsFixed(1)}%', style: MerchantTheme.figure(size: 20, color: tone)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: Shop.paper,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.label,
    required this.value,
    required this.current,
    required this.total,
    required this.icon,
    this.tone = Shop.sign,
  });

  final String label;
  final double value;
  final int current;
  final int total;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.rule),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tone.withValues(alpha: 0.09),
            child: Icon(icon, color: tone, size: 19),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text('$current من $total', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          Text('${value.toStringAsFixed(1)}%', style: MerchantTheme.figure(size: 18, color: tone)),
        ],
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.data, required this.shop});

  final MerchantDashboard data;
  final ShopSummary shop;

  @override
  Widget build(BuildContext context) {
    final attention = data.attention;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('صحة النشاط', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Gap.md),
          _QualityRow(
            icon: shop.isVerified ? Icons.verified_rounded : Icons.pending_outlined,
            label: 'التوثيق',
            value: shop.isVerified ? 'موثّق' : 'قيد المراجعة',
            positive: shop.isVerified,
          ),
          _QualityRow(
            icon: Icons.rate_review_outlined,
            label: 'تقييمات تنتظر رد',
            value: '${attention.reviewsWithoutReply}',
            positive: attention.reviewsWithoutReply == 0,
          ),
          _QualityRow(
            icon: Icons.local_offer_outlined,
            label: 'عروض تنتهي قريبًا',
            value: '${attention.dealsExpiringSoon}',
            positive: attention.dealsExpiringSoon == 0,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.positive,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool positive;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tone = positive ? Shop.jade : Shop.brass;
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : Gap.md, top: last ? Gap.md : 0),
      decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Shop.rule))),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: TextStyle(color: tone, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        Container(height: 180, decoration: BoxDecoration(color: Shop.rule, borderRadius: BorderRadius.circular(22))),
        const SizedBox(height: Gap.lg),
        for (var i = 0; i < 5; i++) ...[
          Container(height: 92, decoration: BoxDecoration(color: Shop.rule, borderRadius: BorderRadius.circular(Radii.card))),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}
