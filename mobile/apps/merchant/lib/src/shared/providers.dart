import 'package:dalil_core/dalil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

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

final class SessionLoading extends SessionState {
  const SessionLoading();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.reason});
  final String? reason;
}

final class SessionActive extends SessionState {
  const SessionActive(this.session);
  final MerchantSession session;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionLoading();
  }

  ApiClient get _api => ref.read(apiClientProvider);
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  Future<MerchantSession> _load() async =>
      MerchantSession.fromJson(await _api.getJson('merchant/session/'));

  Future<void> restore() async {
    if (!await _tokens.hasSession) {
      state = const SessionSignedOut();
      return;
    }
    try {
      state = SessionActive(await _load());
    } on ApiFailure catch (failure) {
      await _tokens.clear();
      state = SessionSignedOut(reason: failure.isForbidden ? _noShop : null);
    }
  }

  static const _noShop =
      'الحساب صحيح، لكن مفيش نشاط مسجَّل عليه. لو عندك محل أو خدمة '
      'وعايز تضيفها، كلّم الدعم وهنسجّلها لك.';

  /// لا نضبط [SessionLoading] هنا — تغيير الحالة يهدم شاشة الدخول
  /// فتضيع رسالة الخطأ. الشاشة تدير مؤشر انتظارها بنفسها.
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    try {
      await _auth.login(username: username, password: password);
    } catch (error) {
      await _tokens.clear();
      rethrow;
    }

    try {
      state = SessionActive(await _load());
    } on ApiFailure catch (failure) {
      await _tokens.clear();
      if (failure.isForbidden) {
        throw const ApiFailure(message: _noShop, statusCode: 403);
      }
      // 404 على نقطة الجلسة معناه الخادم لا يعرف هذا المسار — أي أنه
      // يشغّل نسخة أقدم من الكود. الرسالة تقول ذلك صراحةً بدل تركها
      // "غير موجود" الغامضة التي ترسل التاجر يشك في حسابه.
      if (failure.isNotFound) {
        throw const ApiFailure(
          message: 'الخادم لسه بيشغّل نسخة قديمة مفيهاش خدمة الأنشطة. '
              'محتاج تحديث النشر على الخادم قبل ما التطبيق يشتغل.',
          statusCode: 404,
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.logout();
    state = const SessionSignedOut();
  }

  void forceSignOut() {
    state = const SessionSignedOut(reason: 'انتهت جلستك. سجّل الدخول من جديد.');
  }

  Future<void> refreshShops() async {
    if (state is! SessionActive) return;
    try {
      state = SessionActive(await _load());
    } on ApiFailure {
      // تحديث فاشل لا يجب أن يُخرج التاجر — نُبقي البيانات السابقة.
    }
  }
}

final activeSessionProvider = Provider<MerchantSession>((ref) {
  final state = ref.watch(sessionProvider);
  if (state is SessionActive) return state.session;
  throw StateError('قُرئت الجلسة خارج منطقة محمية.');
});

/// النشاط المختار حاليًا. مهم لأصحاب أكثر من محل.
final selectedShopProvider = StateProvider<int?>((ref) {
  final state = ref.watch(sessionProvider);
  if (state is SessionActive) return state.session.firstShop?.id;
  return null;
});

final currentShopProvider = Provider<ShopSummary?>((ref) {
  final session = ref.watch(activeSessionProvider);
  final id = ref.watch(selectedShopProvider);
  if (session.shops.isEmpty) return null;
  return session.shops.firstWhere(
    (s) => s.id == id,
    orElse: () => session.shops.first,
  );
});

// ── البيانات ──────────────────────────────────────────

final dashboardProvider =
    FutureProvider.autoDispose<MerchantDashboard>((ref) async {
  final api = ref.watch(apiClientProvider);
  return MerchantDashboard.fromJson(await api.getJson('merchant/dashboard/'));
});

/// تصفية التقييمات: الكل أو ما ينتظر ردًا.
final reviewsNeedReplyOnlyProvider = StateProvider.autoDispose<bool>((_) => false);

final reviewsProvider =
    FutureProvider.autoDispose<List<ReviewItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final shop = ref.watch(currentShopProvider);
  final page = await api.getPage(
    'merchant/reviews/',
    ReviewItem.fromJson,
    query: {if (shop != null) 'business': shop.id},
  );

  final items = [...page.items];
  // الأعجل أولًا: تقييم منخفض بلا رد، ثم بقية ما ينتظر ردًا.
  items.sort((a, b) {
    if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
    if (a.needsReply != b.needsReply) return a.needsReply ? -1 : 1;
    return (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000));
  });

  if (ref.watch(reviewsNeedReplyOnlyProvider)) {
    return items.where((r) => r.needsReply).toList(growable: false);
  }
  return items;
});

final productsProvider =
    FutureProvider.autoDispose<List<ProductItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final shop = ref.watch(currentShopProvider);
  final page = await api.getPage(
    'merchant/products/',
    ProductItem.fromJson,
    query: {if (shop != null) 'business': shop.id},
  );
  return page.items;
});

// ── العمليات ──────────────────────────────────────────

final merchantActionsProvider = Provider<MerchantActions>(
  (ref) => MerchantActions(ref),
);

class MerchantActions {
  MerchantActions(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> replyToReview(int reviewId, String comment) async {
    await _api.post(
      'merchant/reviews/$reviewId/reply/',
      body: {'comment': comment},
    );
    _ref.invalidate(reviewsProvider);
    _ref.invalidate(dashboardProvider);
  }

  Future<void> setProductAvailability(int productId, bool available) async {
    await _api.patch(
      'merchant/products/$productId/',
      body: {'is_available': available},
    );
    _ref.invalidate(productsProvider);
  }

  Future<void> updateShop(int shopId, Map<String, dynamic> changes) async {
    await _api.patch('merchant/businesses/$shopId/', body: changes);
    await _ref.read(sessionProvider.notifier).refreshShops();
    _ref.invalidate(dashboardProvider);
  }
}
