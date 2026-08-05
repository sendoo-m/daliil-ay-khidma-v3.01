import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

/// الشاشة الرئيسية.
///
/// الترتيب مقصود: اللافتة أولًا (محلك، وده اللي فتحت التطبيق عشانه)،
/// بعدين اللي محتاج إيدك، وأخيرًا الأرقام. صاحب المحل مش بيفتح التطبيق
/// عشان يشوف إحصائيات — بيفتحه عشان يعرف فيه إيه.
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
            padding: const EdgeInsets.all(Gap.lg),
            child: dashboard.when(
              loading: () => const Loading(),
              error: (e, _) => ShopError(
                failure: ApiFailure.from(e),
                onRetry: () => ref.invalidate(dashboardProvider),
              ),
              data: (data) => _Body(data: data, onOpenTab: onOpenTab),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.md),
            Text('اختار النشاط', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            for (final s in session.shops)
              ListTile(
                title: Text(s.nameAr),
                subtitle: s.placeLine.isEmpty ? null : Text(s.placeLine),
                trailing: s.id == ref.read(selectedShopProvider)
                    ? const Icon(Icons.check, color: Shop.jade, size: 20)
                    : null,
                onTap: () {
                  ref.read(selectedShopProvider.notifier).state = s.id;
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

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.onOpenTab});

  final MerchantDashboard data;
  final void Function(int) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final a = data.attention;
    final tasks = <Widget>[
      if (a.reviewsWithoutReply > 0)
        TaskCard(
          count: a.reviewsWithoutReply,
          label: 'تقييم لسه من غير رد',
          action: 'الرد بيفرق مع العميل الجاي',
          tone: Shop.clay,
          onTap: () => onOpenTab(1),
        ),
      if (a.dealsExpiringSoon > 0)
        TaskCard(
          count: a.dealsExpiringSoon,
          label: 'عرض بيخلص قريب',
          action: 'مدّده أو اعمل غيره',
          tone: Shop.brass,
          onTap: () => onOpenTab(2),
        ),
      if (a.awaitingVerification > 0)
        TaskCard(
          count: a.awaitingVerification,
          label: 'نشاط لسه مستني التوثيق',
          action: 'كمّل بياناتك عشان نراجعه أسرع',
          tone: Shop.inkSoft,
          onTap: () => onOpenTab(3),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('محتاج إيدك'),
        if (tasks.isEmpty)
          _AllClear()
        else
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: task,
            ),

        const SizedBox(height: Gap.xl),
        const SectionTitle('محلك في أرقام'),
        _Numbers(totals: data.totals),
      ],
    );
  }
}

class _AllClear extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.jadeWash,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.jade.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Shop.jade, size: 22),
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
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.totals});

  final ShopTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.rule),
      ),
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        children: [
          Row(
            children: [
              _Figure(
                value: _compact(totals.views),
                label: 'مشاهدة',
                tone: Shop.sign,
              ),
              _Divider(),
              _Figure(
                value: _compact(totals.clicks),
                label: 'ضغطة على رقمك',
                tone: Shop.sign,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Gap.md),
            child: Divider(),
          ),
          Row(
            children: [
              _Figure(
                value: totals.averageRating > 0
                    ? totals.averageRating.toStringAsFixed(1)
                    : '—',
                label: 'متوسط التقييم',
                tone: Shop.brass,
              ),
              _Divider(),
              _Figure(
                value: '${totals.products}',
                label: 'منتج أو خدمة',
                tone: Shop.sign,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 1240 → ١٫٢ ألف. الرقم الدقيق مش مهم هنا، الحجم هو المهم.
  static String _compact(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)} ألف';
    return '${(n / 1000000).toStringAsFixed(1)} مليون';
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, required this.tone});

  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: MerchantTheme.figure(size: 28, color: tone)),
          const SizedBox(height: Gap.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 46, color: Shop.rule);
}
