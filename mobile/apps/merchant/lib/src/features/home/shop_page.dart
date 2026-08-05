import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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

  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _about.dispose();
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
