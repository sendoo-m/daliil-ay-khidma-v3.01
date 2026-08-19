import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../directory/presentation/business_detail_page.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../data/activity_repository.dart';
import '../data/profile_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(profileRepositoryProvider).get();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = ApiFailure.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: Text(_t('حسابي', 'My profile')),
          actions: [
            IconButton(
              tooltip: _t('الإشعارات', 'Notifications'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsPage(),
                ),
              ),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        body: _body(),
      );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _profile == null) {
      return _MessageState(
        icon: Icons.person_off_outlined,
        title: _t('تعذر تحميل الحساب', 'Could not load profile'),
        message: _error ?? _t('حدث خطأ غير متوقع', 'An unexpected error occurred'),
        actionLabel: _t('إعادة المحاولة', 'Try again'),
        onAction: _load,
      );
    }

    final profile = _profile!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _ProfileHero(profile: profile, isArabic: _isArabic),
          const SizedBox(height: 16),
          _StatsRow(stats: profile.stats, isArabic: _isArabic),
          const SizedBox(height: 20),
          _SectionTitle(_t('أنشطتي الأخيرة', 'My recent activity')),
          const SizedBox(height: 10),
          _RecentActivityCard(isArabic: _isArabic),
          const SizedBox(height: 20),
          _SectionTitle(_t('تقييماتي', 'My reviews')),
          const SizedBox(height: 10),
          _MyReviewsCard(isArabic: _isArabic),
          const SizedBox(height: 20),
          _QuickActions(
            isArabic: _isArabic,
            onEdit: () => _openEdit(profile),
            onPassword: _changePassword,
            onNotifications: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(_t('بيانات الحساب', 'Account details')),
          const SizedBox(height: 10),
          _DetailsCard(profile: profile, isArabic: _isArabic),
          const SizedBox(height: 20),
          _SectionTitle(_t('الدعم والمعلومات', 'Support & information')),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: _t('مركز المساعدة', 'Help center'),
                onTap: () => _showInfo(
                  _t('مركز المساعدة', 'Help center'),
                  _t(
                    'يمكنك التواصل مع فريق الدعم من خلال قنوات التواصل الرسمية المتاحة في التطبيق.',
                    'Contact support through the official support channels available in the app.',
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: _t('الخصوصية', 'Privacy'),
                onTap: () => _showInfo(
                  _t('الخصوصية', 'Privacy'),
                  _t(
                    'تُستخدم بياناتك لتشغيل الحساب وتحسين تجربتك داخل دليل أي خدمة.',
                    'Your data is used to operate your account and improve your experience in Daliil Ay Khidma.',
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: _t('الشروط والأحكام', 'Terms & conditions'),
                onTap: () => _showInfo(
                  _t('الشروط والأحكام', 'Terms & conditions'),
                  _t(
                    'باستخدام التطبيق فإنك توافق على الشروط والسياسات المعتمدة للخدمة.',
                    'By using the app, you agree to the approved terms and service policies.',
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: _t('حذف الحساب', 'Delete account'),
                onTap: _startAccountDeletion,
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _confirmLogout,
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

  Future<void> _openEdit(UserProfile profile) async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute<UserProfile>(
        builder: (_) => _EditProfilePage(profile: profile),
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmation = TextEditingController();
    var submitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('تغيير كلمة المرور', 'Change password')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPassword,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _t('كلمة المرور الحالية', 'Current password'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassword,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _t('كلمة المرور الجديدة', 'New password'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _t('تأكيد كلمة المرور', 'Confirm password'),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: Text(_t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (newPassword.text.length < 8) {
                        setDialogState(() => errorMessage = _t(
                              'كلمة المرور يجب ألا تقل عن 8 أحرف',
                              'Password must be at least 8 characters',
                            ));
                        return;
                      }
                      if (newPassword.text != confirmation.text) {
                        setDialogState(() => errorMessage = _t(
                              'كلمتا المرور غير متطابقتين',
                              'Passwords do not match',
                            ));
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorMessage = null;
                      });
                      try {
                        await ref.read(profileRepositoryProvider).changePassword(
                              oldPassword: oldPassword.text,
                              newPassword: newPassword.text,
                            );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(_t(
                                'تم تغيير كلمة المرور بنجاح',
                                'Password changed successfully',
                              )),
                            ),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            submitting = false;
                            errorMessage = ApiFailure.message(error);
                          });
                        }
                      }
                    },
              child: Text(submitting ? _t('جارٍ التغيير...', 'Changing...') : _t('تغيير', 'Change')),
            ),
          ],
        ),
      ),
    );
    oldPassword.dispose();
    newPassword.dispose();
    confirmation.dispose();
  }

  Future<void> _startAccountDeletion() async {
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(_t('حذف الحساب؟', 'Delete account?')),
        content: Text(_t(
          'سيتم تعطيل حسابك فورًا بعد إرسال الطلب ولن تتمكن من تسجيل الدخول أثناء معالجة الحذف.',
          'Your account will be disabled immediately after submitting the request and you will not be able to sign in while deletion is processed.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('متابعة', 'Continue')),
          ),
        ],
      ),
    );
    if (firstConfirmed != true || !mounted) return;

    final password = TextEditingController();
    final reason = TextEditingController();
    var submitting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('التأكيد النهائي', 'Final confirmation')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_t(
                  'أدخل كلمة المرور الحالية للتأكد من هويتك. سبب الحذف اختياري.',
                  'Enter your current password to verify your identity. The reason is optional.',
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _t('كلمة المرور الحالية', 'Current password'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: _t('سبب الحذف (اختياري)', 'Reason (optional)'),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: Text(_t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
              onPressed: submitting
                  ? null
                  : () async {
                      if (password.text.isEmpty) {
                        setDialogState(() {
                          errorMessage = _t('أدخل كلمة المرور الحالية.', 'Enter your current password.');
                        });
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorMessage = null;
                      });
                      try {
                        await ref.read(authControllerProvider.notifier).requestAccountDeletion(
                              password: password.text,
                              reason: reason.text,
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            submitting = false;
                            errorMessage = ApiFailure.message(error);
                          });
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_t('إرسال طلب الحذف', 'Submit deletion request')),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    reason.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('تسجيل الخروج؟', 'Sign out?')),
        content: Text(_t(
          'يمكنك تسجيل الدخول إلى حسابك مرة أخرى في أي وقت.',
          'You can sign in to your account again at any time.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('تسجيل الخروج', 'Sign out')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  Future<void> _showInfo(String title, String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('تم', 'Done')),
            ),
          ],
        ),
      );
}

