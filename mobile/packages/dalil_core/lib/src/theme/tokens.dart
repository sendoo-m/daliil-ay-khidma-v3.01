import 'package:flutter/material.dart';

/// قيم التصميم المشتركة.
///
/// الاتجاه البصري: مكتب سجلات — لا لوحة تحكم SaaS. المرجع هو دفتر
/// القيد الرسمي: ورق بارد، خطوط شعرية، أختام حالة، وأرقام مسلسلة
/// بخط أحادي المسافة. اللون يُستعمل للحالة فقط، لا للزينة.
abstract final class DalilColors {
  /// ورق بارد مائل للأخضر — ليس كريميًا.
  static const paper = Color(0xFFEFF2F1);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFE7EBEA);

  /// حبر أساسي: أزرق-أخضر عميق. لون الترويسة والنص الرئيسي.
  static const ink = Color(0xFF16333B);
  static const inkSoft = Color(0xFF5A6E70);
  static const inkFaint = Color(0xFF8B9B9C);

  /// خط شعري — كل الفواصل في الواجهة بهذا اللون وبسُمك 1.
  static const rule = Color(0xFFD3DAD8);

  /// ختم أحمر: ما ينتظر تدخّلًا. لا يُستعمل لأي غرض آخر.
  static const stamp = Color(0xFFB23A2E);
  static const stampWash = Color(0xFFFAEDEB);

  /// ختم أخضر: موثّق ومعتمد.
  static const seal = Color(0xFF2F7A5E);
  static const sealWash = Color(0xFFE8F2ED);

  /// ذهبي: مميَّز. أندر لون في الواجهة.
  static const gilt = Color(0xFFC08A32);
  static const giltWash = Color(0xFFFBF3E4);
}

abstract final class DalilSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
  static const double xxl = 64;
}

abstract final class DalilRadii {
  /// انحناء ضئيل جدًا: بطاقة قيد، لا فقاعة.
  static const double card = 3;
  static const double control = 4;
  static const double pill = 999;
}

abstract final class DalilDuration {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
}

/// حالة القيد — تحدد لون الختم ونصّه في كل مكان بالتطبيق.
enum RecordStamp {
  pending('بانتظار المراجعة', DalilColors.stamp, DalilColors.stampWash),
  verified('موثّق', DalilColors.seal, DalilColors.sealWash),
  featured('مميَّز', DalilColors.gilt, DalilColors.giltWash),
  suspended('معلّق', DalilColors.inkSoft, DalilColors.surfaceSunken);

  const RecordStamp(this.label, this.color, this.wash);

  final String label;
  final Color color;
  final Color wash;
}
