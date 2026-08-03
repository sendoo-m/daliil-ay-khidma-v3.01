import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../data/catalog_models.dart';
import 'catalog_detail_pages.dart';

final _dealsProvider = FutureProvider.autoDispose
    .family<List<DealSummary>, ({String search, String ordering})>(
  (ref, query) => ref.watch(catalogRepositoryProvider).deals(
        search: query.search,
        ordering: query.ordering,
      ),
);

class DealsPage extends ConsumerStatefulWidget {
  const DealsPage({super.key});

  @override
  ConsumerState<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends ConsumerState<DealsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String _ordering = '-created_at';

  ({String search, String ordering}) get _query =>
      (search: _search, ordering: _ordering);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final deals = ref.watch(_dealsProvider(_query));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _DealsHeader(
              controller: _searchController,
              onSearch: _onSearch,
              onClear: () {
                _searchController.clear();
                setState(() => _search = '');
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _OrderChip(
                      label: 'الأحدث',
                      icon: Icons.auto_awesome_rounded,
                      selected: _ordering == '-created_at',
                      onTap: () => setState(() => _ordering = '-created_at'),
                    ),
                    const SizedBox(width: 8),
                    _OrderChip(
                      label: 'ينتهي قريبًا',
                      icon: Icons.timer_outlined,
                      selected: _ordering == 'end_date',
                      onTap: () => setState(() => _ordering = 'end_date'),
                    ),
                    const SizedBox(width: 8),
                    _OrderChip(
                      label: 'الأكثر مشاهدة',
                      icon: Icons.trending_up_rounded,
                      selected: _ordering == '-view_count',
                      onTap: () => setState(() => _ordering = '-view_count'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: deals.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _MessageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'تعذر تحميل العروض',
                  message: 'تحقق من الاتصال ثم حاول مرة أخرى.',
                  action: () => ref.invalidate(_dealsProvider(_query)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _MessageState(
                      icon: Icons.local_offer_outlined,
                      title: _search.isEmpty
                          ? 'لا توجد عروض متاحة الآن'
                          : 'لا توجد نتائج مطابقة',
                      message: _search.isEmpty
                          ? 'ستظهر العروض الجديدة هنا فور إضافتها.'
                          : 'جرّب كلمة بحث مختلفة أو امسح البحث.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(_dealsProvider(_query).future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, index) => _DealCard(
                        deal: items[index],
                        featured: index == 0,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealsHeader extends StatelessWidget {
  const _DealsHeader({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .25),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_offer_rounded, color: Colors.white, size: 30),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العروض والخصومات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'اكتشف أفضل الصفقات من الأنشطة المسجلة',
                        style: TextStyle(color: Color(0xFFEDEBFF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'ابحث في العروض أو أسماء المحلات',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ],
        ),
      );
}

class _OrderChip extends StatelessWidget {
  const _OrderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? AppColors.primary : AppColors.muted,
        ),
        label: Text(label),
      );
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal, required this.featured});

  final DealSummary deal;
  final bool featured;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DealDetailPage(slug: deal.slug),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  _DealImage(url: deal.image, featured: featured),
                  PositionedDirectional(
                    top: 12,
                    start: 12,
                    child: _Badge(text: deal.typeLabel),
                  ),
                  if (deal.daysRemaining <= 3)
                    const PositionedDirectional(
                      top: 12,
                      end: 12,
                      child: _Badge(text: 'ينتهي قريبًا', urgent: true),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (deal.businessName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              deal.businessName,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (deal.hasPrice) ...[
                          Text(
                            _money(deal.finalPrice!),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (deal.hasDiscount) ...[
                            const SizedBox(width: 9),
                            Text(
                              _money(deal.originalPrice!),
                              style: const TextStyle(
                                color: AppColors.muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ] else
                          Text(
                            deal.typeLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text('متبقي ${deal.daysRemaining} يوم'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _DealImage extends StatelessWidget {
  const _DealImage({required this.url, required this.featured});

  final String? url;
  final bool featured;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: featured ? 210 : 180,
        width: double.infinity,
        child: url == null || url!.isEmpty
            ? const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.brandGradient),
                child: Center(
                  child: Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.brandGradient),
                  child: Center(
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),
              ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.urgent = false});

  final String text;
  final bool urgent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: urgent ? Colors.deepOrange : AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: action,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
      );
}

String _money(double value) =>
    '${NumberFormat('#,##0.##', 'ar').format(value)} ج.م';
