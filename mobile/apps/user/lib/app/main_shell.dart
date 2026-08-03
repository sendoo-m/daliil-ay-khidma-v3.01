import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/catalog/presentation/my_deal_claims_page.dart';
import '../features/directory/presentation/favorites_page.dart';
import '../features/directory/presentation/search_page.dart';
import '../features/home/presentation/home_page_v4.dart';
import '../features/location/presentation/map_discovery_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/subscriptions/presentation/subscription_plans_page.dart';
import 'app_theme.dart';
import 'providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  int _favoritesRevision = 0;

  bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic(context);
    final isAuthenticated =
        ref.watch(authControllerProvider).valueOrNull ?? false;
    final pages = <Widget>[
      HomePageV4(onSearchTap: () => setState(() => _index = 1)),
      const SearchPage(embedded: true),
      const MapDiscoveryPage(),
      const SubscriptionPlansPage(),
      isAuthenticated
          ? FavoritesPage(
              key: ValueKey('favorites-$_favoritesRevision'),
              embedded: true,
            )
          : _GuestGate(
              icon: Icons.favorite_rounded,
              eyebrow: isArabic ? 'مفضّلتك في مكان واحد' : 'All your favorites',
              title: isArabic ? 'احفظ الأماكن التي تعجبك' : 'Save places you like',
              description: isArabic
                  ? 'سجّل دخولك لحفظ المحلات والخدمات والعودة إليها بسرعة في أي وقت.'
                  : 'Sign in to save businesses and services and return to them anytime.',
              isArabic: isArabic,
            ),
      isAuthenticated
          ? const MyDealClaimsPage()
          : _GuestGate(
              icon: Icons.confirmation_number_rounded,
              eyebrow: isArabic ? 'حجوزاتك محفوظة' : 'Your claims in one place',
              title: isArabic ? 'تابع العروض التي حجزتها' : 'Track your claimed deals',
              description: isArabic
                  ? 'سجّل دخولك لعرض أرقام المطالبات وحالة كل عرض حجزته.'
                  : 'Sign in to see claim numbers and the status of every deal you booked.',
              isArabic: isArabic,
            ),
      isAuthenticated
          ? const ProfilePage(embedded: true)
          : _GuestGate(
              icon: Icons.person_rounded,
              eyebrow: isArabic ? 'تجربة مخصّصة لك' : 'A personalized experience',
              title: isArabic ? 'مرحبًا بك في دليل أي خدمة' : 'Welcome to Daliil Ay Khidma',
              description: isArabic
                  ? 'أنشئ حسابًا لإدارة المفضلة والتقييمات والإشعارات بسهولة.'
                  : 'Create an account to manage favorites, reviews and notifications.',
              isArabic: isArabic,
            ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .07),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() {
              _index = value;
              if (value == 4) _favoritesRevision++;
            }),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: isArabic ? 'الرئيسية' : 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_rounded),
                selectedIcon: const Icon(Icons.manage_search_rounded),
                label: isArabic ? 'البحث' : 'Search',
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map_rounded),
                label: isArabic ? 'الخريطة' : 'Map',
              ),
              NavigationDestination(
                icon: const Icon(Icons.workspace_premium_outlined),
                selectedIcon: const Icon(Icons.workspace_premium_rounded),
                label: isArabic ? 'الاشتراك' : 'Plans',
              ),
              NavigationDestination(
                icon: const Icon(Icons.favorite_outline_rounded),
                selectedIcon: const Icon(Icons.favorite_rounded),
                label: isArabic ? 'المفضلة' : 'Favorites',
              ),
              NavigationDestination(
                icon: const Icon(Icons.confirmation_number_outlined),
                selectedIcon: const Icon(Icons.confirmation_number_rounded),
                label: isArabic ? 'عروضي' : 'Claims',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: isArabic ? 'حسابي' : 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestGate extends StatelessWidget {
  const _GuestGate({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.isArabic,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 42, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    eyebrow,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.login_rounded),
                      label: Text(
                        isArabic
                            ? 'تسجيل الدخول أو إنشاء حساب'
                            : 'Sign in or create an account',
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
