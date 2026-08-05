import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/image_field.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

/// بيانات النشاط — التاجر يعدّل ما يخصه.
///
/// ما هو غائب من هنا مقصود ويطابق الخادم: التوثيق والتمييز والتصنيف
/// والمحافظة. لو ظهر حقل هنا والخادم يرفضه، بنينا زرًا يفشل.
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _address = TextEditingController();
  final _about = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _hours = TextEditingController();

  bool _loaded = false;
  bool _busy = false;
  double? _uploadProgress;

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

  Future<void> _save(int shopId) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اتحفظت البيانات')),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message), backgroundColor: Shop.clay),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// الشعار يُرفع فور اختياره لا عند الحفظ — تغيير صورة فعل مستقل،
  /// وانتظاره مع بقية الحقول يجعل التاجر يشك أنه لم يُحفظ.
  Future<void> _uploadLogo(int shopId, PickedImage image) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اترفع الشعار')),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message), backgroundColor: Shop.clay),
        );
      }
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

    if (!_loaded) {
      _phone.text = shop.phone;
      _whatsapp.text = shop.whatsapp;
      _address.text = shop.addressAr;
      _about.text = shop.descriptionAr;
      _email.text = shop.email;
      _website.text = shop.website;
      _facebook.text = shop.facebook;
      _instagram.text = shop.instagram;
      _hours.text = shop.workingHoursAr;
      _loaded = true;
    }

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        if (!shop.isVerified) ...[
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: Shop.brassWash,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: Shop.brass.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 20, color: Shop.brass),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'نشاطك مستني التوثيق. كمّل بياناتك عشان المراجعة تعدّي أسرع.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
        ],

        const SectionTitle('شعار المحل'),
        ImageField(
          label: 'ارفع الشعار',
          hint: 'الشعار بيظهر جنب اسم محلك في نتايج البحث.',
          currentUrl: shop.logo,
          height: 140,
          onPicked: (img) {
            if (img != null) _uploadLogo(shop.id, img);
          },
        ),
        if (_uploadProgress != null) ...[
          const SizedBox(height: Gap.md),
          UploadProgress(value: _uploadProgress),
        ],

        const SizedBox(height: Gap.xl),
        const SectionTitle('التواصل'),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم التليفون'),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'واتساب'),
        ),

        const SizedBox(height: Gap.xl),
        const SectionTitle('العنوان'),
        TextField(
          controller: _address,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'الشارع والعلامة المميزة',
          ),
        ),

        const SizedBox(height: Gap.md),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
        ),

        const SizedBox(height: Gap.xl),
        const SectionTitle('على النت'),
        TextField(
          controller: _website,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'الموقع',
            hintText: 'https://',
          ),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _facebook,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'فيسبوك'),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _instagram,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'إنستجرام'),
        ),

        const SizedBox(height: Gap.xl),
        const SectionTitle('المواعيد'),
        TextField(
          controller: _hours,
          maxLines: 3,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'مثلًا: من ١٠ صباحًا لـ١٢ بالليل — الجمعة إجازة\n'
                'أو: فاتح ٢٤ ساعة',
          ),
        ),

        const SizedBox(height: Gap.xl),
        const SectionTitle('عن النشاط'),
        TextField(
          controller: _about,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'إيه اللي بتقدّمه، وإيه اللي بيميّزك',
          ),
        ),

        const SizedBox(height: Gap.xl),
        FilledButton(
          onPressed: _busy ? null : () => _save(shop.id),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('احفظ التعديلات'),
        ),

        const SizedBox(height: Gap.lg),
        Text(
          'الاسم والتصنيف والتوثيق بيتغيّروا من خلال الدعم، مش من هنا.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.lg),
        TextButton(
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          child: const Text(
            'خروج',
            style: TextStyle(color: Shop.clay),
          ),
        ),
      ],
    );
  }
}
