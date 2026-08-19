import 'package:dalil_core/dalil_core.dart' hide ApiFailure;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/locale_controller.dart';
import '../../../app/providers.dart';
import '../../../app/theme_controller.dart';
import '../data/profile_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({
    required this.profile,
    required this.isArabic,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onDeleteAccount,
    required this.onLogout,
    required this.onShowInfo,
    super.key,
  });

  final UserProfile profile;
  final bool isArabic;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  final VoidCallback onLogout;
  final void Function(String title, String message) onShowInfo;

  String _t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final notificationsEnabled = ref.watch(notificationPreferenceProvider);
    final name = '${profile.firstName} ${profile.lastName}'.trim();

    return Scaffold(
      appBar: AppBar(title: Text(_t('الإعدادات', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 26,
                child: Text(
                  (name.isEmpty ? profile.username : name).characters.first,
                ),
              ),
              title: Text(name.isEmpty ? profile.username : name),
              subtitle: Text(profile.email),
              trailing: TextButton(
                onPressed: onEditProfile,
                child: Text(_t('تعديل', 'Edit')),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(_t('الحساب', 'Account')),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(_t('البيانات الشخصية', 'Personal data')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: onEditProfile,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: Text(_t('تغيير كلمة المرور', 'Change password')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: onChangePassword,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(_t('الخصوصية', 'Privacy')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => onShowInfo(
                    _t('الخصوصية', 'Privacy'),
                    _t(
                      'تُستخدم بياناتك لتشغيل الحساب وتحسين تجربتك داخل دليل أي خدمة.',
                      'Your data is used to operate your account and improve your experience in Daliil Ay Khidma.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(_t('التطبيق', 'App')),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(_t('اللغة', 'Language')),
                  trailing: SegmentedButton<Locale>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: Locale('ar'),
                        label: Text('العربية'),
                      ),
                      ButtonSegment(
                        value: Locale('en'),
                        label: Text('English'),
                      ),
                    ],
                    selected: {locale},
                    onSelectionChanged: (value) => ref
                        .read(localeControllerProvider.notifier)
                        .setLocale(value.first),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(_t('المظهر', 'Appearance')),
                  subtitle: SegmentedButton<DalilAppearance>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: DalilAppearance.system,
                        label: Text(_t('تلقائي', 'Auto')),
                      ),
                      ButtonSegment(
                        value: DalilAppearance.light,
                        label: Text(_t('فاتح', 'Light')),
                      ),
                      ButtonSegment(
                        value: DalilAppearance.dark,
                        label: Text(_t('داكن', 'Dark')),
                      ),
                    ],
                    selected: {themePreference.appearance},
                    onSelectionChanged: (value) => ref
                        .read(themeControllerProvider.notifier)
                        .setAppearance(value.first),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none_rounded),
                  title: Text(_t('الإشعارات', 'Notifications')),
                  value: notificationsEnabled,
                  onChanged: (value) => ref
                      .read(notificationPreferenceProvider.notifier)
                      .setEnabled(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(_t('الدعم', 'Support')),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: Text(_t('اتصل بنا', 'Contact us')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => onShowInfo(
                    _t('اتصل بنا', 'Contact us'),
                    _t(
                      'يمكنك التواصل مع فريق الدعم من خلال قنوات التواصل الرسمية المتاحة في التطبيق.',
                      'Contact support through the official support channels available in the app.',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_t('الشروط والأحكام', 'Terms & conditions')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => onShowInfo(
                    _t('الشروط والأحكام', 'Terms & conditions'),
                    _t(
                      'باستخدام التطبيق فإنك توافق على الشروط والسياسات المعتمدة للخدمة.',
                      'By using the app, you agree to the approved terms and service policies.',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    _t('حذف الحساب', 'Delete account'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: onDeleteAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(_t('تسجيل الخروج', 'Sign out')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w900),
      );
}
