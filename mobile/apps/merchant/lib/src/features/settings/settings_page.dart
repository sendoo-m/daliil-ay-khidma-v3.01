import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';

final merchantLocaleProvider = StateProvider<Locale>((_) => const Locale('ar'));
final merchantNotificationPreferenceProvider = StateProvider<bool>((_) => true);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({
    super.key,
    required this.onOpenNotifications,
    required this.onOpenSubscription,
  });

  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSubscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(merchantLocaleProvider);
    final isArabic = locale.languageCode == 'ar';
    final session = ref.watch(activeSessionProvider);
    final shop = ref.watch(currentShopProvider);
    final notifications = ref.watch(merchantNotificationPreferenceProvider);
    String tr(String ar, String en) => isArabic ? ar : en;

    return Scaffold(
      backgroundColor: Shop.paper,
      appBar: AppBar(
        backgroundColor: Shop.sign,
        foregroundColor: Colors.white,
        title: Text(tr('الإعدادات', 'Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 40),
        children: [
          _AccountCard(
            name: session.fullName,
            phone: session.phone,
            business: shop?.nameAr ?? '',
            isArabic: isArabic,
          ),
          const SizedBox(height: Gap.lg),
          _Section(
            title: tr('التطبيق', 'App'),
            children: [
              ListTile(
                leading: const _Leading(Icons.language_rounded),
                title: Text(tr('اللغة', 'Language')),
                subtitle: Text(isArabic ? 'العربية' : 'English'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('عربي')),
                    ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (value) {
                    ref.read(merchantLocaleProvider.notifier).state =
                        Locale(value.first);
                  },
                  showSelectedIcon: false,
                ),
              ),
              const Divider(),
              SwitchListTile.adaptive(
                secondary: const _Leading(Icons.notifications_active_outlined),
                title: Text(tr('تنبيهات التطبيق', 'App notifications')),
                subtitle: Text(
                  tr(
                    'تحكم في عرض التنبيهات داخل التطبيق.',
                    'Control notification prompts inside the app.',
                  ),
                ),
                value: notifications,
                onChanged: (value) => ref
                    .read(merchantNotificationPreferenceProvider.notifier)
                    .state = value,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          _Section(
            title: tr('الحساب والنشاط', 'Account & business'),
            children: [
              _ActionTile(
                icon: Icons.workspace_premium_outlined,
                title: tr('الاشتراك والخطة', 'Subscription & plan'),
                subtitle: tr('راجع خطتك الحالية والمزايا.', 'Review your current plan and benefits.'),
                onTap: onOpenSubscription,
              ),
              const Divider(),
              _ActionTile(
                icon: Icons.notifications_none_rounded,
                title: tr('مركز الإشعارات', 'Notification center'),
                subtitle: tr('كل التنبيهات والتحديثات.', 'All alerts and updates.'),
                onTap: onOpenNotifications,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          _Section(
            title: tr('المساعدة والمعلومات', 'Help & information'),
            children: [
              _ActionTile(
                icon: Icons.shield_outlined,
                title: tr('الخصوصية', 'Privacy'),
                subtitle: tr('بياناتك مرتبطة بحساب نشاطك فقط.', 'Your data is tied to your business account only.'),
                onTap: () => _showInfo(
                  context,
                  tr('الخصوصية', 'Privacy'),
                  tr(
                    'يعرض التطبيق بيانات حسابك وأنشطتك المصرح لك بإدارتها فقط. إعدادات الخصوصية المتقدمة ستظهر هنا عند توفر API مخصص لها.',
                    'The app only shows your account data and businesses you are allowed to manage. Advanced privacy controls will appear here when a dedicated API is available.',
                  ),
                ),
              ),
              const Divider(),
              _ActionTile(
                icon: Icons.info_outline_rounded,
                title: tr('عن التطبيق', 'About'),
                subtitle: 'Daliil Ay Khidma — Merchant 0.1.0',
                onTap: () => _showInfo(
                  context,
                  tr('عن التطبيق', 'About'),
                  tr(
                    'تطبيق إدارة الأنشطة لأصحاب المحلات والخدمات على دليل أي خدمة.',
                    'Business management app for merchants and service owners on Daliil Ay Khidma.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Shop.clay,
              side: const BorderSide(color: Shop.clay),
            ),
            onPressed: () => _confirmLogout(context, ref, isArabic),
            icon: const Icon(Icons.logout_rounded),
            label: Text(tr('تسجيل الخروج', 'Sign out')),
          ),
        ],
      ),
    );
  }

  static Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    bool isArabic,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'تسجيل الخروج؟' : 'Sign out?'),
        content: Text(
          isArabic
              ? 'هتحتاج تسجل دخول مرة تانية عشان تدير نشاطك.'
              : 'You will need to sign in again to manage your business.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isArabic ? 'خروج' : 'Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).signOut();
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  static void _showInfo(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: Gap.md),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.phone,
    required this.business,
    required this.isArabic,
  });

  final String name;
  final String phone;
  final String business;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Shop.sign,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: .14),
              child: const Icon(Icons.person_outline_rounded, color: Colors.white),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  if (business.isNotEmpty) Text(business, style: const TextStyle(color: Color(0xFFC8D6D0))),
                  if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Color(0xFF9DB5AB), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: Gap.sm),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Container(
            decoration: BoxDecoration(
              color: Shop.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: Shop.rule),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _Leading(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _Leading extends StatelessWidget {
  const _Leading(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Shop.jadeWash,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: Shop.jade, size: 20),
      );
}
