import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/presentation/catalog_detail_pages.dart';
import '../data/business.dart';
import '../data/discovery_repository.dart';
import 'business_card.dart';

class DiscoveryV3Content extends StatelessWidget {
  const DiscoveryV3Content({
    required this.discovery,
    required this.categories,
    required this.history,
    required this.isArabic,
    required this.onSearch,
    required this.onCategory,
    required this.onRemoveHistory,
    required this.onClearHistory,
    this.onRefresh,
    super.key,
  });

  final AsyncValue<DiscoveryData> discovery;
  final List<Map<String, dynamic>> categories;
  final AsyncValue<List<String>> history;
  final bool isArabic;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onCategory;
  final ValueChanged<String> onRemoveHistory;
  final VoidCallback onClearHistory;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final recent = history.valueOrNull ?? const <String>[];
    final media = MediaQuery.sizeOf(context);
    final horizontalPadding = media.width >= 720 ? 24.0 : 16.0;

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: CustomScrollView(
        key: const PageStorageKey<String>('discovery-v3-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        // مهجورة لكنها تعمل. البديل `scrollCacheExtent` يأخذ
        // ‏ScrollCacheExtent لا رقمًا، وتغييره بلا تحقق حوّل تحذيرًا
        // غير مؤذٍ إلى خطأ يوقف البناء. يُترك حتى يُختبر محليًا.
        // ignore: deprecated_member_use
        cacheExtent: 700,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              36,
            ),
            sliver: SliverList.list(
              children: [
                if (recent.isNotEmpty) ...[
                  _Title(
                    icon: Icons.history_rounded,
                    title: isArabic ? 'عمليات البحث الأخيرة' : 'Recent searches',
                    action: isArabic ? 'مسح الكل' : 'Clear all',
                    onAction: onClearHistory,
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    container: true,
                    label: isArabic ? 'عمليات البحث الأخيرة' : 'Recent searches',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recent
                          .take(8)
                          .map(
                            (item) => InputChip(
                              avatar: const Icon(Icons.history_rounded, size: 17),
                              label: Text(item),
                              tooltip: isArabic
                                  ? 'ابحث عن $item'
                                  : 'Search for $item',
                              deleteButtonTooltipMessage: isArabic
                                  ? 'حذف $item من السجل'
                                  : 'Remove $item from history',
                              onPressed: () => onSearch(item),
                              onDeleted: () => onRemoveHistory(item),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
                if (categories.isNotEmpty) ...[
                  _Title(
                    icon: Icons.grid_view_rounded,
                    title: isArabic ? 'استكشف الأقسام' : 'Explore categories',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 106,
                    child: ListView.separated(
                      key: const PageStorageKey<String>('discovery-categories'),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.take(10).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        final id = item['id'] as int?;
                        final label =
                            '${item[isArabic ? 'name_ar' : 'name_en'] ?? item['name_ar'] ?? item['name_en'] ?? ''}';
                        return Semantics(
                          button: id != null,
                          label: isArabic
                              ? 'استكشف قسم $label'
                              : 'Explore $label category',
                          child: SizedBox(
                            width: 108,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: id == null ? null : () => onCategory(id),
                              child: Ink(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.category_rounded,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, if (currentChild != null) currentChild],
                  ),
                  child: discovery.when(
                    loading: () => const _LoadingSections(
                      key: ValueKey<String>('discovery-loading'),
                    ),
                    error: (_, __) => _FallbackSearches(
                      key: const ValueKey<String>('discovery-fallback'),
                      isArabic: isArabic,
                      onSearch: onSearch,
                    ),
                    data: (data) => _DiscoverySections(
                      key: const ValueKey<String>('discovery-data'),
                      data: data,
                      isArabic: isArabic,
                      onSearch: onSearch,
                    ),
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

class _DiscoverySections extends StatelessWidget {
  const _DiscoverySections({
    required this.data,
    required this.isArabic,
    required this.onSearch,
    super.key,
  });

  final DiscoveryData data;
  final bool isArabic;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PopularSearches(
            items: isArabic ? data.popularSearchesAr : data.popularSearchesEn,
            isArabic: isArabic,
            onSearch: onSearch,
          ),
          if (data.trendingBusinesses.isNotEmpty) ...[
            const SizedBox(height: 26),
            _BusinessSection(
              title: isArabic ? 'الأكثر رواجًا' : 'Trending businesses',
              icon: Icons.local_fire_department_rounded,
              items: data.trendingBusinesses,
            ),
          ],
          if (data.recommendedBusinesses.isNotEmpty) ...[
            const SizedBox(height: 26),
            _BusinessSection(
              title: isArabic ? 'موصى به لك' : 'Recommended for you',
              icon: Icons.auto_awesome_rounded,
              items: data.recommendedBusinesses,
            ),
          ],
          if (data.popularProducts.isNotEmpty) ...[
            const SizedBox(height: 26),
            _ProductSection(
              title: isArabic
                  ? 'منتجات وخدمات شائعة'
                  : 'Popular products & services',
              items: data.popularProducts,
              isArabic: isArabic,
            ),
          ],
        ],
      );
}

class _Title extends StatelessWidget {
  const _Title({
    required this.icon,
    required this.title,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                child: Text(action!),
              ),
          ],
        ),
      );
}

class _PopularSearches extends StatelessWidget {
  const _PopularSearches({
    required this.items,
    required this.isArabic,
    required this.onSearch,
  });

  final List<String> items;
  final bool isArabic;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(
            icon: Icons.trending_up_rounded,
            title: isArabic ? 'الأكثر بحثًا' : 'Popular searches',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: items
                .map(
                  (item) => ActionChip(
                    avatar: const Icon(Icons.search_rounded, size: 17),
                    label: Text(item),
                    tooltip: isArabic ? 'ابحث عن $item' : 'Search for $item',
                    onPressed: () => onSearch(item),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      );
}

class _BusinessSection extends StatelessWidget {
  const _BusinessSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<Business> items;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(icon: icon, title: title),
          const SizedBox(height: 10),
          ...items.take(5).map(
                (item) => RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BusinessCard(business: item),
                  ),
                ),
              ),
        ],
      );
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.title,
    required this.items,
    required this.isArabic,
  });

  final String title;
  final List<ProductSummary> items;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(icon: Icons.shopping_bag_rounded, title: title),
          const SizedBox(height: 10),
          SizedBox(
            height: 210,
            child: ListView.separated(
              key: const PageStorageKey<String>('discovery-products'),
              scrollDirection: Axis.horizontal,
              // ignore: deprecated_member_use
              cacheExtent: 600,
              itemCount: items.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Semantics(
                  button: true,
                  label: isArabic
                      ? '${item.name}، السعر ${item.price} جنيه مصري'
                      : '${item.name}, price ${item.price} EGP',
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: 176,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProductDetailPage(slug: item.slug),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: item.image == null
                                    ? const Center(
                                        child: Icon(
                                          Icons.inventory_2_outlined,
                                          size: 42,
                                        ),
                                      )
                                    : Image.network(
                                        item.image!,
                                        fit: BoxFit.cover,
                                        cacheWidth: 420,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 36,
                                          ),
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isArabic
                                          ? '${item.price} ج.م'
                                          : '${item.price} EGP',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
}

class _LoadingSections extends StatelessWidget {
  const _LoadingSections({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading discovery content',
        child: ExcludeSemantics(
          child: Column(
            children: List.generate(
              3,
              (index) => _SkeletonCard(index: index),
            ),
          ),
        ),
      );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: .55, end: 1),
        duration: Duration(milliseconds: 650 + (index * 100)),
        curve: Curves.easeInOut,
        builder: (context, opacity, child) => Opacity(
          opacity: opacity,
          child: child,
        ),
        child: Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: LinearProgressIndicator(minHeight: 5),
          ),
        ),
      );
}

class _FallbackSearches extends StatelessWidget {
  const _FallbackSearches({
    required this.isArabic,
    required this.onSearch,
    super.key,
  });

  final bool isArabic;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => _PopularSearches(
        items: isArabic
            ? const ['مطاعم', 'كافيهات', 'صيدليات', 'سباك', 'كهربائي', 'عروض']
            : const [
                'Restaurants',
                'Cafes',
                'Pharmacies',
                'Plumber',
                'Electrician',
                'Deals',
              ],
        isArabic: isArabic,
        onSearch: onSearch,
      );
}
