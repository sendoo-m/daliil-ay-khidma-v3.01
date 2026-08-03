import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

/// الشاشة الرئيسية.
///
/// قرار تصميمي: تبدأ بما ينتظر تدخّلًا، لا بأرقام إجمالية. الموظف يفتح
/// اللوحة ليعرف "ماذا أفعل الآن"، لا "كم عدد المستخدمين". الأرقام
/// الإجمالية أسفل الصفحة لمن يريدها.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final queue = ref.watch(pendingQueueProvider);
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingQueueProvider);
        ref.invalidate(dashboardStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(DalilSpacing.lg),
        children: [
          Text('أهلًا، ${session.user.fullName}', style: text.displaySmall),
          const SizedBox(height: DalilSpacing.xs),
          Row(
            children: [
              Text(session.role.name, style: text.bodySmall),
              const SizedBox(width: DalilSpacing.sm),
              Container(width: 3, height: 3, color: DalilColors.inkFaint),
              const SizedBox(width: DalilSpacing.sm),
              Text(session.scopeLabel, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: DalilSpacing.xl),

          const SectionRule('في انتظارك'),
          const SizedBox(height: DalilSpacing.md),

          queue.when(
            loading: () => const _QueueSkeleton(),
            error: (e, _) => ErrorState(
              failure: ApiFailure.from(e),
              onRetry: () => ref.invalidate(pendingQueueProvider),
            ),
            data: (data) => data.total == 0
                ? const EmptyState(
                    title: 'لا شيء ينتظر',
                    hint: 'الطابور فاضي. كل القيود مراجَعة.',
                  )
                : _QueueGrid(data: data, session: session),
          ),

          const SizedBox(height: DalilSpacing.xl),

          if (session.can(Perm.analyticsView)) ...[
            const SectionRule('إجماليات المنصة'),
            const SizedBox(height: DalilSpacing.md),
            const _StatsBlock(),
          ],
        ],
      ),
    );
  }
}

class _QueueGrid extends StatelessWidget {
  const _QueueGrid({required this.data, required this.session});

  final PendingQueue data;
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (session.can(Perm.businessVerify))
        _QueueCard(
          count: data.businesses,
          label: 'نشاط ينتظر التوثيق',
          action: 'راجع الأنشطة',
          route: '/businesses?is_verified=false',
          stamp: RecordStamp.pending,
        ),
      if (session.can(Perm.reviewModerate))
        _QueueCard(
          count: data.reviews,
          label: 'تقييم ينتظر الاعتماد',
          action: 'راجع التقييمات',
          route: '/reviews?is_approved=false',
          stamp: RecordStamp.pending,
        ),
      if (session.can(Perm.dealView))
        _QueueCard(
          count: data.expiringDeals,
          label: 'عرض ينتهي خلال ٣ أيام',
          action: 'افتح العروض',
          route: '/deals',
          stamp: RecordStamp.featured,
        ),
    ];

    if (cards.isEmpty) {
      return const EmptyState(
        title: 'لا يوجد طابور مخصص لدورك',
        hint: 'استخدم القائمة للتنقّل بين الأقسام المتاحة لك.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        return Wrap(
          spacing: DalilSpacing.md,
          runSpacing: DalilSpacing.md,
          children: [
            for (final card in cards)
              SizedBox(
                width: (constraints.maxWidth -
                        (DalilSpacing.md * (columns - 1))) /
                    columns,
                child: card,
              ),
          ],
        );
      },
    );
  }
}

/// بطاقة طابور: الرقم هو البطل، والباقي يخدمه.
class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.count,
    required this.label,
    required this.action,
    required this.route,
    required this.stamp,
  });

  final int count;
  final String label;
  final String action;
  final String route;
  final RecordStamp stamp;

  @override
  Widget build(BuildContext context) {
    final idle = count == 0;
    final tone = idle ? DalilColors.inkFaint : stamp.color;

    return Container(
      decoration: BoxDecoration(
        color: DalilColors.surface,
        border: Border.all(color: DalilColors.rule),
        borderRadius: BorderRadius.circular(DalilRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: tone),
          Padding(
            padding: const EdgeInsets.all(DalilSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: AdminTheme.mono(
                    size: 40,
                    weight: FontWeight.w600,
                    color: tone,
                    spacing: -1,
                  ),
                ),
                const SizedBox(height: DalilSpacing.xs),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: DalilSpacing.md),
                if (!idle)
                  OutlinedButton(
                    onPressed: () {/* router.go(route) */},
                    child: Text(action),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBlock extends ConsumerWidget {
  const _StatsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);

    return stats.when(
      loading: () => const _QueueSkeleton(),
      error: (e, _) => ErrorState(
        failure: ApiFailure.from(e),
        onRetry: () => ref.invalidate(dashboardStatsProvider),
      ),
      data: (data) {
        final users = data['users'] as Map<String, dynamic>? ?? const {};
        final biz = data['businesses'] as Map<String, dynamic>? ?? const {};
        final content = data['content'] as Map<String, dynamic>? ?? const {};

        return Container(
          decoration: BoxDecoration(
            color: DalilColors.surface,
            border: Border.all(color: DalilColors.rule),
            borderRadius: BorderRadius.circular(DalilRadii.card),
          ),
          child: Column(
            children: [
              _StatRow('المستخدمون', users['total'], users['new_this_week'],
                  'جديد هذا الأسبوع'),
              const Divider(),
              _StatRow('الأنشطة', biz['total'], biz['verified'], 'موثّق'),
              const Divider(),
              _StatRow('المنتجات', content['products'], null, null),
              const Divider(),
              _StatRow('التقييمات', content['reviews_total'],
                  content['reviews_pending'], 'بانتظار المراجعة'),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, this.subValue, this.subLabel);

  final String label;
  final Object? value;
  final Object? subValue;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DalilSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (subValue != null && subLabel != null) ...[
            Text(
              '$subValue $subLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: DalilSpacing.md),
          ],
          Text(
            '${value ?? 0}',
            style: AdminTheme.mono(
              size: 16,
              weight: FontWeight.w600,
              color: DalilColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: DalilColors.surfaceSunken,
        borderRadius: BorderRadius.circular(DalilRadii.card),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
