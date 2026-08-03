import 'package:dalil_app/features/notifications/data/notification_repository.dart';
import 'package:dalil_app/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile maps extended account fields safely', () {
    final profile = UserProfile.fromJson({
      'username': 'ahmed',
      'first_name': 'أحمد',
      'last_name': 'محمد',
      'email': 'ahmed@example.com',
      'phone': '01012345678',
      'bio': 'أبحث عن أفضل الخدمات القريبة',
      'city': 'القاهرة',
      'profile_picture': 'https://example.com/avatar.png',
      'email_verified': true,
      'date_joined': '2026-07-20T10:00:00Z',
    });

    expect(profile.username, 'ahmed');
    expect(profile.bio, 'أبحث عن أفضل الخدمات القريبة');
    expect(profile.city, 'القاهرة');
    expect(profile.emailVerified, isTrue);
    expect(profile.dateJoined?.isUtc, isTrue);
  });

  test('notification maps metadata and copyWith preserves content', () {
    final notification = AppNotification.fromJson({
      'id': 42,
      'notification_type': 'deal',
      'title': 'عرض جديد',
      'body': 'خصم لفترة محدودة',
      'data': {'deal_id': 7},
      'is_read': false,
      'created_at': '2026-07-23T18:30:00Z',
    });

    expect(notification.type, 'deal');
    expect(notification.data['deal_id'], 7);
    expect(notification.isRead, isFalse);
    expect(notification.copyWith(isRead: true).isRead, isTrue);
    expect(notification.copyWith(isRead: true).title, 'عرض جديد');
  });
}
