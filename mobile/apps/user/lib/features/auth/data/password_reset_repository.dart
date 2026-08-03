import 'package:dio/dio.dart';

final class PasswordResetRepository {
  PasswordResetRepository(this._dio);
  final Dio _dio;

  Future<void> request(String email) => _dio.post<void>(
        'auth/password-reset/',
        data: {'email': email.trim()},
      );

  Future<void> confirm({
    required String uid,
    required String token,
    required String password,
  }) => _dio.post<void>(
        'auth/password-reset/confirm/',
        data: {
          'uid': uid,
          'token': token,
          'password': password,
          'password_confirm': password,
        },
      );
}
