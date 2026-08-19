import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../auth/presentation/login_page.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/presentation/catalog_detail_pages.dart';
import '../../directory/data/business.dart';
import '../../directory/presentation/business_card.dart';
import '../../browse/presentation/browse_hub_page.dart';
import '../../browse/presentation/browse_results_page.dart';
import '../../notifications/presentation/notifications_page.dart';

class HomePageV4 extends ConsumerWidget {
  const HomePageV4({required this.onSearchTap, super.key});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final authenticated = ref.watch(authControllerProvider).valueOrNull ?? false;
    return Scaffold(
      body: SafeArea(
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorState(
            onRetry: () => ref.invalidate(homeProvider),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.refresh(homeProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _BrandHero(
                    authenticated: authenticated,
                    onSearchTap: onSearchTap,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DirectoryEntry(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BrowseHubPage(),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _DealsSpotlight(items: data.deals)),
                SliverToBoxAdapter(
                  child: _CategoryRail(items: data.categories),
                ),
                SliverToBoxAdapter(
                  child: _BusinessSection(items: data.businesses),
                ),
                SliverToBoxAdapter(child: _ProductRail(items: data.products)),
                const SliverToBoxAdapter(child: SizedBox(height: 34)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.authenticated, required this.onSearchTap});

  final bool authenticated;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .28),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const DalilLogo(size: 38),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دليل أي خدمة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'كل ما تحتاجه حولك في مكان واحد',
                        style: TextStyle(color: Color(0xFFE9E8FF)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'الإشعارات',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .15),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => authenticated
                          ? const NotificationsPage()
                          : const LoginPage(),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'ابحث. قارن. اختَر الأفضل.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                height: 1.35,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'محلات وخدمات ومنتجات وعروض موثوقة بالقرب منك',
              style: TextStyle(color: Color(0xFFF0EFFF), fontSize: 14),
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ابحث عن محل، منتج أو خدمة',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      Icon(Icons.tune_rounded, color: AppColors.secondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _DirectoryEntry extends StatelessWidget {
  const _DirectoryEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.apps_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الأقسام والمحافظات',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'افتح الدليل الكامل واختر القسم أو المحافظة',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _DealsSpotlight extends StatelessWidget {
  const _DealsSpotlight({required this.items});

  final List<DealSummary> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'أقوى العروض الآن',
      subtitle: 'خصومات مختارة تستحق المشاهدة',
      child: SizedBox(
        height: 205,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 310,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DealDetailPage(slug: item.slug),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.secondary, AppColors.primary],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.local_offer_rounded,
                              color: Colors.white,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'متبقي ${item.daysRemaining} يوم',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            // العرض قد يكون بلا سعر (هدية، خدمة مجانية).
                            // ‏finalPrice نوعه double? — طباعته مباشرة تُظهر
                            // كلمة null للمستخدم. hasPrice موجودة في الموديل
                            // لهذا الغرض بالضبط.
                            if (item.hasPrice)
                              Text(
                                '${item.finalPrice!.toStringAsFixed(0)} جنيه',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            else
                              const Text(
                                'عرض مجاني',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ],
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
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'تصفح حسب القسم',
      subtitle: 'الوصول السريع لأكثر الأقسام استخدامًا',
      child: SizedBox(
        height: 126,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length > 10 ? 10 : items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) {
            final item = items[index];
            final name = '${item['name_ar'] ?? ''}';
            final id = item['id'] as int?;
            return SizedBox(
              width: 96,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                // كانت بلا onTap تمامًا: اسم وأيقونة ولا شيء يحدث
                // عند الضغط، وهو أسوأ من غياب القسم أصلًا.
                onTap: id == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BrowseResultsPage(
                              title: name,
                              categoryId: id,
                            ),
                          ),
                        ),
                child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? AppColors.primarySoft
                          : AppColors.secondarySoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BusinessSection extends StatelessWidget {
  const _BusinessSection({required this.items});

  final List<Business> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'أنشطة مميزة',
      subtitle: 'اختيارات موثوقة وأعلى تقييمًا',
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length > 4 ? 4 : items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => BusinessCard(business: items[index]),
      ),
    );
  }
}

class _ProductRail extends StatelessWidget {
  const _ProductRail({required this.items});

  final List<ProductSummary> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'منتجات وخدمات مختارة',
      subtitle: 'اكتشف الجديد من الأنشطة المسجلة',
      child: SizedBox(
        height: 230,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: item.image == null || item.image!.isEmpty
                            ? const ColoredBox(
                                color: AppColors.primarySoft,
                                child: Center(
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.primary,
                                    size: 42,
                                  ),
                                ),
                              )
                            : Image.network(
                                item.image!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              // ‏ProductSummary.price نصّ لا رقم —
                              // ‏ProductDetail هو الذي يحمل double.
                              '${item.displayPrice} جنيه',
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
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 54),
              const SizedBox(height: 14),
              const Text('تعذر تحميل الصفحة الرئيسية'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
}
