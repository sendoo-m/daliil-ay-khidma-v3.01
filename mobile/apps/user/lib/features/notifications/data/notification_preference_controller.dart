import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device_repository.dart';

const _enabledKey = 'push_notifications_enabled';
const pushRegistrationIdStorageKey = 'push_registration_id';

/// Whether push notifications are turned on for this device. Backed by the
/// real register/unregister endpoints — turning this off actually removes
/// the device's push token server-side instead of just flipping a cosmetic
/// switch, since there is no separate "muted" flag to set.
final class NotificationPreferenceController extends StateNotifier<bool> {
  NotificationPreferenceController(this._devices, this._storage)
      : super(true) {
    _restore();
  }

  final DeviceRepository _devices;
  final FlutterSecureStorage _storage;

  Future<void> _restore() async {
    final saved = await _storage.read(key: _enabledKey);
    if (saved != null) state = saved == 'true';
  }

  /// يقرأ التفضيل المحفوظ مباشرة من التخزين بدل الاعتماد على [state]، اللي
  /// بيبدأ دايمًا true لحد ما [_restore] يخلص بشكل غير متزامن — قارئ في
  /// نفس اللحظة اللي الـ controller اتبنى فيها ممكن ياخد القيمة الافتراضية
  /// الخاطئة بدل التفضيل الحقيقي المحفوظ.
  Future<bool> readPersistedEnabled() async {
    final saved = await _storage.read(key: _enabledKey);
    return saved == null || saved == 'true';
  }

  Future<void> setEnabled(bool value) async {
    if (value == state) return;
    if (value) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final id = await _devices.register(token: token);
      await _storage.write(key: pushRegistrationIdStorageKey, value: '$id');
    } else {
      final storedId = await _storage.read(key: pushRegistrationIdStorageKey);
      final id = int.tryParse(storedId ?? '');
      if (id != null) {
        await _devices.unregister(registrationId: id);
        await _storage.delete(key: pushRegistrationIdStorageKey);
      }
    }
    state = value;
    await _storage.write(key: _enabledKey, value: '$value');
  }
}
