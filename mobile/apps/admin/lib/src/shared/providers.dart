import 'package:dalil_core/dalil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// عنوان الخادم. يُمرَّر وقت البناء:
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com
const _rawBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://daliil-ay-khidma.onrender.com',
);

final apiBaseUrlProvider = Provider<String>((ref) => '$_rawBaseUrl/api/v2/');

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    tokens: ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(sessionProvider.notifier).forceSignOut(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});

// ── حالة الجلسة ───────────────────────────────────────

sealed class SessionState {
  const SessionState();
}

/// نتحقق من وجود جلسة محفوظة — شاشة البداية.
final class SessionLoading extends SessionState {
  const SessionLoading();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.reason});

  /// سبب الخروج، لعرضه في شاشة الدخول ("انتهت جلستك").
  final String? reason;
}

final class SessionActive extends SessionState {
  const SessionActive(this.session);

  final AdminSession session;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionLoading();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  /// عند فتح التطبيق: لو فيه رمز محفوظ، نحمّل الجلسة مباشرة.
  Future<void> restore() async {
    if (!await _tokens.hasSession) {
      state = const SessionSignedOut();
      return;
    }
    try {
      state = SessionActive(await _auth.loadAdminSession());
    } on ApiFailure catch (failure) {
      await _tokens.clear();
      state = SessionSignedOut(
        reason: failure.isForbidden
            ? 'هذا الحساب لا يملك صلاحية الدخول للوحة الإدارة.'
            : null,
      );
    }
  }

  /// يرمي [ApiFailure] ليعرضها نموذج الدخول تحت الحقل المناسب.
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    state = const SessionLoading();
    try {
      await _auth.login(username: username, password: password);
      state = SessionActive(await _auth.loadAdminSession());
    } catch (error) {
      await _tokens.clear();
      state = const SessionSignedOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.logout();
    state = const SessionSignedOut();
  }

  /// يُستدعى من ApiClient عند فشل التجديد نهائيًا.
  void forceSignOut() {
    state = const SessionSignedOut(reason: 'انتهت جلستك. سجّل الدخول من جديد.');
  }
}

/// الجلسة النشطة. تُقرأ داخل الشاشات المحمية فقط، حيث يضمن الموجّه وجودها.
final activeSessionProvider = Provider<AdminSession>((ref) {
  final state = ref.watch(sessionProvider);
  if (state is SessionActive) return state.session;
  throw StateError('قُرئت الجلسة النشطة خارج منطقة محمية.');
});

// ── بيانات اللوحة ─────────────────────────────────────

class PendingQueue {
  const PendingQueue({
    required this.businesses,
    required this.reviews,
    required this.expiringDeals,
  });

  final int businesses;
  final int reviews;
  final int expiringDeals;

  int get total => businesses + reviews + expiringDeals;

  factory PendingQueue.fromJson(Map<String, dynamic> json) => PendingQueue(
        businesses:
            (json['businesses_awaiting_verification'] as num?)?.toInt() ?? 0,
        reviews: (json['reviews_awaiting_moderation'] as num?)?.toInt() ?? 0,
        expiringDeals: (json['deals_expiring_soon'] as num?)?.toInt() ?? 0,
      );
}

final pendingQueueProvider = FutureProvider.autoDispose<PendingQueue>((ref) async {
  final api = ref.watch(apiClientProvider);
  return PendingQueue.fromJson(await api.getJson('admin/dashboard/pending-queue/'));
});

final dashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getJson('admin/dashboard/stats/');
});
