import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../features/notifications/data/device_repository.dart';
import '../../firebase_options.dart';

final class PushService {
  PushService(this._devices);
  final DeviceRepository _devices;

  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) await _devices.register(token: token);
    messaging.onTokenRefresh.listen((value) => _devices.register(token: value));
  }
}
