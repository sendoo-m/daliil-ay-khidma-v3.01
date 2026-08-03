import '../models/admin_session.dart';
import '../network/api_client.dart';
import 'token_store.dart';

/// عمليات الدخول والخروج المشتركة.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  /// يسجّل الدخول ويحفظ الرموز. يرمي [ApiFailure] عند الفشل.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.post(
      'auth/login/',
      body: {'username': username, 'password': password},
    );

    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || refresh == null) {
      throw const _MalformedLogin();
    }
    await _tokens.savePair(access: access, refresh: refresh);
  }

  /// جلسة الإدارة: الهوية والصلاحيات والنطاق.
  /// أول نداء بعد الدخول — التطبيق يبني قائمته من نتيجته.
  Future<AdminSession> loadAdminSession() async {
    final data = await _api.getJson('admin/session/');
    return AdminSession.fromJson(data);
  }

  Future<void> logout() async {
    try {
      final refresh = await _tokens.readRefresh();
      if (refresh != null) {
        await _api.post('auth/logout/', body: {'refresh': refresh});
      }
    } catch (_) {
      // الخروج المحلي ينجح دائمًا حتى لو رفض الخادم.
    } finally {
      await _tokens.clear();
    }
  }
}

class _MalformedLogin implements Exception {
  const _MalformedLogin();
  @override
  String toString() => 'استجابة دخول غير مكتملة من الخادم.';
}
