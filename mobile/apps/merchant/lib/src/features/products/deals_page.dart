import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/image_field.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

class DealsPage extends ConsumerWidget {
  const DealsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealsProvider);

    return deals.when(
      loading: () => const Loading(),
      error: (e, _) => ShopError(
        failure: ApiFailure.from(e),
        onRetry: () => ref.invalidate(dealsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return ShopEmpty(
            title: 'مفيش عروض دلوقتي',
            hint: 'العرض بيحطّ محلك في صفحة العروض، ودي من أكتر '
                'الصفحات اللي الناس بتفتحها.',
            action: FilledButton(
              onPressed: () => openDealEditor(context),
              child: const Text('اعمل أول عرض'),
            ),
          );
        }
        return RefreshIndicator(
          color: Shop.sign,
          onRefresh: () async => ref.invalidate(dealsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(Gap.md),
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == items.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  child: OutlinedButton.icon(
                    onPressed: () => openDealEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('عرض جديد'),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _DealCard(deal: items[i]),
              );
            },
          ),
        );
      },
    );
  }
}

void openDealEditor(BuildContext context, {DealItem? deal}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => DealEditorPage(deal: deal)),
  );
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal});

  final DealItem deal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, tone) = _status(deal);

    return InkWell(
      onTap: () => openDealEditor(context, deal: deal),
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Shop.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: deal.isEndingSoon
                ? Shop.brass.withValues(alpha: 0.5)
                : Shop.rule,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    deal.titleAr,
                    style: text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: tone,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                if ((deal.discountPercentage ?? 0) > 0) ...[
                  Text(
                    'خصم ${deal.discountPercentage}%',
                    style: MerchantTheme.figure(size: 15, color: Shop.brass),
                  ),
                  const SizedBox(width: Gap.md),
                ],
                if (deal.currentUses > 0)
                  Text(
                    'اتستخدم ${deal.currentUses} مرة',
                    style: text.labelSmall,
                  ),
                const Spacer(),
                const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: Shop.inkFaint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static (String, Color) _status(DealItem d) {
    if (d.isExpired) return ('خلص', Shop.inkFaint);
    if (!d.isActive) return ('موقوف', Shop.inkSoft);
    if (d.isEndingSoon) {
      final days = d.daysLeft ?? 0;
      return (days <= 0 ? 'بيخلص النهارده' : 'باقي $days أيام', Shop.brass);
    }
    if (!d.isLive) return ('لسه مابدأش', Shop.inkSoft);
    return ('شغّال', Shop.jade);
  }
}

// ═══════════════════════════════════════════════════════

class DealEditorPage extends ConsumerStatefulWidget {
  const DealEditorPage({super.key, this.deal});

  final DealItem? deal;

  @override
  ConsumerState<DealEditorPage> createState() => _DealEditorPageState();
}

