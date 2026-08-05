import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان تطبيق الأنشطة.
///
/// الاتجاه: **لافتة المحل**. لوحة الإدارة مكتب سجلات — ورق بارد وخطوط
/// شعرية وأختام. هذا التطبيق شيء آخر تمامًا: هنا المحل محلّك، والواجهة
/// تبدأ بلافتته لا بجدول.
///
/// الأخضر النيلي العميق هو لون اللافتة، والنحاسي للتقييم والتميّز —
/// لون اللافتات والبراويز في الشارع المصري. الطين للي محتاج إيدك.
abstract final class Shop {
  /// شريط اللافتة. غامق، يحمل اسم المحل.
  static const sign = Color(0xFF14332B);
  static const signSoft = Color(0xFF1E4A3E);

  /// صفحة بميل خفيف للمريمية — ليست كريمية ولا رمادية ميتة.
  static const paper = Color(0xFFF2F4F0);
  static const surface = Color(0xFFFFFFFF);

  static const ink = Color(0xFF1E2420);
  static const inkSoft = Color(0xFF6B7268);
  static const inkFaint = Color(0xFF9BA197);

  static const rule = Color(0xFFDEE3DB);

  /// نحاسي: التقييم، التميّز. أدفأ لون في الواجهة وأندره.
  static const brass = Color(0xFFC1811F);
  static const brassWash = Color(0xFFFBF2E1);

  /// يشمي: موثّق، تم، إيجابي.
  static const jade = Color(0xFF1F7A5E);
  static const jadeWash = Color(0xFFE7F3EE);

  /// طين: محتاج إيدك، تحذير، حذف.
  static const clay = Color(0xFFA83A2C);
  static const clayWash = Color(0xFFFAEDEA);
}

abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 36;
}

abstract final class Radii {
  /// أنعم من لوحة الإدارة — هذا تطبيق موبايل يُلمس، لا جدول يُقرأ.
  static const double card = 14;
  static const double control = 10;
  static const double pill = 999;
}

abstract final class MerchantTheme {
  /// ريدكس برو للعناوين والأرقام — خط مصمَّم للعربية واللاتينية معًا،
  /// وليس كايرو أو تجوال اللذين يظهران في كل تطبيق عربي.
  /// تجوال للنص: عريض ودافئ ويُقرأ جيدًا بأحجام صغيرة على الموبايل.
  static ThemeData build() {
    final body = GoogleFonts.tajawalTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Shop.paper,
      colorScheme: const ColorScheme.light(
        primary: Shop.sign,
        onPrimary: Colors.white,
        secondary: Shop.brass,
        onSecondary: Colors.white,
        error: Shop.clay,
        onError: Colors.white,
        surface: Shop.surface,
        onSurface: Shop.ink,
      ),
      textTheme: body.copyWith(
        displaySmall: GoogleFonts.readexPro(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Shop.ink,
          height: 1.35,
        ),
        headlineSmall: GoogleFonts.readexPro(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: Shop.ink,
          height: 1.4,
        ),
        titleMedium: GoogleFonts.readexPro(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Shop.ink,
          height: 1.5,
        ),
        bodyMedium: body.bodyMedium?.copyWith(
          fontSize: 14.5,
          color: Shop.ink,
          height: 1.75,
        ),
        bodySmall: body.bodySmall?.copyWith(
          fontSize: 13,
          color: Shop.inkSoft,
          height: 1.65,
        ),
        labelSmall: body.labelSmall?.copyWith(
          fontSize: 11.5,
          color: Shop.inkFaint,
          letterSpacing: 0.3,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Shop.rule,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Shop.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: 15,
        ),
        border: _field(Shop.rule),
        enabledBorder: _field(Shop.rule),
        focusedBorder: _field(Shop.sign, width: 1.6),
        errorBorder: _field(Shop.clay),
        focusedErrorBorder: _field(Shop.clay, width: 1.6),
        labelStyle: const TextStyle(color: Shop.inkSoft),
        hintStyle: const TextStyle(color: Shop.inkFaint),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Shop.sign,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          textStyle: GoogleFonts.readexPro(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Shop.sign,
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: Shop.rule),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          textStyle: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Shop.sign,
        contentTextStyle: GoogleFonts.tajawal(
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),
    );
  }

  static OutlineInputBorder _field(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: color, width: width),
      );

  /// الأرقام الكبيرة. ريدكس برو لا خط أحادي — التاجر يريد رقمًا وديًا
  /// يقرأه بلمحة، لا عمودًا يصطف مع غيره.
  static TextStyle figure({
    double size = 34,
    Color color = Shop.ink,
  }) =>
      GoogleFonts.readexPro(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.1,
      );

  static TextStyle get eyebrow => GoogleFonts.readexPro(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Shop.inkFaint,
        letterSpacing: 0.6,
      );
}