class _EditProfilePage extends ConsumerStatefulWidget {
  const _EditProfilePage({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<_EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _bio;
  bool _saving = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.profile.firstName);
    _lastName = TextEditingController(text: widget.profile.lastName);
    _email = TextEditingController(text: widget.profile.email);
    _phone = TextEditingController(text: widget.profile.phone);
    _city = TextEditingController(text: widget.profile.city);
    _bio = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    for (final controller in [_firstName, _lastName, _email, _phone, _city, _bio]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_t('تعديل الملف الشخصي', 'Edit profile'))),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(child: _field(_firstName, _t('الاسم الأول', 'First name'))),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_lastName, _t('اسم العائلة', 'Last name'))),
                ],
              ),
              _field(
                _email,
                _t('البريد الإلكتروني', 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return _t('أدخل بريدًا صحيحًا', 'Enter a valid email');
                  }
                  return null;
                },
              ),
              _field(
                _phone,
                _t('رقم الهاتف', 'Phone number'),
                keyboardType: TextInputType.phone,
              ),
              _field(_city, _t('المدينة', 'City')),
              _field(
                _bio,
                _t('نبذة عنك', 'About you'),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? _t('جارٍ الحفظ...', 'Saving...') : _t('حفظ التعديلات', 'Save changes')),
              ),
            ],
          ),
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final profile = await ref.read(profileRepositoryProvider).update(
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            phone: _phone.text,
            bio: _bio.text,
            city: _city.text,
          );
      if (mounted) Navigator.pop(context, profile);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.message(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.isArabic});
  final UserProfile profile;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = '${profile.firstName} ${profile.lastName}'.trim();
    final initials = [
      if (profile.firstName.isNotEmpty) profile.firstName.characters.first,
      if (profile.lastName.isNotEmpty) profile.lastName.characters.first,
    ].join();
    final uri = Uri.tryParse(profile.profilePicture ?? '');
    final image = uri != null && uri.hasScheme ? NetworkImage(uri.toString()) : null;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: colors.surface,
            foregroundImage: image,
            child: image == null
                ? Text(
                    initials.isEmpty ? profile.username.characters.first : initials,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? profile.username : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text('@${profile.username}', style: const TextStyle(color: Colors.white70)),
                if (profile.dateJoined != null)
                  Text(
                    '${isArabic ? 'عضو منذ' : 'Member since'} ${DateFormat('MMMM yyyy', isArabic ? 'ar' : 'en').format(profile.dateJoined!.toLocal())}',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          Icon(
            profile.emailVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.isArabic});
  final UserProfileStats stats;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _StatTile(
              value: stats.claimedDealsCount,
              label: isArabic ? 'عروض محفوظة' : 'Claimed deals',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              value: stats.reviewsCount,
              label: isArabic ? 'تقييمات' : 'Reviews',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              value: stats.favoritesCount,
              label: isArabic ? 'محل مفضل' : 'Favorites',
            ),
          ),
        ],
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _RecentActivityCard extends ConsumerWidget {
  const _RecentActivityCard({required this.isArabic});
  final bool isArabic;

  String _label(ActivityEntry entry) => switch (entry.type) {
        ActivityType.review => isArabic
            ? 'قيّمت ${entry.businessName}'
            : 'You reviewed ${entry.businessName}',
        ActivityType.favorite => isArabic
            ? 'أضفت ${entry.businessName} للمفضلة'
            : 'You favorited ${entry.businessName}',
        ActivityType.dealClaim => isArabic
            ? 'استخدمت عرض ${entry.dealTitle ?? ''} من ${entry.businessName}'
            : 'You claimed ${entry.dealTitle ?? ''} from ${entry.businessName}',
      };

  IconData _icon(ActivityType type) => switch (type) {
        ActivityType.review => Icons.star_rounded,
        ActivityType.favorite => Icons.favorite_rounded,
        ActivityType.dealClaim => Icons.local_offer_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(recentActivityProvider);
    return activity.when(
      loading: () => const _CardLoading(),
      error: (_, __) => _CardEmpty(
        message: isArabic ? 'تعذر تحميل الأنشطة' : 'Could not load activity',
      ),
      data: (items) {
        if (items.isEmpty) {
          return _CardEmpty(
            message: isArabic ? 'لا توجد أنشطة بعد' : 'No activity yet',
          );
        }
        final shown = items.take(5).toList(growable: false);
        return Card(
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++)
                ListTile(
                  onTap: shown[i].businessSlug.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BusinessDetailPage(
                                slug: shown[i].businessSlug,
                              ),
                            ),
                          ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    foregroundImage: shown[i].businessLogo == null
                        ? null
                        : NetworkImage(shown[i].businessLogo!),
                    child: Icon(
                      _icon(shown[i].type),
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  title: Text(_label(shown[i]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    DateFormat('d MMMM yyyy', isArabic ? 'ar' : 'en')
                        .format(shown[i].createdAt.toLocal()),
                  ),
                  trailing: shown[i].businessSlug.isEmpty
                      ? null
                      : const Icon(Icons.chevron_left_rounded),
                  dense: true,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MyReviewsCard extends ConsumerWidget {
  const _MyReviewsCard({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(myReviewsProvider);
    return reviews.when(
      loading: () => const _CardLoading(),
      error: (_, __) => _CardEmpty(
        message: isArabic ? 'تعذر تحميل التقييمات' : 'Could not load reviews',
      ),
      data: (items) {
        if (items.isEmpty) {
          return _CardEmpty(
            message:
                isArabic ? 'لم تكتب أي تقييم بعد' : 'You have not written any reviews yet',
          );
        }
        return Column(
          children: [
            for (final review in items.take(5))
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: review.businessSlug.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  BusinessDetailPage(slug: review.businessSlug),
                            ),
                          ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    foregroundImage: review.businessLogo == null
                        ? null
                        : NetworkImage(review.businessLogo!),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    review.businessName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 15,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                      if (review.comment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          review.comment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (!review.isApproved) ...[
                        const SizedBox(height: 4),
                        Text(
                          isArabic
                              ? 'بانتظار المراجعة'
                              : 'Pending moderation',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
}

class _CardEmpty extends StatelessWidget {
  const _CardEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isArabic,
    required this.onEdit,
    required this.onPassword,
    required this.onNotifications,
  });
  final bool isArabic;
  final VoidCallback onEdit;
  final VoidCallback onPassword;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _QuickAction(icon: Icons.edit_outlined, label: isArabic ? 'تعديل' : 'Edit', onTap: onEdit)),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: Icons.lock_reset_rounded, label: isArabic ? 'كلمة المرور' : 'Password', onTap: onPassword)),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: Icons.notifications_none_rounded, label: isArabic ? 'الإشعارات' : 'Alerts', onTap: onNotifications)),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.profile, required this.isArabic});
  final UserProfile profile;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            _DetailRow(icon: Icons.email_outlined, label: isArabic ? 'البريد الإلكتروني' : 'Email', value: profile.email),
            _DetailRow(icon: Icons.phone_outlined, label: isArabic ? 'رقم الهاتف' : 'Phone', value: profile.phone),
            _DetailRow(icon: Icons.location_city_outlined, label: isArabic ? 'المدينة' : 'City', value: profile.city),
            if (profile.bio.isNotEmpty)
              _DetailRow(icon: Icons.notes_rounded, label: isArabic ? 'نبذة' : 'Bio', value: profile.bio, last: true),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value, this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(label),
            subtitle: Text(value.isEmpty ? '—' : value),
          ),
          if (!last) const Divider(height: 1),
        ],
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(child: Column(children: children));
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh), label: Text(actionLabel)),
            ],
          ),
        ),
      );
}
