import 'package:dio/dio.dart';

/// خطأ جاهز للعرض على الشاشة.
///
/// الهدف: ألا تصل رسالة إنجليزية خام أو stack trace للمستخدم أبدًا.
/// كل ما يخرج من هنا عربي ومفهوم ويقول ماذا يفعل المستخدم.
class ApiFailure implements Exception {
  const ApiFailure({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;

  /// أخطاء الحقول من DRF: {"name_ar": ["هذا الحقل مطلوب."]}
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 400 && fieldErrors.isNotEmpty;

  /// خطأ يُرجى المحاولة بعده — يستحق زر "أعد المحاولة".
  bool get isRetryable =>
      statusCode == null || statusCode! >= 500 || statusCode == 429;

  factory ApiFailure.from(Object error) {
    if (error is ApiFailure) return error;
    if (error is! DioException) {
      return const ApiFailure(message: 'حدث خطأ غير متوقع.');
    }

    final status = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiFailure(
          message: 'انتهت مهلة الاتصال. تحقق من الشبكة وأعد المحاولة.',
        );
      case DioExceptionType.connectionError:
        return const ApiFailure(
          message: 'تعذّر الوصول للخادم. تحقق من اتصالك بالإنترنت.',
        );
      case DioExceptionType.cancel:
        return const ApiFailure(message: 'أُلغي الطلب.');
      default:
        break;
    }

    final data = error.response?.data;
    final fields = <String, List<String>>{};
    String? detail;

    if (data is Map) {
      final rawDetail = data['detail'] ?? data['message'] ?? data['error'];
      if (rawDetail is String) detail = rawDetail;

      data.forEach((key, value) {
        if (key == 'detail' || key == 'message' || key == 'error') return;
        if (value is List) {
          fields['$key'] = value.map((e) => '$e').toList();
        } else if (value is String) {
          fields['$key'] = [value];
        }
      });
    } else if (data is String && data.isNotEmpty) {
      // صفحات الخطأ من الخادم ترجع HTML. عرضها للمستخدم خام غير مقبول:
      // هو لا يقرأ وسوم، والرسالة تخفي السبب الحقيقي بدل أن تكشفه.
      final looksLikeHtml = data.trimLeft().startsWith('<') ||
          data.contains('<html') ||
          data.contains('<!doctype');
      if (!looksLikeHtml && data.length < 300) {
        detail = data;
      }
    }

    return ApiFailure(
      message: detail ?? _messageForStatus(status, fields),
      statusCode: status,
      fieldErrors: fields,
    );
  }

  static String _messageForStatus(int? status, Map<String, List<String>> f) {
    if (f.isNotEmpty) return f.values.first.first;
    // ‏?? 0 يجعل المتغيّر غير قابل للعدم، وإلا رفض المحلل النمط >= 500.
    return switch (status ?? 0) {
      400 => 'البيانات المرسلة غير صحيحة.',
      401 => 'انتهت جلستك. سجّل الدخول من جديد.',
      403 => 'ليس لديك صلاحية هذه العملية.',
      404 => 'المسار ده مش موجود على الخادم. غالبًا الخادم بيشغّل '
          'نسخة أقدم من التطبيق.',
      409 => 'تعارض مع بيانات موجودة.',
      429 => 'محاولات كثيرة. انتظر قليلًا وأعد المحاولة.',
      >= 500 => 'الخادم لا يستجيب حاليًا. أعد المحاولة بعد قليل.',
      _ => 'تعذّر إتمام العملية.',
    };
  }

  @override
  String toString() => 'ApiFailure($statusCode): $message';
}
