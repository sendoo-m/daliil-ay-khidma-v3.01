import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/theme.dart';
import 'src/features/analytics/analytics_page.dart';
import 'src/features/auth/login_page.dart';
import 'src/features/home/home_page.dart';
import 'src/features/home/shop_page.dart';
import 'src/features/notifications/notification_repository.dart';
import 'src/features/notifications/notifications_page.dart';
import 'src/features/products/deals_manager_page.dart';
import 'src/features/products/products_page.dart';
import 'src/features/reviews/reviews_page.dart';
import 'src/features/settings/settings_page.dart';
import 'src/features/subscriptions/subscription_center_page.dart';
import 'src/shared/providers.dart';
import 'src/shared/widgets.dart';

void main() {
  runApp(const ProviderScope(child: MerchantApp()));
}

class MerchantApp extends ConsumerWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(merchantLocaleProvider);
    return MaterialApp(
      title: 'Daliil Ay Khidma — Merchant',
      debugShowCheckedModeBanner: false,
      theme: MerchantTheme.build(),
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection:
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _Gate(),
    );
  }
}

class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(sessionProvider)) {
      SessionLoading() => const Scaffold(body: Loading()),
      SessionSignedOut() => const LoginPage(),
      SessionActive() => const _Shell(),
    };
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(currentShopProvider);
    final unread = ref.watch(merchantUnreadNotificationsProvider).valueOrNull ?? 0;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final titles = isArabic
        ? const ['نشاطي', 'التقييمات', 'المنتجات والعروض', 'التحليلات', 'البيانات']
        : const ['Business', 'Reviews', 'Products & deals', 'Analytics', 'Profile'];

    return Scaffold(
      appBar: _index == 0
          ? null
          : AppBar(
              backgroundColor: Shop.sign,
              foregroundColor: Colors.white,
              elevation: 0,
              titleSpacing: Gap.md,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    titles[_index],
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white, fontSize: 16),
                  ),
                  if (shop != null)
                    Text(
                      shop.nameAr,
                      style: const TextStyle(
                        color: Color(0xFF9DB5AB),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: isArabic ? 'الإعدادات' : 'Settings',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                IconButton(
                  tooltip: isArabic ? 'الاشتراك' : 'Subscription',
                  onPressed: _openSubscription,
                  icon: const Icon(Icons.workspace_premium_outlined),
                ),
                _NotificationBell(
                  unread: unread,
                  onTap: _openNotifications,
                  tooltip: isArabic ? 'الإشعارات' : 'Notifications',
                ),
                const SizedBox(width: 6),
              ],
            ),
      body: switch (_index) {
        0 => HomePage(onOpenTab: (i) => setState(() => _index = i)),
        1 => const ReviewsPage(),
        2 => const _CatalogTabs(),
        3 => const AnalyticsPage(),
        _ => const ShopPage(),
      },
      floatingActionButton: _index == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'merchant-settings',
                  tooltip: isArabic ? 'الإعدادات' : 'Settings',
                  backgroundColor: Shop.surface,
                  foregroundColor: Shop.sign,
                  onPressed: _openSettings,
                  child: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(height: Gap.sm),
                FloatingActionButton.small(
                  heroTag: 'merchant-subscription',
                  tooltip: isArabic ? 'الاشتراك' : 'Subscription',
                  backgroundColor: Shop.brass,
                  foregroundColor: Colors.white,
                  onPressed: _openSubscription,
                  child: const Icon(Icons.workspace_premium_outlined),
                ),
                const SizedBox(height: Gap.sm),
                _HomeNotificationButton(
                  unread: unread,
                  onTap: _openNotifications,
                  tooltip: isArabic ? 'الإشعارات' : 'Notifications',
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Shop.surface,
        indicatorColor: Shop.jadeWash,
        height: 66,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront, color: Shop.jade),
            label: isArabic ? 'نشاطي' : 'Business',
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outline_rounded),
            selectedIcon: const Icon(Icons.star_rounded, color: Shop.jade),
            label: isArabic ? 'التقييمات' : 'Reviews',
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2, color: Shop.jade),
            label: isArabic ? 'المنتجات' : 'Products',
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights, color: Shop.jade),
            label: isArabic ? 'التحليلات' : 'Analytics',
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune, color: Shop.jade),
            label: isArabic ? 'البيانات' : 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MerchantNotificationsPage(
          onOpenTab: (index) {
            if (mounted) setState(() => _index = index);
          },
        ),
      ),
    );
    ref.invalidate(merchantUnreadNotificationsProvider);
  }

  Future<void> _openSubscription() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionCenterPage()),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          onOpenNotifications: () {
            Navigator.of(context).pop();
            _openNotifications();
          },
          onOpenSubscription: () {
            Navigator.of(context).pop();
            _openSubscription();
          },
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.unread,
    required this.onTap,
    required this.tooltip,
  });

  final int unread;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded),
          if (unread > 0)
            PositionedDirectional(
              top: -7,
              end: -9,
              child: _UnreadBadge(count: unread),
            ),
        ],
      ),
    );
  }
}

class _HomeNotificationButton extends StatelessWidget {
  const _HomeNotificationButton({
    required this.unread,
    required this.onTap,
    required this.tooltip,
  });

  final int unread;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'merchant-notifications',
      tooltip: tooltip,
      backgroundColor: Shop.sign,
      foregroundColor: Colors.white,
      onPressed: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded),
          if (unread > 0)
            PositionedDirectional(
              top: -8,
              end: -10,
              child: _UnreadBadge(count: unread),
            ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Shop.clay,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CatalogTabs extends StatefulWidget {
  const _CatalogTabs();

  @override
  State<_CatalogTabs> createState() => _CatalogTabsState();
}

class _CatalogTabsState extends State<_CatalogTabs> {
  bool _showDeals = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          decoration: const BoxDecoration(
            color: Shop.surface,
            border: Border(bottom: BorderSide(color: Shop.rule)),
          ),
          child: Row(
            children: [
              _Tab(
                label: isArabic ? 'المنتجات' : 'Products',
                active: !_showDeals,
                onTap: () => setState(() => _showDeals = false),
              ),
              const SizedBox(width: Gap.sm),
              _Tab(
                label: isArabic ? 'العروض' : 'Deals',
                active: _showDeals,
                onTap: () => setState(() => _showDeals = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showDeals ? const DealsManagerPage() : const ProductsPage(),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? Shop.sign : Colors.transparent,
          border: Border.all(color: active ? Shop.sign : Shop.rule),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            color: active ? Colors.white : Shop.inkSoft,
          ),
        ),
      ),
    );
  }
}
