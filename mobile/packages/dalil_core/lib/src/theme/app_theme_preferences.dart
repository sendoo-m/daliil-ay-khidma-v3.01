import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum DalilThemePreset { teal, blue, red, purple, sunset, custom }

enum DalilAppearance { system, light, dark }

@immutable
class DalilThemePreference {
  const DalilThemePreference({
    this.preset = DalilThemePreset.teal,
    this.appearance = DalilAppearance.system,
    this.customColors = const [],
  });

  final DalilThemePreset preset;
  final DalilAppearance appearance;

  /// Two or three user-selected colors when [preset] is custom.
  final List<Color> customColors;

  ThemeMode get themeMode => switch (appearance) {
        DalilAppearance.light => ThemeMode.light,
        DalilAppearance.dark => ThemeMode.dark,
        DalilAppearance.system => ThemeMode.system,
      };

  DalilThemePalette get palette {
    if (preset == DalilThemePreset.custom && customColors.length >= 2) {
      return DalilThemePalette(
        primary: customColors[0],
        secondary: customColors[1],
        accent: customColors.length > 2 ? customColors[2] : customColors[1],
      );
    }
    return DalilThemePalette.forPreset(preset);
  }

  DalilThemePreference copyWith({
    DalilThemePreset? preset,
    DalilAppearance? appearance,
    List<Color>? customColors,
  }) =>
      DalilThemePreference(
        preset: preset ?? this.preset,
        appearance: appearance ?? this.appearance,
        customColors: customColors ?? this.customColors,
      );
}

@immutable
class DalilThemePalette {
  const DalilThemePalette({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;

  List<Color> get gradientColors => [primary, secondary, accent];

  LinearGradient get gradient => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      );

  static DalilThemePalette forPreset(DalilThemePreset preset) => switch (preset) {
        DalilThemePreset.teal => const DalilThemePalette(
            primary: Color(0xFF006D73),
            secondary: Color(0xFF009688),
            accent: Color(0xFF00B878),
          ),
        DalilThemePreset.blue => const DalilThemePalette(
            primary: Color(0xFF155EEF),
            secondary: Color(0xFF2563EB),
            accent: Color(0xFF38BDF8),
          ),
        DalilThemePreset.red => const DalilThemePalette(
            primary: Color(0xFFB42318),
            secondary: Color(0xFFDC2626),
            accent: Color(0xFFF97316),
          ),
        DalilThemePreset.purple => const DalilThemePalette(
            primary: Color(0xFF6941C6),
            secondary: Color(0xFF7C3AED),
            accent: Color(0xFFDB2777),
          ),
        DalilThemePreset.sunset => const DalilThemePalette(
            primary: Color(0xFF7C3AED),
            secondary: Color(0xFFDB2777),
            accent: Color(0xFFF97316),
          ),
        DalilThemePreset.custom => const DalilThemePalette(
            primary: Color(0xFF006D73),
            secondary: Color(0xFF009688),
            accent: Color(0xFF00B878),
          ),
      };
}

class DalilThemePreferenceStore {
  DalilThemePreferenceStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _presetKey = 'ui.theme.preset';
  static const _appearanceKey = 'ui.theme.appearance';
  static const _colorsKey = 'ui.theme.custom_colors';

  Future<DalilThemePreference> read() async {
    final presetName = await _storage.read(key: _presetKey);
    final appearanceName = await _storage.read(key: _appearanceKey);
    final colorsValue = await _storage.read(key: _colorsKey);
    return DalilThemePreference(
      preset: DalilThemePreset.values.firstWhere(
        (value) => value.name == presetName,
        orElse: () => DalilThemePreset.teal,
      ),
      appearance: DalilAppearance.values.firstWhere(
        (value) => value.name == appearanceName,
        orElse: () => DalilAppearance.system,
      ),
      customColors: _decodeColors(colorsValue),
    );
  }

  Future<void> write(DalilThemePreference preference) async {
    await Future.wait([
      _storage.write(key: _presetKey, value: preference.preset.name),
      _storage.write(key: _appearanceKey, value: preference.appearance.name),
      _storage.write(
        key: _colorsKey,
        value: preference.customColors.map((c) => c.toARGB32().toRadixString(16)).join(','),
      ),
    ]);
  }

  List<Color> _decodeColors(String? value) {
    if (value == null || value.isEmpty) return const [];
    return value.split(',').map((hex) => Color(int.parse(hex, radix: 16))).take(3).toList();
  }
}
