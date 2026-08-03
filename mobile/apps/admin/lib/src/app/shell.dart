import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/providers.dart';
import 'theme.dart';

/// عنصر قائمة مربوط بصلاحية. لا يظهر إلا لمن يملكها.
class NavDestination {
  const NavDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.permission,
  });

  final String route;
  final String label;
  final IconData icon;
  final String permission;
}

const kDestinations = <NavDestination>[
  NavDestination(
    route: '/',
    label: 'اللوحة',
    icon: Icons.dashboard_outlined,
    permission: Perm.analyticsView,
  ),
  NavDestination(
    route: '/businesses',
    label: 'الأنشطة',
    icon: Icons.storefront_outlined,
    permission: Perm.businessView,
  ),
  NavDestination(
    route: '/reviews',
    label: 'التقييمات',
    icon: Icons.rate_review_outlined,
    permission: Perm.reviewView,
  ),
  NavDestination(
    route: '/products',
    label: 'المنتجات',
    icon: Icons.inventory_2_outlined,
    permission: Perm.productView,
  ),
  NavDestination(
    route: '/deals',
    label: 'العروض',
    icon: Icons.local_offer_outlined,
    permission: Perm.dealView,
  ),
  NavDestination(
    route: '/users',
    label: 'المستخدمون',
    icon: Icons.people_outline,
    permission: Perm.userView,
  ),
  NavDestination(
    route: '/staff',
    label: 'الموظفون',
    icon: Icons.badge_outlined,
    permission: Perm.staffView,
  ),
  NavDestination(
    route: '/audit',
    label: 'سجل العمليات',
    icon: Icons.history_outlined,
    permission: Perm.auditView,
  ),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.onNavigate,
  });

  final Widget child;
  final String currentRoute;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final visible =
        kDestinations.where((d) => session.can(d.permission)).toList();
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      appBar: wide ? null : _bar(context),
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: DalilColors.ink,
              child: _NavList(
                destinations: visible,
                current: currentRoute,
                session: session,
                onNavigate: (r) {
                  Navigator.of(context).pop();
                  onNavigate(r);
                },
                onSignOut: () => ref.read(sessionProvider.notifier).signOut(),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 248,
              child: ColoredBox(
                color: DalilColors.ink,
                child: _NavList(
                  destinations: visible,
                  current: currentRoute,
                  session: session,
                  onNavigate: onNavigate,
                  onSignOut: () => ref.read(sessionProvider.notifier).signOut(),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  PreferredSizeWidget _bar(BuildContext context) {
    return AppBar(
      backgroundColor: DalilColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'دليل أي خدمة',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({
    required this.destinations,
    required this.current,
    required this.session,
    required this.onNavigate,
    required this.onSignOut,
  });

  final List<NavDestination> destinations;
  final String current;
  final AdminSession session;
  final void Function(String) onNavigate;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DalilSpacing.md,
              DalilSpacing.lg,
              DalilSpacing.md,
              DalilSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإدارة',
                  style: AdminTheme.mono(
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                    spacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'دليل أي خدمة',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white, fontSize: 17),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: DalilSpacing.sm),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: DalilSpacing.sm,
              ),
              children: [
                for (final d in destinations)
                  _NavTile(
                    destination: d,
                    active: current == d.route,
                    onTap: () => onNavigate(d.route),
                  ),
              ],
            ),
          ),

          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          Padding(
            padding: const EdgeInsets.all(DalilSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DalilRadii.control),
                  ),
                  child: Text(
                    session.user.initials,
                    style: AdminTheme.mono(size: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: DalilSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        session.role.name,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSignOut,
                  tooltip: 'خروج',
                  icon: Icon(
                    Icons.logout,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.6),
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

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final NavDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(DalilRadii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DalilRadii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DalilSpacing.sm,
              vertical: 11,
            ),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 18,
                  color: active ? Colors.white : Colors.transparent,
                ),
                const SizedBox(width: DalilSpacing.sm),
                Icon(
                  destination.icon,
                  size: 19,
                  color: Colors.white.withValues(alpha: active ? 0.95 : 0.6),
                ),
                const SizedBox(width: DalilSpacing.sm),
                Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.white.withValues(alpha: active ? 1 : 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
