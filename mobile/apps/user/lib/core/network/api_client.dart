import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/environment.dart';

final class ApiClient {
  ApiClient(this._tokens)
      : dio = Dio(
          BaseOptions(
            baseUrl: Environment.apiV2.toString(),
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.addAll([
      _AuthInterceptor(dio, _tokens),
      _TransientRetryInterceptor(dio),
    ]);
  }

  final TokenStore _tokens;
  final Dio dio;
}

final class _TransientRetryInterceptor extends Interceptor {
  _TransientRetryInterceptor(this._dio);

  static const _maxRetries = 2;
  final Dio _dio;

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final retryCount = request.extra['transientRetryCount'] as int? ?? 0;
    final statusCode = error.response?.statusCode;
    final isSafeRequest =
        request.method.toUpperCase() == 'GET' ||
        request.method.toUpperCase() == 'HEAD';
    final isTemporaryFailure = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.connectionError => true,
      _ => statusCode == 502 || statusCode == 503 || statusCode == 504,
    };

    if (!isSafeRequest ||
        !isTemporaryFailure ||
        retryCount >= _maxRetries) {
      return handler.next(error);
    }

    request.extra['transientRetryCount'] = retryCount + 1;
    await Future<void>.delayed(Duration(seconds: retryCount + 2));

    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

final class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;
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
      // Authentication storage must never block public requests on Web.
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
    final canRetry = error.response?.statusCode == 401 &&
        request.extra['authRetried'] != true &&
        !request.path.contains('auth/refresh');
    if (!canRetry) return handler.next(error);

    try {
      final access = await (_refreshing ??= _refreshAccess());
      _refreshing = null;
      if (access == null) return handler.next(error);
      request.extra['authRetried'] = true;
      request.headers['Authorization'] = 'Bearer $access';
      handler.resolve(await _dio.fetch<dynamic>(request));
    } catch (_) {
      _refreshing = null;
      await _tokens.clear();
      handler.next(error);
    }
  }

  Future<String?> _refreshAccess() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null) return null;
    final response = await Dio().post<Map<String, dynamic>>(
      Environment.apiV2.resolve('auth/refresh/').toString(),
      data: {'refresh': refresh},
    );
    final access = response.data?['access'] as String?;
    if (access == null) return null;
    final rotatedRefresh = response.data?['refresh'] as String? ?? refresh;
    await _tokens.save(TokenPair(access: access, refresh: rotatedRefresh));
    return access;
  }
}
