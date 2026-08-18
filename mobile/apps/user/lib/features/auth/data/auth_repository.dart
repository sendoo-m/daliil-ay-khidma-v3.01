import 'package:dio/dio.dart';

import '../../../core/auth/token_store.dart';

final class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/register/',
      data: {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirm': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    final tokens = response.data?['tokens'] as Map<String, dynamic>;
    await _tokens.save(
      TokenPair(
        access: tokens['access'] as String,
        refresh: tokens['refresh'] as String,
      ),
    );
  }

  Future<bool> restoreSession() async {
    if (await _tokens.readRefresh() == null) return false;
    try {
      await _dio.get<Map<String, dynamic>>('auth/profile/');
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _tokens.clear();
        return false;
      }
      return true;
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/login/',
      data: {'username': username.trim(), 'password': password},
    );
    final data = response.data ?? const <String, dynamic>{};
    await _tokens.save(
      TokenPair(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      ),
    );
  }

  Future<void> requestAccountDeletion({
    required String password,
    String reason = '',
  }) async {
    final refresh = await _tokens.readRefresh();
    await _dio.post<Map<String, dynamic>>(
      'auth/account-deletion/',
      data: {
        'password': password,
        'confirmation': 'DELETE',
        'source': 'user_app',
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (refresh != null) 'refresh': refresh,
      },
    );
    await _tokens.clear();
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    try {
      if (refresh != null) {
        await _dio.post<void>('auth/logout/', data: {'refresh': refresh});
      }
    } finally {
      await _tokens.clear();
    }
  }
}
