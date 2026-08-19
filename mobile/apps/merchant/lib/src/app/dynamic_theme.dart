import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Bridges the existing merchant design system to the shared dynamic palette.
/// Screen-level Shop.* constants are intentionally migrated in the Merchant UI
/// refresh; global Material controls become theme-aware now.
abstract final class MerchantDynamicTheme {
  static ThemeData build(DalilThemePalette palette, {bool dark = false}) {
    final base = MerchantTheme.build();
    final brightness = dark ? Brightness.dark : Brightness.light;
    final surface = dark ? const Color(0xFF111827) : Shop.surface;
    final background = dark ? const Color(0xFF0B1220) : Shop.paper;
    final onSurface = dark ? const Color(0xFFF8FAFC) : Shop.ink;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      secondary: palette.secondary,
      surface: surface,
      error: Shop.clay,
    );

    return base.copyWith(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(palette.primary),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.primary),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: palette.primary.withValues(alpha: .12),
        backgroundColor: surface,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
    );
  }
}
