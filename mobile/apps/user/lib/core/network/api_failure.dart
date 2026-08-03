import 'dart:io';

import 'package:dio/dio.dart';

final class ApiFailure {
  ApiFailure._();

  static String message(Object error) {
    if (error is! DioException) return 'حدث خطأ غير متوقع';
    if (error.error is SocketException) return 'لا يوجد اتصال بالإنترنت';
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'انتهت مهلة الاتصال، حاول مرة أخرى';
    }
    final status = error.response?.statusCode;
    if (status == 401) return 'انتهت الجلسة أو بيانات الدخول غير صحيحة';
    if (status == 429) return 'عدد المحاولات كبير، حاول لاحقًا';
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      final message = data['message'] ?? data['error'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((item) => '$item').join('\n');
      }
      if (errors is Map && errors.isNotEmpty) {
        final value = errors.values.first;
        if (value is List && value.isNotEmpty) return '${value.first}';
        return '$value';
      }
    }
    return 'تعذر تنفيذ الطلب، حاول مرة أخرى';
  }
}
