import 'package:dio/dio.dart';

final class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        type: json['notification_type'] as String? ?? 'general',
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      );

  final int id;
  final String title;
  final String body;
  final bool isRead;
  final String type;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  String? get businessSlug => _firstString(
        const ['business_slug', 'businessSlug', 'business'],
      );

  String? get productSlug => _firstString(
        const ['product_slug', 'productSlug', 'product'],
      );

  String? get dealSlug => _firstString(
        const ['deal_slug', 'dealSlug', 'deal'],
      );

  String? _firstString(List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is Map) {
        final slug = value['slug'];
        if (slug is String && slug.trim().isNotEmpty) return slug.trim();
      }
    }
    return null;
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        type: type,
        data: data,
        createdAt: createdAt,
      );
}

final class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  Future<List<AppNotification>> list({int pageSize = 100}) async {
    final response = await _dio.get<dynamic>(
      'notifications/',
      queryParameters: {'page_size': pageSize},
    );
    final payload = response.data;
    final results = payload is Map<String, dynamic>
        ? payload['results'] as List<dynamic>? ?? const []
        : payload is List<dynamic>
            ? payload
            : const <dynamic>[];
    return results
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  Future<AppNotification> markRead(int id) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'notifications/$id/read/',
    );
    return AppNotification.fromJson(response.data!);
  }

  Future<int> unreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'notifications/unread-count/',
    );
    return response.data?['count'] as int? ?? 0;
  }

  Future<int> markAllRead() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'notifications/read-all/',
    );
    return response.data?['updated'] as int? ?? 0;
  }

  Future<void> delete(int id) =>
      _dio.delete<void>('notifications/$id/');

  Future<int> deleteMany(Iterable<int> ids) async {
    var deleted = 0;
    for (final id in ids.toSet()) {
      await delete(id);
      deleted++;
    }
    return deleted;
  }
}