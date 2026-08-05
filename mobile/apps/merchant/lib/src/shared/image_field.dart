import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme.dart';

/// صورة مختارة، جاهزة للرفع.
class PickedImage {
  const PickedImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  double get megabytes => bytes.length / (1024 * 1024);
}

/// حقل اختيار صورة مع معاينة.
///
/// يعرض الصورة الحالية من الخادم لو موجودة، ويستبدلها بالمعاينة فور
/// الاختيار — التاجر يشوف اللي هيتحفظ قبل ما يضغط حفظ.
///
/// الضغط على الجودة عند الالتقاط مقصود: صور موبايلات اليوم تتعدى
/// ٨ ميجابايت، والخادم بيرفض فوق ٤. الضغط هنا أرحم من رسالة رفض بعد
/// انتظار رفع طويل على شبكة ضعيفة.
class ImageField extends StatefulWidget {
  const ImageField({
    super.key,
    required this.label,
    required this.onPicked,
    this.currentUrl,
    this.picked,
    this.height = 170,
    this.hint,
  });

  final String label;
  final String? hint;

  /// رابط الصورة الحالية من الخادم.
  final String? currentUrl;

  /// الصورة المختارة محليًا ولسه ماترفعتش.
  final PickedImage? picked;

  final void Function(PickedImage?) onPicked;
  final double height;

  @override
  State<ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<ImageField> {
  bool _picking = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _picking = true;
      _error = null;
    });

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final image = PickedImage(bytes: bytes, filename: file.name);

      // حتى بعد الضغط قد تتجاوز صورة عالية الدقة الحد.
      if (image.megabytes > 4) {
        setState(() {
          _error = 'الصورة لسه كبيرة (${image.megabytes.toStringAsFixed(1)} '
              'ميجا). اختار صورة أصغر.';
        });
        return;
      }

      widget.onPicked(image);
    } catch (_) {
      setState(() => _error = 'تعذّر فتح الصورة. جرّب تاني.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Shop.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.sm),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Shop.sign),
              title: const Text('من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Shop.sign),
              title: const Text('صوّر دلوقتي'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            if (widget.picked != null || widget.currentUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Shop.clay),
                title: const Text(
                  'شيل الصورة',
                  style: TextStyle(color: Shop.clay),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPicked(null);
                },
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.picked != null ||
        (widget.currentUrl != null && widget.currentUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _picking ? null : _showSourceSheet,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            height: widget.height,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Shop.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: hasImage ? Shop.rule : Shop.jade.withValues(alpha: 0.4),
                width: hasImage ? 1 : 1.5,
              ),
            ),
            child: _picking
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Shop.sign,
                      ),
                    ),
                  )
                : hasImage
                    ? _preview()
                    : _placeholder(context),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Gap.sm),
          Text(
            _error!,
            style: const TextStyle(color: Shop.clay, fontSize: 12.5),
          ),
        ],
        if (widget.hint != null && _error == null) ...[
          const SizedBox(height: Gap.sm),
          Text(widget.hint!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _preview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.picked != null)
          Image.memory(widget.picked!.bytes, fit: BoxFit.cover)
        else
          Image.network(
            widget.currentUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Shop.paper,
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Shop.inkFaint),
              ),
            ),
          ),
        Positioned(
          bottom: Gap.sm,
          left: Gap.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Shop.sign.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit, size: 13, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  widget.picked != null ? 'هتترفع عند الحفظ' : 'غيّر',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_a_photo_outlined, size: 26, color: Shop.jade),
        const SizedBox(height: Gap.sm),
        Text(
          widget.label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Shop.jade),
        ),
      ],
    );
  }
}

/// شريط تقدم الرفع. يظهر أثناء إرسال الصورة فقط.
class UploadProgress extends StatelessWidget {
  const UploadProgress({super.key, required this.value});

  /// من 0 إلى 1، أو `null` لو الحجم غير معروف.
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Shop.rule,
            color: Shop.jade,
          ),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          value == null
              ? 'بيرفع الصورة…'
              : 'بيرفع الصورة… ${(value! * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
