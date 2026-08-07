import 'package:dalil_core/dalil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';

final class MerchantNotification {
  const MerchantNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory MerchantNotification.fromJson(Map<String, dynamic> json) {
    return MerchantNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['notification_type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;

  MerchantNotification copyWith({bool? isRead}) {
    return MerchantNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  String? get target {
    for (final key in const ['screen', 'route', 'target', 'type']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim().toLowerCase();
      }
    }
    return type.toLowerCase();
  }

  int? get entityId {
    for (final key in const [
      'review_id',
      'deal_id',
      'product_id',
      'business_id',
      'id',
    ]) {
      final value = data[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

final merchantNotificationRepositoryProvider =
    Provider<MerchantNotificationRepository>((ref) {
  return MerchantNotificationRepository(ref.watch(apiClientProvider));
});

final merchantUnreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(merchantNotificationRepositoryProvider).unreadCount();
});

final class MerchantNotificationRepository {
  const MerchantNotificationRepository(this._api);

  final ApiClient _api;

  Future<List<MerchantNotification>> list({
    String language = 'ar',
    int pageSize = 100,
  }) async {
    final page = await _api.getPage<MerchantNotification>(
      'notifications/',
      MerchantNotification.fromJson,
      query: {
        'language': language,
        'page_size': pageSize,
      },
    );
    return page.items.where((item) => item.id > 0).toList(growable: false);
  }

  Future<int> unreadCount() async {
    final json = await _api.getJson('notifications/unread-count/');
    return (json['count'] as num?)?.toInt() ?? 0;
  }

  Future<MerchantNotification> markRead(int id, {String language = 'ar'}) async {
    final json = await _api.post(
      'notifications/$id/read/',
      query: {'language': language},
    );
    return MerchantNotification.fromJson(json);
  }

  Future<int> markAllRead() async {
    final json = await _api.post('notifications/read-all/');
    return (json['updated'] as num?)?.toInt() ?? 0;
  }

  Future<void> delete(int id) => _api.delete('notifications/$id/');

  Future<int> deleteMany(Iterable<int> ids) async {
    var count = 0;
    for (final id in ids.toSet()) {
      await delete(id);
      count++;
    }
    return count;
  }
}
