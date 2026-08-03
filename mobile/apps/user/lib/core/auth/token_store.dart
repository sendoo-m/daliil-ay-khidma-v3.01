import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class TokenPair {
  const TokenPair({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

final class TokenStore {
  TokenStore(this._storage);

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';
  final FlutterSecureStorage _storage;

  Future<String?> readAccess() => _safeRead(_accessKey);
  Future<String?> readRefresh() => _safeRead(_refreshKey);

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // Some Web browser contexts can reject secure-storage access. Public API
      // requests must continue as guest requests instead of failing before Dio
      // sends anything to the network.
      return null;
    }
  }

  Future<void> save(TokenPair tokens) async {
    try {
      await Future.wait([
        _storage.write(key: _accessKey, value: tokens.access),
        _storage.write(key: _refreshKey, value: tokens.refresh),
      ]);
    } catch (_) {
      // Keep the application usable even when persistent browser storage is
      // unavailable. The user may need to sign in again on the next session.
    }
  }

  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessKey),
        _storage.delete(key: _refreshKey),
      ]);
    } catch (_) {
      // An unavailable store is equivalent to having no persisted session.
    }
  }

  Future<bool> get hasSession async => (await readRefresh()) != null;
}