class _DealEditorPageState extends ConsumerState<DealEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _discount = TextEditingController();
  final _terms = TextEditingController();

  String _type = 'percentage';
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 14));
  bool _active = true;
  bool _busy = false;
  PickedImage? _image;
  double? _uploadProgress;

  bool get _isNew => widget.deal == null;

  static const _types = {
    'percentage': 'خصم بالنسبة',
    'fixed': 'خصم بمبلغ ثابت',
    'bogo': 'اشتري واحد وخد التاني',
    'bundle': 'عرض مجمّع',
    'special': 'عرض خاص',
  };

  @override
  void initState() {
    super.initState();
    final d = widget.deal;
    if (d != null) {
      _title.text = d.titleAr;
      _description.text = d.descriptionAr;
      _discount.text = d.discountPercentage?.toString() ?? '';
      _terms.text = d.termsAr;
      _type = d.dealType;
      _active = d.isActive;
      if (d.startDate != null) _start = d.startDate!;
      if (d.endDate != null) _end = d.endDate!;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _discount.dispose();
    _terms.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // نهاية قبل البداية لا معنى لها — نصلحها فورًا بدل رفضها عند الحفظ.
        if (_end.isBefore(_start)) {
          _end = _start.add(const Duration(days: 7));
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final shop = ref.read(currentShopProvider);
    if (shop == null) return;

    setState(() => _busy = true);

    final body = <String, dynamic>{
      'business': shop.id,
      'title_ar': _title.text.trim(),
      'title_en': _title.text.trim(),
      'description_ar': _description.text.trim(),
      'description_en': _description.text.trim(),
      'deal_type': _type,
      'discount_percentage':
          _type == 'percentage' && _discount.text.trim().isNotEmpty
              ? int.parse(_discount.text.trim())
              : 0,
      'start_date': _start.toUtc().toIso8601String(),
      'end_date': _end.toUtc().toIso8601String(),
      'terms_ar': _terms.text.trim(),
      'terms_en': _terms.text.trim(),
      'is_active': _active,
    };

    try {
      final actions = ref.read(merchantActionsProvider);

      if (_image != null) {
        setState(() => _uploadProgress = 0);
        await actions.saveDealWithImage(
          id: _isNew ? null : widget.deal!.id,
          fields: body,
          image: _image!,
          onProgress: (sent, total) {
            if (mounted && total > 0) {
              setState(() => _uploadProgress = sent / total);
            }
          },
        );
      } else if (_isNew) {
        await actions.createDeal(body);
      } else {
        await actions.updateDeal(widget.deal!.id, body);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNew ? 'اتنشر العرض' : 'اتحفظ العرض')),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) _toast(failure);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
        });
      }
    }
  }

  void _toast(ApiFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure.fieldErrors.isNotEmpty
              ? failure.fieldErrors.values.first.first
              : failure.message,
        ),
        backgroundColor: Shop.clay,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Shop.surface,
        title: Text(
          'تحذف العرض؟',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: const Text(
          'هيختفي من صفحة محلك ومن صفحة العروض.',
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
      await ref.read(merchantActionsProvider).deleteDeal(widget.deal!.id);
      if (mounted) Navigator.pop(context);
    } on ApiFailure catch (failure) {
      if (mounted) _toast(failure);
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
          _isNew ? 'عرض جديد' : 'تعديل العرض',
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
            const SectionTitle('صورة العرض'),
            ImageField(
              label: 'ضيف صورة',
              hint: 'العروض بصور بتاخد مساحة أكبر في صفحة العروض.',
              currentUrl: widget.deal?.imageUrl,
              picked: _image,
              height: 150,
              onPicked: (img) => setState(() => _image = img),
            ),

            const SizedBox(height: Gap.xl),
            const SectionTitle('نوع العرض'),
            for (final entry in _types.entries)
              _TypeOption(
                label: entry.value,
                active: _type == entry.key,
                onTap: () => setState(() => _type = entry.key),
              ),

            const SizedBox(height: Gap.lg),
            const SectionTitle('التفاصيل'),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'عنوان العرض',
                hintText: 'مثلًا: خصم ٢٥٪ على كل المشروبات',
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'اكتب عنوان أوضح'
                  : null,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _description,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(labelText: 'الوصف'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'الوصف مطلوب' : null,
            ),

            if (_type == 'percentage') ...[
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _discount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'نسبة الخصم',
                  suffixText: '%',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'اكتب رقم';
                  if (n < 1 || n > 99) return 'من ١ لـ٩٩';
                  return null;
                },
              ),
            ],

            const SizedBox(height: Gap.xl),
            const SectionTitle('المدة'),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'يبدأ',
                    date: _start,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _DateField(
                    label: 'ينتهي',
                    date: _end,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xl),
            const SectionTitle('الشروط'),
            TextFormField(
              controller: _terms,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'مثلًا: العرض على الصالة بس، ومش بيتجمّع مع خصم تاني',
              ),
            ),

            const SizedBox(height: Gap.lg),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('العرض شغّال'),
              subtitle: Text(
                _active ? 'ظاهر للزباين' : 'محفوظ ومش ظاهر',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              activeThumbColor: Shop.jade,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: Gap.lg),
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
                  : Text(_isNew ? 'انشر العرض' : 'احفظ التعديلات'),
            ),
            if (!_isNew) ...[
              const SizedBox(height: Gap.md),
              TextButton(
                onPressed: _busy ? null : _confirmDelete,
                child: const Text(
                  'احذف العرض',
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Shop.surface,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: Shop.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: MerchantTheme.figure(size: 15),
            ),
          ],
        ),
      ),
    );
  }
}


/// خيار نوع العرض.
///
/// كُتب يدويًا بدل `RadioListTile` لأن الأخيرة هُجرت في Flutter 3.32
/// لصالح `RadioGroup`. الفائدة الجانبية أهم: العنصر بقى بلغة التطبيق
/// نفسها — نفس الأخضر ونفس الانحناء — بدل شكل ماتيريال الافتراضي.
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: active ? Shop.jadeWash : Shop.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: active ? Shop.jade : Shop.rule,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                active
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: active ? Shop.jade : Shop.inkFaint,
              ),
              const SizedBox(width: Gap.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: active ? Shop.jade : Shop.ink,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
