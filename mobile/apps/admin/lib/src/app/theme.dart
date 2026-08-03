import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// سِمة تطبيق الإدارة.
///
/// ثلاثة خطوط بأدوار مختلفة:
///   نوتو كوفي عربي  — العناوين. خط رسمي زاوي، لغة اللافتات الحكومية.
///   IBM Plex Sans Arabic — النص. مصمم للعربية أصلًا لا محوّلًا عن اللاتينية.
///   IBM Plex Mono   — الأرقام والمسلسلات. أرقام متساوية العرض تجعل
///                     الأعمدة تصطف، وهذا سبب وظيفي لا زخرفي.
abstract final class AdminTheme {
  static ThemeData build() {
    const scheme = ColorScheme.light(
      primary: DalilColors.ink,
      onPrimary: Colors.white,
      secondary: DalilColors.seal,
      onSecondary: Colors.white,
      error: DalilColors.stamp,
      onError: Colors.white,
      surface: DalilColors.surface,
      onSurface: DalilColors.ink,
    );

    final body = GoogleFonts.ibmPlexSansArabicTextTheme();
    final display = GoogleFonts.notoKufiArabic();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: DalilColors.paper,
      textTheme: body.copyWith(
        displaySmall: display.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: DalilColors.ink,
          height: 1.3,
        ),
        headlineSmall: display.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: DalilColors.ink,
          height: 1.4,
        ),
        titleMedium: display.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: DalilColors.ink,
          height: 1.5,
        ),
        bodyMedium: body.bodyMedium?.copyWith(
          fontSize: 14,
          color: DalilColors.ink,
          height: 1.7,
        ),
        bodySmall: body.bodySmall?.copyWith(
          fontSize: 12.5,
          color: DalilColors.inkSoft,
          height: 1.6,
        ),
        labelSmall: body.labelSmall?.copyWith(
          fontSize: 11,
          color: DalilColors.inkFaint,
          letterSpacing: 0.4,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DalilColors.rule,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: DalilColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DalilRadii.card),
          side: const BorderSide(color: DalilColors.rule),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DalilColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DalilSpacing.md,
          vertical: 14,
        ),
        border: _fieldBorder(DalilColors.rule),
        enabledBorder: _fieldBorder(DalilColors.rule),
        focusedBorder: _fieldBorder(DalilColors.ink, width: 1.5),
        errorBorder: _fieldBorder(DalilColors.stamp),
        focusedErrorBorder: _fieldBorder(DalilColors.stamp, width: 1.5),
        labelStyle: const TextStyle(color: DalilColors.inkSoft),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DalilColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: DalilSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DalilRadii.control),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DalilColors.ink,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: DalilColors.rule),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DalilRadii.control),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DalilColors.ink,
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: Colors.white,
          fontSize: 13.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DalilRadii.control),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(DalilRadii.control),
        borderSide: BorderSide(color: color, width: width),
      );

  /// خط الأرقام والمسلسلات.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = DalilColors.inkSoft,
    double spacing = 0.2,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );

  /// عنوان قسم صغير فوق المحتوى.
  static TextStyle get eyebrow => GoogleFonts.ibmPlexMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: DalilColors.inkFaint,
        letterSpacing: 1.2,
      );
}
