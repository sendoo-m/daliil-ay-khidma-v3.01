import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import 'deals_page.dart';

class DealsManagerPage extends ConsumerStatefulWidget {
  const DealsManagerPage({super.key});

  @override
  ConsumerState<DealsManagerPage> createState() => _DealsManagerPageState();
}

class _DealsManagerPageState extends ConsumerState<DealsManagerPage> {
  final _search = TextEditingController();
  _DealFilter _filter = _DealFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deals = ref.watch(dealsProvider);

    return deals.when(
      loading: () => const Loading(),
      error: (error, _) => ShopError(
        failure: ApiFailure.from(error),
        onRetry: () => ref.invalidate(dealsProvider),
      ),
      data: (items) => _buildContent(context, items),
    );
  }

  Widget _buildContent(BuildContext context, List<DealItem> items) {
    if (items.isEmpty) {
      return ShopEmpty(
        title: 'مفيش عروض دلوقتي',
        hint: 'اعمل عرض واضح بمدة محددة عشان يظهر للناس في صفحة العروض.',
        action: FilledButton.icon(
          onPressed: () => openDealEditor(context),
          icon: const Icon(Icons.add),
          label: const Text('اعمل أول عرض'),
        ),
      );
    }

    final query = _search.text.trim().toLowerCase();
    final filtered = items.where((deal) {
      final matchesQuery = query.isEmpty ||
          deal.titleAr.toLowerCase().contains(query) ||
          deal.descriptionAr.toLowerCase().contains(query) ||
          deal.termsAr.toLowerCase().contains(query);
      if (!matchesQuery) return false;

      return switch (_filter) {
        _DealFilter.all => true,
        _DealFilter.live => deal.isLive,
        _DealFilter.endingSoon => deal.isEndingSoon,
        _DealFilter.paused => !deal.isActive && !deal.isExpired,
        _DealFilter.expired => deal.isExpired,
      };
    }).toList(growable: false)
      ..sort((a, b) {
        if (a.isEndingSoon != b.isEndingSoon) return a.isEndingSoon ? -1 : 1;
        if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
        final aEnd = a.endDate ?? DateTime(2100);
        final bEnd = b.endDate ?? DateTime(2100);
        return aEnd.compareTo(bEnd);
      });

    final live = items.where((d) => d.isLive).length;
    final endingSoon = items.where((d) => d.isEndingSoon).length;
    final uses = items.fold<int>(0, (sum, d) => sum + d.currentUses);

    return RefreshIndicator(
      color: Shop.sign,
      onRefresh: () async => ref.invalidate(dealsProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
        children: [
          _ManagerHeader(
            total: items.length,
            live: live,
            endingSoon: endingSoon,
            uses: uses,
            onAdd: () => openDealEditor(context),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث في العروض',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: Gap.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in _DealFilter.values) ...[
                  _FilterChip(
                    label: filter.label,
                    selected: _filter == filter,
                    onTap: () => setState(() => _filter = filter),
                  ),
                  if (filter != _DealFilter.values.last)
                    const SizedBox(width: Gap.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xl),
              child: ShopEmpty(
                title: 'مفيش عروض مطابقة',
                hint: 'جرّب تغيّر البحث أو الفلتر.',
              ),
            )
          else
            for (final deal in filtered) ...[
              _ManagerDealCard(deal: deal),
              const SizedBox(height: Gap.sm),
            ],
        ],
      ),
    );
  }
}

enum _DealFilter { all, live, endingSoon, paused, expired }

extension on _DealFilter {
  String get label => switch (this) {
        _DealFilter.all => 'الكل',
        _DealFilter.live => 'شغّالة',
        _DealFilter.endingSoon => 'تنتهي قريبًا',
        _DealFilter.paused => 'موقوفة',
        _DealFilter.expired => 'منتهية',
      };
}

class _ManagerHeader extends StatelessWidget {
  const _ManagerHeader({
    required this.total,
    required this.live,
    required this.endingSoon,
    required this.uses,
    required this.onAdd,
  });

  final int total;
  final int live;
  final int endingSoon;
  final int uses;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(20),
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
                      'إدارة العروض',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'تابع اللي شغّال واللي محتاج تدخل قبل ما ينتهي.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('عرض'),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              _Stat(label: 'الإجمالي', value: '$total'),
              _Stat(label: 'شغّالة', value: '$live', tone: Shop.jade),
              _Stat(
                label: 'تنتهي قريبًا',
                value: '$endingSoon',
                tone: Shop.brass,
              ),
              _Stat(label: 'الاستخدامات', value: '$uses'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.tone = Shop.sign});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: MerchantTheme.figure(size: 19, color: tone)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Shop.sign : Shop.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? Shop.sign : Shop.rule),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Shop.inkSoft,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ManagerDealCard extends ConsumerStatefulWidget {
  const _ManagerDealCard({required this.deal});

  final DealItem deal;

  @override
  ConsumerState<_ManagerDealCard> createState() => _ManagerDealCardState();
}

class _ManagerDealCardState extends ConsumerState<_ManagerDealCard> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(merchantActionsProvider).updateDeal(
        widget.deal.id,
        {'is_active': value},
      );
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message), backgroundColor: Shop.clay),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final (status, tone) = _status(deal);

    return InkWell(
      onTap: () => openDealEditor(context, deal: deal),
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: deal.isEndingSoon
                ? Shop.brass.withValues(alpha: 0.45)
                : Shop.rule,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DealImage(url: deal.imageUrl),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deal.titleAr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: tone,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (deal.descriptionAr.isNotEmpty) ...[
                    const SizedBox(height: Gap.xs),
                    Text(
                      deal.descriptionAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.md,
                    runSpacing: Gap.xs,
                    children: [
                      if ((deal.discountPercentage ?? 0) > 0)
                        _Meta(
                          icon: Icons.percent,
                          text: 'خصم ${deal.discountPercentage}%',
                        ),
                      _Meta(
                        icon: Icons.redeem_outlined,
                        text: '${deal.currentUses} استخدام',
                      ),
                      if (deal.daysLeft != null)
                        _Meta(
                          icon: Icons.schedule_outlined,
                          text: deal.isExpired
                              ? 'انتهى'
                              : deal.daysLeft! <= 0
                                  ? 'ينتهي اليوم'
                                  : 'باقي ${deal.daysLeft} يوم',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: deal.isActive,
                    activeThumbColor: Shop.jade,
                    onChanged: deal.isExpired ? null : _toggle,
                  ),
          ],
        ),
      ),
    );
  }

  static (String, Color) _status(DealItem deal) {
    if (deal.isExpired) return ('منتهي', Shop.inkFaint);
    if (!deal.isActive) return ('موقوف', Shop.inkSoft);
    if (deal.isEndingSoon) return ('قرب ينتهي', Shop.brass);
    if (!deal.isLive) return ('مجدول', Shop.inkSoft);
    return ('شغّال', Shop.jade);
  }
}

class _DealImage extends StatelessWidget {
  const _DealImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Shop.paper,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Shop.rule),
      ),
      child: url == null || url!.isEmpty
          ? const Icon(Icons.local_offer_outlined, color: Shop.inkFaint)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Shop.inkFaint,
              ),
            ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Shop.inkFaint),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
