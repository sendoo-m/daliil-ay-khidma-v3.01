import 'package:flutter/widgets.dart';

/// The Daliil Ay Khidma brand mark: a teal-to-green gradient map-pin
/// with a white "D" glyph, bundled once here so every app renders the
/// exact same logo instead of a generic placeholder icon.
class DalilLogo extends StatelessWidget {
  const DalilLogo({super.key, this.size = 48});

  final double size;

  static const _asset = 'packages/dalil_core/assets/branding/logo_mark.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'دليل أي خدمة',
    );
  }
}
