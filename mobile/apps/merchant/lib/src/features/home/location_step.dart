import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';

/// خطوة تحديد موقع النشاط.
///
/// طريقتان، والأولى هي الأدق: صاحب المحل واقف في محله، فجهازه يعرف
/// الباب بدقة أمتار. اللصق بديل لمن يجهّز نشاطه من البيت.
///
/// كلاهما ينتهي إلى `latitude/longitude` — لا إلى رابط محفوظ بلا معنى.
/// المحل بلا إحداثيات لا يظهر على الخريطة ولا في البحث بالمسافة، مهما
/// بدا مكتملًا في قائمة المهام.
class LocationStep extends ConsumerStatefulWidget {
  const LocationStep({
    super.key,
    required this.shopId,
    this.latitude,
    this.longitude,
    this.onSaved,
  });

  final int shopId;
  final double? latitude;
  final double? longitude;
  final VoidCallback? onSaved;

  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<LocationStep> {
  final _link = TextEditingController();

  double? _lat;
  double? _lng;
  bool _busy = false;
  String? _error;
  String? _done;

  bool get _hasLocation => _lat != null && _lng != null;

  @override
  void initState() {
    super.initState();
    _lat = widget.latitude;
    _lng = widget.longitude;
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  // ── الـGPS ──────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationDenied(
          'خدمة الموقع مقفولة على الجهاز. افتحها وجرّب تاني.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationDenied(
          'محتاجين إذن الموقع عشان نحدد مكان محلك.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationDenied(
          'إذن الموقع مرفوض نهائيًا. فعّله من إعدادات التطبيق، '
          'أو الزق رابط خرائط بدل كده.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // دقة أسوأ من ١٠٠ متر تعني غالبًا موقعًا من الشبكة لا القمر
      // الصناعي — ندخّلها لكن نقولها للتاجر بدل أن نتظاهر بالدقة.
      final rough = position.accuracy > 100;

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _done = rough
            ? 'أخدنا موقعك، بس الدقة ±${position.accuracy.toInt()} متر. '
                'لو مش مظبوط، جرّب برّه المحل أو الزق رابط.'
            : 'اتحدد موقعك بدقة ±${position.accuracy.toInt()} متر.';
      });
      await _save();
    } on _LocationDenied catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحديد الموقع. اتأكد إنك برّه المبنى وجرّب تاني، '
              'أو الزق رابط خرائط.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── الرابط ──────────────────────────────────────────

  Future<void> _useLink() async {
    final url = _link.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'الزق الرابط الأول.');
      return;
    }

    // نكشف المختصر هنا قبل الإرسال: الخادم سيرفضه على أي حال،
    // ورسالة فورية أسرع من رحلة ذهاب وإياب.
    final lowered = url.toLowerCase();
    if (lowered.contains('maps.app.goo.gl') || lowered.contains('goo.gl/maps')) {
      setState(() {
        _error = 'الرابط ده مختصر ومفيهوش موقع. افتحه في خرائط جوجل، '
            'وبعدين انسخ الرابط الكامل من فوق.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });

    try {
      final updated = await ref
          .read(merchantActionsProvider)
          .updateShopLocation(widget.shopId, locationUrl: url);

      final lat = (updated['latitude'] as num?)?.toDouble();
      final lng = (updated['longitude'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        setState(() {
          _error = 'مش لاقيين موقع في الرابط ده. افتح المكان في خرائط جوجل '
              'وانسخ الرابط من شريط العنوان.';
        });
        return;
      }

      setState(() {
        _lat = lat;
        _lng = lng;
        _done = 'اتحفظ الموقع من الرابط.';
      });
      widget.onSaved?.call();
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_hasLocation) return;
    try {
      await ref.read(merchantActionsProvider).updateShopLocation(
            widget.shopId,
            latitude: _lat,
            longitude: _lng,
          );
      widget.onSaved?.call();
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasLocation) _LocationCard(lat: _lat!, lng: _lng!),
        if (!_hasLocation) const _WhyItMatters(),

        const SizedBox(height: Gap.lg),
        FilledButton.icon(
          onPressed: _busy ? null : _useCurrentLocation,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.my_location, size: 19),
          label: Text(
            _hasLocation ? 'حدّث الموقع من مكاني دلوقتي' : 'أنا في المحل دلوقتي',
          ),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'أدق طريقة: افتحها وإنت واقف قدام باب المحل.',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: Gap.lg),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Text('أو', style: text.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: Gap.lg),

        TextField(
          controller: _link,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'رابط من خرائط جوجل',
            hintText: 'https://maps.google.com/...',
          ),
        ),
        const SizedBox(height: Gap.sm),
        OutlinedButton(
          onPressed: _busy ? null : _useLink,
          child: const Text('خد الموقع من الرابط'),
        ),

        if (_error != null) ...[
          const SizedBox(height: Gap.md),
          _Note(text: _error!, tone: Shop.clay),
        ],
        if (_done != null && _error == null) ...[
          const SizedBox(height: Gap.md),
          _Note(text: _done!, tone: Shop.jade),
        ],
      ],
    );
  }
}

class _LocationDenied implements Exception {
  const _LocationDenied(this.message);
  final String message;
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.jadeWash,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.jade.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.place, color: Shop.jade, size: 22),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'محلك على الخريطة',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Shop.jade),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: MerchantTheme.figure(size: 13, color: Shop.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyItMatters extends StatelessWidget {
  const _WhyItMatters();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.brassWash,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.brass.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, color: Shop.brass, size: 20),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              'من غير موقع، محلك مش هيظهر على الخريطة ولا لما حد يدوّر '
              'على أقرب مكان ليه.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(color: tone, fontSize: 13, height: 1.75),
      ),
    );
  }
}
