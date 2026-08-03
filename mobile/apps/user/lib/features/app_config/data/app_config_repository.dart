import 'dart:io';

import 'package:dio/dio.dart';

final class AppConfig {
  const AppConfig({
    required this.maintenanceMode,
    required this.minimumVersion,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        maintenanceMode: json['maintenance_mode'] as bool? ?? false,
        minimumVersion: json['minimum_version'] as String? ?? '0.0.0',
      );

  final bool maintenanceMode;
  final String minimumVersion;
}

final class AppConfigRepository {
  AppConfigRepository(this._dio);

  final Dio _dio;

  Future<AppConfig> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'app-config/',
      queryParameters: {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'version': '0.1.0',
      },
    );
    return AppConfig.fromJson(response.data ?? const {});
  }
}
