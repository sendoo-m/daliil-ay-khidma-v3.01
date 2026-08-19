import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTokens {
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const text = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);

  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF111827);
  static const darkText = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF263244);
}

/// Compatibility facade for screens that still reference the legacy constants.
/// New/updated screens should prefer Theme.of(context).colorScheme and the
/// dynamic theme preference instead. Keeping these constants during migration
/// prevents unrelated screens from breaking while we refresh them PR-by-PR.
abstract final class AppColors {
  static const primary = Color(0xFF0F8B8D);
  static const primaryDark = Color(0xFF0A6F71);
  static const secondary = Color(0xFF19A974);
  static const primarySoft = Color(0xFFE9F8F7);
  static const secondarySoft = Color(0xFFEAF8F1);
  static const accent = Color(0xFFF59E0B);
  static const accentDark = Color(0xFFD97706);
  static const accentSoft = Color(0xFFFFF7E6);
  static const background = AppTokens.background;
  static const surface = AppTokens.surface;
  static const surfaceMuted = AppTokens.surfaceMuted;
  static const text = AppTokens.text;
  static const muted = AppTokens.muted;
  static const border = AppTokens.border;
  static const success = AppTokens.success;
  static const error = AppTokens.error;

  static const brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

abstract final class AppTheme {
  static ThemeData light(DalilThemePalette palette) => _build(palette, false);
  static ThemeData dark(DalilThemePalette palette) => _build(palette, true);

  static ThemeData _build(DalilThemePalette palette, bool dark) {
    final background = dark ? AppTokens.darkBackground : AppTokens.background;
    final surface = dark ? AppTokens.darkSurface : AppTokens.surface;
    final text = dark ? AppTokens.darkText : AppTokens.text;
    final muted = dark ? AppTokens.darkMuted : AppTokens.muted;
    final border = dark ? AppTokens.darkBorder : AppTokens.border;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      secondary: palette.secondary,
      surface: surface,
      error: AppTokens.error,
    );
    final base = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      brightness: brightness,
    );
    final cairo = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
    );

    return base.copyWith(
      textTheme: cairo.copyWith(
        headlineLarge: cairo.headlineLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
        headlineMedium: cairo.headlineMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.3),
        headlineSmall: cairo.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.35),
        titleLarge: cairo.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: cairo.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: cairo.bodyLarge?.copyWith(height: 1.7),
        bodyMedium: cairo.bodyMedium?.copyWith(height: 1.6),
        bodySmall: cairo.bodySmall?.copyWith(color: muted, height: 1.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.cairo(color: text, fontSize: 21, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.cairo(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: palette.primary, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primary),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: palette.primary.withValues(alpha: .12),
        side: BorderSide(color: border),
        labelStyle: GoogleFonts.cairo(color: text, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: palette.primary.withValues(alpha: .12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? palette.primary : muted,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => GoogleFonts.cairo(
          color: states.contains(WidgetState.selected) ? palette.primary : muted,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppTokens.darkText : AppTokens.text,
        contentTextStyle: GoogleFonts.cairo(color: dark ? AppTokens.text : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.primary),
    );
  }
}
