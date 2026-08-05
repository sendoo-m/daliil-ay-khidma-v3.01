import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تخزين رموز JWT.
///
/// يستعمل flutter_secure_storage حيث توجد (Android / iOS)، ويعود
/// لذاكرة الجلسة على الويب حيث لا يوجد مخزن آمن حقيقي — وهذا مقصود:
/// كتابة رمز إداري في localStorage تجعله متاحًا لأي سكربت XSS.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        _useMemory = kIsWeb;

  static const _accessKey = 'dalil.access';
  static const _refreshKey = 'dalil.refresh';

  final FlutterSecureStorage _storage;
  final bool _useMemory;

  String? _memAccess;
  String? _memRefresh;

  // ‏await ضرورية: بدونها يستنتج المحلل Object? من فرعَي الشرطي
  // (‏String? و Future<String?>) ويرفض الإرجاع.
  Future<String?> readAccess() async =>
      _useMemory ? _memAccess : await _read(_accessKey);

  Future<String?> readRefresh() async =>
      _useMemory ? _memRefresh : await _read(_refreshKey);

  Future<void> saveAccess(String token) async {
    if (_useMemory) {
      _memAccess = token;
      return;
    }
    await _storage.write(key: _accessKey, value: token);
  }

  Future<void> saveRefresh(String token) async {
    if (_useMemory) {
      _memRefresh = token;
      return;
    }
    await _storage.write(key: _refreshKey, value: token);
  }

  Future<void> savePair({required String access, required String refresh}) async {
    await saveAccess(access);
    await saveRefresh(refresh);
  }

  Future<bool> get hasSession async =>
      (await readRefresh())?.isNotEmpty ?? false;

  Future<void> clear() async {
    _memAccess = null;
    _memRefresh = null;
    if (_useMemory) return;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }
}
