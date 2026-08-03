import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../auth/presentation/login_page.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/presentation/catalog_detail_pages.dart';
import '../../directory/data/business.dart';
import '../../directory/presentation/business_card.dart';
import '../../directory/presentation/search_page.dart';
import '../../location/presentation/nearby_page.dart';
import '../../notifications/presentation/notifications_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({required this.onSearchTap, super.key});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final isAuthenticated =
        ref.watch(authControllerProvider).valueOrNull ?? false;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: home.when(
          loading: () => const _HomeLoading(),
          error: (_, __) => _HomeError(
            isArabic: isArabic,
            onRetry: () => ref.invalidate(homeProvider),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.refresh(homeProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HomeHeader(
                    isArabic: isArabic,
                    onSearchTap: onSearchTap,
                    isAuthenticated: isAuthenticated,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _QuickActions(
                    isArabic: isArabic,
                    onSearchTap: onSearchTap,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HomeOverview(
                    isArabic: isArabic,
                    businesses: data.businesses.length,
                    products: data.products.length,
                    deals: data.deals.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoriesSection(
                    categories: data.categories,
                    isArabic: isArabic,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _BusinessesSection(
                    items: data.businesses,
                    isArabic: isArabic,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ProductsSection(
                    items: data.products,
                    isArabic: isArabic,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DealsSection(
                    items: data.deals,
                    isArabic: isArabic,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 34)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.isArabic,
    required this.onSearchTap,
    required this.isAuthenticated,
  });

  final bool isArabic;
  final VoidCallback onSearchTap;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        decoration: const BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.place_outlined, color: Colors.white),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'دليل أي خدمة' : 'Daliil Ay Khidma',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        ),
                      ),
                      Text(
                        isArabic
                            ? 'كل ما تحتاجه بالقرب منك'
                            : 'Everything you need nearby',
                        style: const TextStyle(color: Color(0xFFE8E5FF)),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: isArabic ? 'الإشعارات' : 'Notifications',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .14),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => isAuthenticated
                          ? const NotificationsPage()
                          : const LoginPage(),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              isArabic ? 'ماذا تبحث عنه اليوم؟' : 'What do you need today?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              isArabic
                  ? 'اكتشف أفضل الأنشطة والمنتجات والعروض في مكان واحد.'
                  : 'Discover businesses, products and deals in one place.',
              style: const TextStyle(color: Color(0xFFE8E5FF), height: 1.5),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'ابحث عن محل، منتج أو خدمة'
                            : 'Search a business, product or service',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    const Icon(Icons.tune_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isArabic, required this.onSearchTap});

  final bool isArabic;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String title, VoidCallback onTap})>[
      (
        icon: Icons.near_me_rounded,
        title: isArabic ? 'بالقرب مني' : 'Nearby',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NearbyPage()),
        ),
      ),
      (
        icon: Icons.storefront_rounded,
        title: isArabic ? 'الأنشطة' : 'Businesses',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchPage()),
        ),
      ),
      (
        icon: Icons.shopping_bag_rounded,
        title: isArabic ? 'المنتجات' : 'Products',
        onTap: onSearchTap,
      ),
      (
        icon: Icons.local_offer_rounded,
        title: isArabic ? 'العروض' : 'Deals',
        onTap: onSearchTap,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: actions
            .map(
              (action) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: action.onTap,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: .09),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(action.icon, color: AppColors.primary),
                          const SizedBox(height: 7),
                          Text(
                            action.title,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({
    required this.isArabic,
    required this.businesses,
    required this.products,
    required this.deals,
  });

  final bool isArabic;
  final int businesses;
  final int products;
  final int deals;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isArabic
                    ? '$businesses أنشطة مميزة • $products منتجات • $deals عروض'
                    : '$businesses businesses • $products products • $deals deals',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.categories, required this.isArabic});

  final List<Map<String, dynamic>> categories;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => _Section(
        title: isArabic ? 'تصفح حسب القسم' : 'Browse by category',
        subtitle: isArabic ? 'اختر القسم المناسب لك' : 'Choose what you need',
        child: categories.isEmpty
            ? _SectionEmpty(
                isArabic: isArabic,
                message: isArabic
                    ? 'لا توجد أقسام متاحة الآن'
                    : 'No categories available yet',
              )
            : SizedBox(
                height: 116,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = categories[index];
                    final name =
                        '${item[isArabic ? 'name_ar' : 'name_en'] ?? item['name_ar'] ?? ''}';
                    final iconUrl = '${item['icon'] ?? ''}';
                    final categoryId = item['id'] as int?;
                    return SizedBox(
                      width: 84,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        // ✅ إرسال initialCategoryId فقط بدون initialQuery
                        // حتى لا يختلط فلتر القسم مع البحث النصي
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SearchPage(
                              initialCategoryId: categoryId,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(21),
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: .1),
                                ),
                              ),
                              child: !iconUrl.startsWith('http')
                                  ? const Icon(Icons.grid_view_rounded,
                                      color: AppColors.primary)
                                  : Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Image.network(
                                        iconUrl,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.grid_view_rounded,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
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

class _BusinessesSection extends StatelessWidget {
  const _BusinessesSection({required this.items, required this.isArabic});

  final List<Business> items;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => _Section(
        title: isArabic ? 'أنشطة مميزة' : 'Featured businesses',
        subtitle:
            isArabic ? 'اختيارات موثوقة بالقرب منك' : 'Trusted picks near you',
        actionLabel: isArabic ? 'عرض الكل' : 'See all',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchPage()),
        ),
        child: items.isEmpty
            ? _SectionEmpty(
                isArabic: isArabic,
                message: isArabic
                    ? 'لا توجد أنشطة مميزة الآن'
                    : 'No featured businesses yet',
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length > 4 ? 4 : items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => BusinessCard(business: items[index]),
              ),
      );
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.items, required this.isArabic});

  final List<ProductSummary> items;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => _Section(
        title: isArabic
            ? 'منتجات وخدمات مختارة'
            : 'Selected products & services',
        subtitle:
            isArabic ? 'اقتراحات قد تناسبك' : 'Suggestions you may like',
        child: items.isEmpty
            ? _SectionEmpty(
                isArabic: isArabic,
                message: isArabic
                    ? 'لا توجد منتجات مختارة الآن'
                    : 'No selected products yet',
              )
            : SizedBox(
                height: 230,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => _ProductCard(
                    item: items[index],
                    isArabic: isArabic,
                  ),
                ),
              ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.isArabic});

  final ProductSummary item;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 172,
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
                SizedBox(
                  width: double.infinity,
                  height: 132,
                  child: item.image == null || item.image!.isEmpty
                      ? const ColoredBox(
                          color: AppColors.primarySoft,
                          child: Icon(Icons.shopping_bag_outlined,
                              size: 38, color: AppColors.primary),
                        )
                      : Image.network(
                          item.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: AppColors.primarySoft,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        isArabic ? '${item.price} ج.م' : '${item.price} EGP',
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
}

class _DealsSection extends StatelessWidget {
  const _DealsSection({required this.items, required this.isArabic});

  final List<DealSummary> items;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => _Section(
        title: isArabic ? 'عروض لا تفوّتها' : 'Deals not to miss',
        subtitle: isArabic
            ? 'استفد قبل انتهاء المدة'
            : 'Claim them before they end',
        child: items.isEmpty
            ? _SectionEmpty(
                isArabic: isArabic,
                message: isArabic
                    ? 'لا توجد عروض متاحة الآن'
                    : 'No deals available now',
              )
            : SizedBox(
                height: 174,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox(
                      width: 286,
                      child: Card(
                        color: const Color(0xFFFFF6DD),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DealDetailPage(slug: item.slug),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_offer_rounded,
                                        color: Color(0xFFE08A00)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: .7),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        isArabic
                                            ? 'متبقي ${item.daysRemaining} يوم'
                                            : '${item.daysRemaining} days left',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  isArabic
                                      ? '${item.finalPrice} ج.م'
                                      : '${item.finalPrice} EGP',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
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
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.isArabic, required this.message});

  final bool isArabic;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Skeleton(height: 226, radius: 30),
          const SizedBox(height: 18),
          Row(
            children: List.generate(
              4,
              (_) => const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: _Skeleton(height: 78, radius: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          const _Skeleton(height: 20, width: 150, radius: 8),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              4,
              (_) => const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: _Skeleton(height: 86, radius: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _Skeleton(height: 20, width: 180, radius: 8),
          const SizedBox(height: 14),
          const _Skeleton(height: 150, radius: 22),
          const SizedBox(height: 12),
          const _Skeleton(height: 150, radius: 22),
        ],
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({
    required this.height,
    required this.radius,
    this.width = double.infinity,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE4E9E7),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.isArabic, required this.onRetry});

  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isArabic
                    ? 'تعذر تحميل الصفحة الرئيسية'
                    : 'Could not load the home page',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'تحقق من الاتصال ثم حاول مرة أخرى.'
                    : 'Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isArabic ? 'إعادة المحاولة' : 'Try again'),
              ),
            ],
          ),
        ),
      );
}
