import 'package:dalil_app/core/network/api_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps throttling responses to an Arabic message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/auth/password-reset/'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/auth/password-reset/'),
        statusCode: 429,
      ),
    );

    expect(ApiFailure.message(error), contains('المحاولات'));
  });

  test('joins password validation errors returned as a list', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/auth/register/'),
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/auth/register/'),
        statusCode: 400,
        data: {
          'error': ['كلمة المرور قصيرة', 'كلمة المرور شائعة'],
        },
      ),
    );

    expect(
      ApiFailure.message(error),
      'كلمة المرور قصيرة\nكلمة المرور شائعة',
    );
  });
}
