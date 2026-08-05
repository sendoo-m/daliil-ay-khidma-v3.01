import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import 'api_failure.dart';
import 'paginated.dart';

/// عميل HTTP مشترك بين تطبيق المستخدم وتطبيق الإدارة.
///
/// يتولى: إرفاق رمز الدخول، تجديده تلقائيًا عند 401، إعادة المحاولة
/// للأخطاء المؤقتة، وتحويل كل خطأ إلى [ApiFailure] عربي.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokens,
    this.onSessionExpired,
  })  : _tokens = tokens,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(_AuthInterceptor(dio, _tokens, onSessionExpired));
    dio.interceptors.add(_RetryInterceptor(dio));
  }

  final Dio dio;
  final TokenStore _tokens;

  /// يُستدعى عندما يفشل التجديد نهائيًا — التطبيق يعيد للمستخدم شاشة الدخول.
  final void Function()? onSessionExpired;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return const [];
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<Paginated<T>> getPage<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    final json = await getJson(path, query: query);
    return Paginated.fromJson<T>(json, parse);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.post<dynamic>(
        path,
        data: body,
        queryParameters: query,
      );
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async {
    try {
      final res = await dio.patch<dynamic>(path, data: body);
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  /// رفع صورة مع حقول نصية في طلب واحد.
  ///
  /// نمرّر البايتات لا مسار الملف: على الويب لا يوجد مسار أصلًا، وعلى
  /// الموبايل يبقى الكود واحدًا. [onProgress] تُظهر شريط تقدم — رفع
  /// صورة على شبكة ضعيفة قد يستغرق عشرات الثواني، وشاشة صامتة تبدو
  /// معطّلة فيضغط المستخدم مرة أخرى ويرفع نسختين.
  Future<Map<String, dynamic>> sendMultipart(
    String path, {
    required String method,
    required String fileField,
    required Uint8List bytes,
    required String filename,
    Map<String, dynamic> fields = const {},
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final form = FormData();

      fields.forEach((key, value) {
        if (value == null) return;
        form.fields.add(MapEntry(key, '$value'));
      });

      form.files.add(
        MapEntry(
          fileField,
          MultipartFile.fromBytes(bytes, filename: filename),
        ),
      );

      final res = await dio.request<dynamic>(
        path,
        data: form,
        options: Options(
          method: method,
          contentType: 'multipart/form-data',
          // الرفع أبطأ من طلب عادي — مهلة أطول تمنع فشلًا زائفًا.
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onProgress,
      );

      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await dio.delete<dynamic>(path);
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._tokens, this._onExpired);

  final Dio _dio;
  final TokenStore _tokens;
  final void Function()? _onExpired;

  /// تجديد واحد مشترك: لو عشرة طلبات فشلت بـ401 معًا، لا نُطلق
  /// عشر عمليات تجديد متوازية تُبطل بعضها.
  Future<String?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final access = await _tokens.readAccess();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    } catch (_) {
      // التخزين الآمن قد يفشل على الويب — لا يمنع الطلبات العامة.
      options.headers.remove('Authorization');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final shouldRefresh = error.response?.statusCode == 401 &&
        request.extra['authRetried'] != true &&
        !request.path.contains('auth/refresh') &&
        !request.path.contains('auth/login');

    if (!shouldRefresh) return handler.next(error);

    try {
      final access = await (_refreshing ??= _refresh());
      _refreshing = null;

      if (access == null) {
        await _tokens.clear();
        _onExpired?.call();
        return handler.next(error);
      }

      request.extra['authRetried'] = true;
      request.headers['Authorization'] = 'Bearer $access';
      handler.resolve(await _dio.fetch<dynamic>(request));
    } catch (_) {
      _refreshing = null;
      await _tokens.clear();
      _onExpired?.call();
      handler.next(error);
    }
  }

  Future<String?> _refresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return null;

    // Dio نظيف بلا interceptors — وإلا دخلنا حلقة لا نهائية.
    final plain = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
    final res = await plain.post<Map<String, dynamic>>(
      'auth/refresh/',
      data: {'refresh': refresh},
    );

    final access = res.data?['access'] as String?;
    if (access == null) return null;

    await _tokens.saveAccess(access);
    // بعض الإعدادات تُدوّر رمز التجديد أيضًا.
    final rotated = res.data?['refresh'] as String?;
    if (rotated != null) await _tokens.saveRefresh(rotated);

    return access;
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  static const _maxRetries = 2;
  final Dio _dio;

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final attempt = request.extra['retryCount'] as int? ?? 0;
    final method = request.method.toUpperCase();
    final status = error.response?.statusCode;

    // إعادة المحاولة للطلبات الآمنة فقط — إعادة POST قد تُنشئ سجلًا مكررًا.
    final isSafe = method == 'GET' || method == 'HEAD';
    final isTransient = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.connectionError =>
        true,
      _ => status == 502 || status == 503 || status == 504,
    };

    if (!isSafe || !isTransient || attempt >= _maxRetries) {
      return handler.next(error);
    }

    request.extra['retryCount'] = attempt + 1;
    await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));

    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
