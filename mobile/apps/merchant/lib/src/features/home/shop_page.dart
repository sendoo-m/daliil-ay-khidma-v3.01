import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/image_field.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

/// Business Profile Editor V2.
///
/// Keeps the fields the merchant API already accepts, but presents them as a
/// guided profile editor with validation, profile health and safer save/upload
/// feedback.
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _address = TextEditingController();
  final _about = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _hours = TextEditingController();

  int? _loadedShopId;
  bool _busy = false;
  double? _uploadProgress;

  bool get _uploading => _uploadProgress != null;

  @override
  void dispose() {
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _about.dispose();
    _email.dispose();
    _website.dispose();
    _facebook.dispose();
    _instagram.dispose();
    _hours.dispose();
    super.dispose();
  }

  void _loadShop(ShopSummary shop) {
    if (_loadedShopId == shop.id) return;
    _phone.text = shop.phone;
    _whatsapp.text = shop.whatsapp;
    _address.text = shop.addressAr;
    _about.text = shop.descriptionAr;
    _email.text = shop.email;
    _website.text = shop.website;
    _facebook.text = shop.facebook;
    _instagram.text = shop.instagram;
    _hours.text = shop.workingHoursAr;
    _loadedShopId = shop.id;
  }

  void _fieldChanged(String _) => setState(() {});

  Future<void> _save(int shopId) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('راجع الحقول المعلّمة قبل الحفظ.')),
      );
      return;
    }

    if (_phone.text.trim().isEmpty && _whatsapp.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ضيف رقم تليفون أو واتساب واحد على الأقل.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(merchantActionsProvider).updateShop(shopId, {
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'address_ar': _address.text.trim(),
        'description_ar': _about.text.trim(),
        'email': _email.text.trim(),
        'website': _website.text.trim(),
        'facebook': _facebook.text.trim(),
        'instagram': _instagram.text.trim(),
        'working_hours_ar': _hours.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: Gap.sm),
              Text('اتحفظت بيانات النشاط بنجاح'),
            ],
          ),
        ),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Shop.clay,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadLogo(int shopId, PickedImage image) async {
    if (_uploading) return;
    setState(() => _uploadProgress = 0);
    try {
      await ref.read(merchantActionsProvider).uploadShopImage(
            shopId: shopId,
            field: 'logo',
            image: image,
            onProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _uploadProgress = sent / total);
              }
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: Gap.sm),
              Text('اترفع الشعار واتحدّث نشاطك'),
            ],
          ),
        ),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Shop.clay,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(currentShopProvider);
    if (shop == null) {
      return const ShopEmpty(title: 'مفيش نشاط');
    }

    _loadShop(shop);
    final health = _ProfileHealth.from(
      shop: shop,
      phone: _phone.text,
      whatsapp: _whatsapp.text,
      address: _address.text,
      about: _about.text,
      hours: _hours.text,
    );

    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 110),
        children: [
          _ProfileHeader(shop: shop, health: health),
          const SizedBox(height: Gap.lg),
          if (!shop.isVerified) ...[
            const _VerificationNotice(),
            const SizedBox(height: Gap.lg),
          ],
          _SectionCard(
            icon: Icons.photo_camera_outlined,
            title: 'هوية النشاط',
            subtitle: 'الشعار أول حاجة بتعرّف العميل عليك في نتائج البحث.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ImageField(
                  label: 'ارفع شعار النشاط',
                  hint: 'يفضل صورة مربعة وواضحة، بحد أقصى 4 ميجا.',
                  currentUrl: shop.logo,
                  height: 156,
                  onPicked: (image) {
                    if (image != null) {
                      _uploadLogo(shop.id, image);
                    }
                  },
                ),
                if (_uploadProgress != null) ...[
                  const SizedBox(height: Gap.md),
                  UploadProgress(value: _uploadProgress),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          _SectionCard(
            icon: Icons.call_outlined,
            title: 'التواصل',
            subtitle: 'خلي الوصول ليك سهل. لازم رقم تليفون أو واتساب على الأقل.',
            child: Column(
              children: [
                TextFormField(
                  controller: _phone,
                  onChanged: _fieldChanged,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _phoneValidator,
                  decoration: const InputDecoration(
                    labelText: 'رقم التليفون',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '01xxxxxxxxx',
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: _whatsapp,
                  onChanged: _fieldChanged,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _phoneValidator,
                  decoration: const InputDecoration(
                    labelText: 'واتساب',
                    prefixIcon: Icon(Icons.chat_outlined),
                    hintText: '01xxxxxxxxx',
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _emailValidator,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.mail_outline),
                    hintText: 'name@example.com',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          _SectionCard(
            icon: Icons.location_on_outlined,
            title: 'العنوان',
            subtitle: shop.placeLine.isEmpty
                ? 'اكتب العنوان بالتفصيل عشان العميل يعرف يوصل بسهولة.'
                : 'النطاق المسجل: ${shop.placeLine}',
            child: TextFormField(
              controller: _address,
              onChanged: _fieldChanged,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'العنوان التفصيلي',
                prefixIcon: Icon(Icons.map_outlined),
                hintText: 'الشارع، رقم العقار، وأقرب علامة مميزة',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          _SectionCard(
            icon: Icons.language_outlined,
            title: 'وجودك على الإنترنت',
            subtitle: 'الروابط اختيارية، لكن وجودها يزيد طرق الوصول لنشاطك.',
            child: Column(
              children: [
                TextFormField(
                  controller: _website,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: _urlValidator,
                  decoration: const InputDecoration(
                    labelText: 'الموقع الإلكتروني',
                    prefixIcon: Icon(Icons.public_outlined),
                    hintText: 'https://example.com',
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: _facebook,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: _urlValidator,
                  decoration: const InputDecoration(
                    labelText: 'فيسبوك',
                    prefixIcon: Icon(Icons.facebook_outlined),
                    hintText: 'https://facebook.com/...',
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextFormField(
                  controller: _instagram,
                  keyboardType: TextInputType.url,
                  validator: _urlValidator,
                  decoration: const InputDecoration(
                    labelText: 'إنستجرام',
                    prefixIcon: Icon(Icons.camera_alt_outlined),
                    hintText: 'https://instagram.com/...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          _SectionCard(
            icon: Icons.schedule_outlined,
            title: 'مواعيد العمل',
            subtitle: 'اكتب المواعيد بشكل واضح عشان العميل يعرف إمتى يزورك أو يكلمك.',
            child: TextFormField(
              controller: _hours,
              onChanged: _fieldChanged,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'ساعات العمل',
                alignLabelWithHint: true,
                hintText: 'مثال: السبت للخميس من 10 ص إلى 11 م — الجمعة 2 م إلى 11 م',
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          _SectionCard(
            icon: Icons.notes_outlined,
            title: 'عن النشاط',
            subtitle: 'وصف مختصر وواضح يساعد العميل يفهم خدمتك قبل ما يتواصل.',
            child: TextFormField(
              controller: _about,
              onChanged: _fieldChanged,
              maxLines: 6,
              minLines: 4,
              maxLength: 1200,
              decoration: const InputDecoration(
                labelText: 'وصف النشاط',
                alignLabelWithHint: true,
                hintText: 'اكتب أهم الخدمات أو المنتجات، خبرتك، وإيه اللي بيميز نشاطك.',
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          _ReadOnlyNotice(shop: shop),
          const SizedBox(height: Gap.lg),
          FilledButton.icon(
            onPressed: _busy || _uploading ? null : () => _save(shop.id),
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_busy ? 'بيتحفظ…' : 'احفظ كل التعديلات'),
          ),
          const SizedBox(height: Gap.lg),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => ref.read(sessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
            style: TextButton.styleFrom(foregroundColor: Shop.clay),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.shop, required this.health});

  final ShopSummary shop;
  final _ProfileHealth health;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Shop.sign,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: shop.logo == null || shop.logo!.isEmpty
                      ? const Icon(
                          Icons.storefront_outlined,
                          color: Colors.white,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            shop.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.storefront_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.nameAr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                      ),
                      if (shop.placeLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          shop.placeLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFBFD1CA),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  shop.isVerified
                      ? Icons.verified_rounded
                      : Icons.pending_outlined,
                  color: shop.isVerified ? Shop.jade : Shop.brass,
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'اكتمال الملف',
                    style: TextStyle(
                      color: Color(0xFFBFD1CA),
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Text(
                  '${health.percent}%',
                  style: MerchantTheme.figure(size: 22, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: health.percent / 100,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                color: health.isComplete ? Shop.jade : Shop.brass,
              ),
            ),
            if (!health.isComplete) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'كمّل ${health.missingCount} عناصر أساسية عشان صفحة نشاطك تظهر أقوى.',
                style: const TextStyle(
                  color: Color(0xFFDFE8E4),
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      );
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.brassWash,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: Shop.brass.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.fact_check_outlined, color: Shop.brass),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نشاطك قيد المراجعة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'كمّل البيانات الأساسية وخليها دقيقة عشان تساعد فريق المراجعة على التوثيق أسرع.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: Shop.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Shop.jadeWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Shop.jade, size: 21),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            child,
          ],
        ),
      );
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.shop});

  final ShopSummary shop;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.paper,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: Shop.rule),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, color: Shop.inkSoft),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'الاسم والتصنيف والمحافظة وحالة التوثيق بيانات محمية. '
                'لو محتاج تعديلها تواصل مع الدعم. التصنيف الحالي: '
                '${shop.categoryName.isEmpty ? 'غير محدد' : shop.categoryName}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
}

class _ProfileHealth {
  const _ProfileHealth({required this.percent, required this.missingCount});

  final int percent;
  final int missingCount;

  bool get isComplete => missingCount == 0;

  factory _ProfileHealth.from({
    required ShopSummary shop,
    required String phone,
    required String whatsapp,
    required String address,
    required String about,
    required String hours,
  }) {
    final checks = <bool>[
      shop.logo != null && shop.logo!.isNotEmpty,
      shop.categoryName.trim().isNotEmpty,
      shop.cityName.trim().isNotEmpty,
      address.trim().isNotEmpty,
      about.trim().isNotEmpty,
      phone.trim().isNotEmpty || whatsapp.trim().isNotEmpty,
      hours.trim().isNotEmpty,
    ];
    final complete = checks.where((value) => value).length;
    return _ProfileHealth(
      percent: ((complete / checks.length) * 100).round(),
      missingCount: checks.length - complete,
    );
  }
}

String? _phoneValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final normalized = text.replaceAll(RegExp(r'[\s\-()+]'), '');
  if (!RegExp(r'^\d{8,15}$').hasMatch(normalized)) {
    return 'اكتب رقم صحيح من 8 إلى 15 رقم.';
  }
  return null;
}

String? _emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
    return 'اكتب بريد إلكتروني صحيح.';
  }
  return null;
}

String? _urlValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return 'الرابط لازم يبدأ بـ http:// أو https://';
  }
  return null;
}
