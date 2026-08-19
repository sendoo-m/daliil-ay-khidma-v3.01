import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teal is the default brand preset', () {
    const preference = DalilThemePreference();
    expect(preference.preset, DalilThemePreset.teal);
    expect(preference.palette.primary, const Color(0xFF006D73));
    expect(preference.themeMode, ThemeMode.system);
  });

  test('custom theme accepts two colors and reuses secondary as accent', () {
    const preference = DalilThemePreference(
      preset: DalilThemePreset.custom,
      customColors: [Color(0xFF112233), Color(0xFF445566)],
    );
    expect(preference.palette.primary, const Color(0xFF112233));
    expect(preference.palette.secondary, const Color(0xFF445566));
    expect(preference.palette.accent, const Color(0xFF445566));
  });

  test('custom theme supports a third accent color', () {
    const preference = DalilThemePreference(
      preset: DalilThemePreset.custom,
      customColors: [
        Color(0xFF112233),
        Color(0xFF445566),
        Color(0xFF778899),
      ],
    );
    expect(preference.palette.accent, const Color(0xFF778899));
  });

  test('appearance maps to Flutter theme mode', () {
    expect(
      const DalilThemePreference(appearance: DalilAppearance.dark).themeMode,
      ThemeMode.dark,
    );
    expect(
      const DalilThemePreference(appearance: DalilAppearance.light).themeMode,
      ThemeMode.light,
    );
  });
}
