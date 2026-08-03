import 'dart:io';

import 'package:dio/dio.dart';

final class DeviceRepository {
  DeviceRepository(this._dio);

  final Dio _dio;

  Future<int> register({
    required String token,
    String deviceId = '',
    String appVersion = '',
    String language = 'ar',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'devices/',
      data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_id': deviceId,
        'app_version': appVersion,
        'language': language,
      },
    );
    return response.data!['id'] as int;
  }

  Future<void> unregister({required int registrationId}) async {
    await _dio.delete<void>('devices/$registrationId/');
  }
}
