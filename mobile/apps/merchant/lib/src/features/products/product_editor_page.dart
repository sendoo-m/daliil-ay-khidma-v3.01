import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/image_field.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

/// محرّر المنتج أو الخدمة.
///
/// نفس الشاشة للإضافة والتعديل — الفرق في العنوان وزر الحذف فقط.
/// شاشتان منفصلتان لنفس الحقول تعني نسختين تفترقان مع الوقت.
class ProductEditorPage extends ConsumerStatefulWidget {
  const ProductEditorPage({super.key, this.product});

  /// `null` = إضافة جديد.
  final ProductItem? product;

  @override
  ConsumerState<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _ProductEditorPageState extends ConsumerState<ProductEditorPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _oldPrice = TextEditingController();
  final _stock = TextEditingController();
  final _deliveryCost = TextEditingController();
  final _deliveryTime = TextEditingController();

  String _type = 'product';
  bool _available = true;
  bool _hasDelivery = false;
  bool _busy = false;

  PickedImage? _image;
  double? _uploadProgress;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.nameAr;
      _description.text = p.descriptionAr;
      _price.text = _clean(p.price);
      _oldPrice.text = p.oldPrice == null ? '' : _clean(p.oldPrice!);
      _stock.text = p.stockQuantity?.toString() ?? '';
      _type = p.productType;
      _available = p.isAvailable;
      _hasDelivery = p.hasDelivery;
      _deliveryCost.text = _clean(p.deliveryCost ?? '');
      _deliveryTime.text = p.deliveryTimeAr;
    }
  }

  /// "75.00" → "75" — الكسر الصفري ضجيج في حقل إدخال.
  static String _clean(String value) {
    if (value.isEmpty) return '';
    final n = double.tryParse(value);
    if (n == null) return value;
    return n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _oldPrice.dispose();
    _stock.dispose();
    _deliveryCost.dispose();
    _deliveryTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final shop = ref.read(currentShopProvider);
    if (shop == null) return;

    setState(() => _busy = true);

    final body = <String, dynamic>{
      'business': shop.id,
      'name_ar': _name.text.trim(),
      'name_en': _name.text.trim(),
      'description_ar': _description.text.trim(),
      'description_en': _description.text.trim(),
      'product_type': _type,
      'price': _price.text.trim(),
      'old_price':
          _oldPrice.text.trim().isEmpty ? null : _oldPrice.text.trim(),
      'is_available': _available,
      'stock_quantity':
          _stock.text.trim().isEmpty ? 0 : int.parse(_stock.text.trim()),
      'has_delivery': _hasDelivery,
      'delivery_cost': _hasDelivery && _deliveryCost.text.trim().isNotEmpty
          ? _deliveryCost.text.trim()
          : '0',
      'delivery_time_ar': _hasDelivery ? _deliveryTime.text.trim() : '',
      'delivery_time_en': _hasDelivery ? _deliveryTime.text.trim() : '',
    };

    try {
      final actions = ref.read(merchantActionsProvider);

      if (_image != null) setState(() => _uploadProgress = 0);
      await actions.saveProductThenImage(
        id: _isNew ? null : widget.product!.id,
        fields: body,
        image: _image,
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNew ? 'اتضاف المنتج' : 'اتحفظت التعديلات')),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        _showFailure(failure);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
        });
      }
    }
  }

  /// أخطاء الحقول من الخادم تُعرض كما هي — أدق من رسالة عامة.
  void _showFailure(ApiFailure failure) {
    final detail = failure.fieldErrors.isNotEmpty
        ? failure.fieldErrors.entries
            .map((e) => '${_fieldLabel(e.key)}: ${e.value.first}')
            .join('\n')
        : failure.message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(detail), backgroundColor: Shop.clay),
    );
  }

  static String _fieldLabel(String key) => switch (key) {
        'name_ar' || 'name_en' => 'الاسم',
        'price' => 'السعر',
        'old_price' => 'السعر قبل الخصم',
        'description_ar' || 'description_en' => 'الوصف',
        'stock_quantity' => 'الكمية',
        'delivery_cost' => 'سعر التوصيل',
        _ => key,
      };

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Shop.surface,
        title: Text(
          'تحذف ${widget.product!.nameAr}؟',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: const Text(
          'المنتج هيختفي من صفحة محلك. مش هينفع ترجّعه.',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Shop.clay),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('احذف'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(merchantActionsProvider).deleteProduct(widget.product!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اتحذف المنتج')),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) _showFailure(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Shop.sign,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isNew ? 'منتج جديد' : 'تعديل المنتج',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            const SectionTitle('الصورة'),
            ImageField(
              label: 'ضيف صورة',
              hint: 'المنتج بصورة بيتفتح أضعاف اللي من غيرها. '
                  'صوّره في ضوء كويس ومن غير خلفية مزحومة.\n'
                  'تقدر تضيف صور تانية بعد الحفظ.',
              currentUrl: widget.product?.primaryImage,
              picked: _image,
              onPicked: (img) => setState(() => _image = img),
            ),

            const SizedBox(height: Gap.xl),
            const SectionTitle('نوعه'),
            _TypePicker(
              value: _type,
              onChanged: (v) => setState(() => _type = v),
            ),

            const SizedBox(height: Gap.xl),
            const SectionTitle('الأساسيات'),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _type == 'service' ? 'اسم الخدمة' : 'اسم المنتج',
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'اكتب اسم أطول شوية'
                  : null,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _description,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                hintText: 'إيه اللي فيه، وإيه اللي بيميّزه',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'الوصف مطلوب — بيساعد الزباين يفهموا'
                  : null,
            ),

            const SizedBox(height: Gap.xl),
            const SectionTitle('السعر'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'السعر الحالي',
                      suffixText: 'ج.م',
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null) return 'اكتب رقم';
                      if (n <= 0) return 'السعر لازم يكون أكبر من صفر';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: TextFormField(
                    controller: _oldPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'قبل الخصم',
                      suffixText: 'ج.م',
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return null;
                      final old = double.tryParse(text);
                      if (old == null) return 'اكتب رقم';
                      final now = double.tryParse(_price.text.trim());
                      if (now != null && old <= now) {
                        return 'لازم يكون أعلى من الحالي';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'سيب خانة "قبل الخصم" فاضية لو مفيش خصم. لما تملاها، '
              'السعر القديم بيظهر مشطوب جنب الجديد.',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            if (_type == 'product') ...[
              const SizedBox(height: Gap.xl),
              const SectionTitle('الكمية'),
              TextFormField(
                controller: _stock,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'الكمية المتاحة',
                  hintText: 'سيبها فاضية لو مش بتحسبها',
                ),
              ),
            ],

            const SizedBox(height: Gap.xl),
            const SectionTitle('التوصيل'),
            _SwitchRow(
              label: 'فيه توصيل للمنتج ده',
              value: _hasDelivery,
              onChanged: (v) => setState(() => _hasDelivery = v),
            ),
            if (_hasDelivery) ...[
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _deliveryCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'سعر التوصيل',
                  hintText: '0 لو مجاني',
                  suffixText: 'ج.م',
                ),
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _deliveryTime,
                decoration: const InputDecoration(
                  labelText: 'وقت التوصيل',
                  hintText: 'مثلًا: من ٣٠ لـ٤٥ دقيقة',
                ),
              ),
            ],

            const SizedBox(height: Gap.xl),
            const SectionTitle('الظهور'),
            _SwitchRow(
              label: 'متاح للزباين دلوقتي',
              value: _available,
              onChanged: (v) => setState(() => _available = v),
            ),

            const SizedBox(height: Gap.xl),
            if (_uploadProgress != null) ...[
              UploadProgress(value: _uploadProgress),
              const SizedBox(height: Gap.md),
            ],
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isNew ? 'ضيف المنتج' : 'احفظ التعديلات'),
            ),

            if (!_isNew) ...[
              const SizedBox(height: Gap.md),
              TextButton(
                onPressed: _busy ? null : _confirmDelete,
                child: const Text(
                  'احذف المنتج',
                  style: TextStyle(color: Shop.clay),
                ),
              ),
            ],
            const SizedBox(height: Gap.xl),
          ],
        ),
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.value, required this.onChanged});

  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            label: 'منتج',
            hint: 'حاجة بتتباع',
            icon: Icons.inventory_2_outlined,
            active: value == 'product',
            onTap: () => onChanged('product'),
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _TypeCard(
            label: 'خدمة',
            hint: 'شغل بتعمله',
            icon: Icons.handyman_outlined,
            active: value == 'service',
            onTap: () => onChanged('service'),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.label,
    required this.hint,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: active ? Shop.jadeWash : Shop.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: active ? Shop.jade : Shop.rule,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: active ? Shop.jade : Shop.inkFaint),
            const SizedBox(height: Gap.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: active ? Shop.jade : Shop.ink,
                  ),
            ),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.sm,
      ),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Shop.rule),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Switch(
            value: value,
            activeThumbColor: Shop.jade,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
