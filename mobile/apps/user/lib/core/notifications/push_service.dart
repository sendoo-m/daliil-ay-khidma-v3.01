import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/notifications/data/device_repository.dart';
import '../../features/notifications/data/notification_preference_controller.dart'
    show pushRegistrationIdStorageKey;
import '../../firebase_options.dart';

final class PushService {
  PushService(this._devices, [FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final DeviceRepository _devices;
  final FlutterSecureStorage _storage;

  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) await _registerAndRemember(token);
    messaging.onTokenRefresh.listen(_registerAndRemember);
  }

  // منسجم مع NotificationPreferenceController: نفس مفتاح التخزين، عشان
  // تبديل مفتاح الإشعارات من الإعدادات يقدر يلغي تسجيل نفس الجهاز اللي
  // اتسجل هنا عند فتح التطبيق، مش بس التسجيلات اللي حصلت من شاشة الإعدادات.
  Future<void> _registerAndRemember(String token) async {
    final id = await _devices.register(token: token);
    await _storage.write(key: pushRegistrationIdStorageKey, value: '$id');
  }
}
