import 'dart:typed_data';

import 'package:dalil_core/dalil_core.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_field.dart';
import 'models.dart';

const _rawBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dalilaykhidma.com',
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

  // التاجر لازم يسجّل دخوله من جديد في كل مرة يفتح فيها التطبيق —
  // بعكس تطبيق المستخدم اللي جلسته دايمة. أي رمز محفوظ من جلسة سابقة
  // بيتمسح هنا بدل ما يُستخدم لاستعادة الجلسة تلقائيًا.
  Future<void> restore() async {
    await _tokens.clear();
    state = const SessionSignedOut();
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

final dealsProvider = FutureProvider.autoDispose<List<DealItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final shop = ref.watch(currentShopProvider);
  final page = await api.getPage(
    'merchant/deals/',
    DealItem.fromJson,
    query: {if (shop != null) 'business': shop.id},
  );
  return page.items;
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

  /// يحفظ موقع النشاط ويرجّع ما خزّنه الخادم فعلًا.
  ///
  /// نُرجع الرد لا `void`: عند إرسال رابط، الخادم هو من يستخرج
  /// الإحداثيات — والواجهة تحتاج أن تعرف إن كان نجح فعلًا أم أن
  /// الرابط لم يحمل موقعًا.
  Future<Map<String, dynamic>> updateShopLocation(
    int shopId, {
    double? latitude,
    double? longitude,
    String? locationUrl,
  }) async {
    final result = await _api.patch(
      'merchant/businesses/$shopId/',
      body: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationUrl != null) 'location_url': locationUrl,
      },
    );
    await _ref.read(sessionProvider.notifier).refreshShops();
    _ref.invalidate(dashboardProvider);
    return result;
  }

  Future<void> updateShop(int shopId, Map<String, dynamic> changes) async {
    await _api.patch('merchant/businesses/$shopId/', body: changes);
    await _ref.read(sessionProvider.notifier).refreshShops();
    _ref.invalidate(dashboardProvider);
  }

  // ── المنتجات ────────────────────────────────────────

  Future<void> createProduct(Map<String, dynamic> body) async {
    await _api.post('merchant/products/', body: body);
    _ref.invalidate(productsProvider);
    _ref.invalidate(dashboardProvider);
  }

  Future<void> updateProduct(int id, Map<String, dynamic> body) async {
    await _api.patch('merchant/products/$id/', body: body);
    _ref.invalidate(productsProvider);
  }

  Future<void> deleteProduct(int id) async {
    await _api.delete('merchant/products/$id/');
    _ref.invalidate(productsProvider);
    _ref.invalidate(dashboardProvider);
  }

  /// رفع صورة لمعرض المنتج. أول صورة تصير الرئيسية تلقائيًا.
  Future<void> addProductImage({
    required int productId,
    required PickedImage image,
    String altText = '',
    void Function(int, int)? onProgress,
  }) async {
    await _api.sendMultipart(
      'merchant/products/$productId/images/',
      method: 'POST',
      fileField: 'image',
      bytes: image.bytes,
      filename: image.filename,
      fields: {if (altText.isNotEmpty) 'alt_text_ar': altText},
      onProgress: onProgress,
    );
    _ref.invalidate(productsProvider);
  }

  Future<void> deleteProductImage(int productId, int imageId) async {
    await _api.delete('merchant/products/$productId/images/$imageId/');
    _ref.invalidate(productsProvider);
  }

  Future<void> makeImagePrimary(int productId, int imageId) async {
    await _api.post('merchant/products/$productId/images/$imageId/make-primary/');
    _ref.invalidate(productsProvider);
  }

  /// إنشاء أو تعديل مع صورة في طلب واحد.
  ///
  /// طلب واحد لا اثنان: لو رفعنا الصورة في طلب منفصل وفشل الثاني،
  /// نبقى بسجل ناقص أو صورة يتيمة على الخادم.
  /// حفظ المنتج ثم رفع صورته. خطوتان لأن الصور موديل منفصل — لا
  /// يمكن إنشاء صورة قبل وجود المنتج الذي تنتمي إليه.
  Future<void> saveProductThenImage({
    int? id,
    required Map<String, dynamic> fields,
    PickedImage? image,
    void Function(int, int)? onProgress,
  }) async {
    int productId;
    if (id == null) {
      final created = await _api.post('merchant/products/', body: fields);
      productId = (created['id'] as num).toInt();
    } else {
      await _api.patch('merchant/products/$id/', body: fields);
      productId = id;
    }

    if (image != null) {
      await addProductImage(
        productId: productId,
        image: image,
        onProgress: onProgress,
      );
    }
    _ref.invalidate(productsProvider);
    _ref.invalidate(dashboardProvider);
  }

  Future<void> saveDealWithImage({
    int? id,
    required Map<String, dynamic> fields,
    required PickedImage image,
    void Function(int, int)? onProgress,
  }) async {
    await _api.sendMultipart(
      id == null ? 'merchant/deals/' : 'merchant/deals/$id/',
      method: id == null ? 'POST' : 'PATCH',
      fileField: 'image',
      bytes: image.bytes,
      filename: image.filename,
      fields: fields,
      onProgress: onProgress,
    );
    _ref.invalidate(dealsProvider);
    _ref.invalidate(dashboardProvider);
  }

  /// شعار المحل أو صورة الغلاف.
  Future<void> uploadShopImage({
    required int shopId,
    required String field,
    required PickedImage image,
    void Function(int, int)? onProgress,
  }) async {
    await _api.sendMultipart(
      'merchant/businesses/$shopId/',
      method: 'PATCH',
      fileField: field,
      bytes: image.bytes,
      filename: image.filename,
      onProgress: onProgress,
    );
    await _ref.read(sessionProvider.notifier).refreshShops();
  }

  // ── الرفع الجماعي ───────────────────────────────────

  /// ينزّل ملف المنتجات ويحفظه على الجهاز.
  Future<void> downloadProductsFile(int shopId) async {
    final bytes = await _api.getBytes(
      'merchant/products/bulk/',
      query: {'business': shopId},
    );
    await FileSaver.instance.saveFile(
      name: 'منتجاتي-$shopId',
      bytes: bytes,
      // ‏file_saver 0.2.x اسمه ext — اتغيّر لـfileExtension في 0.4.
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  /// فحص بلا كتابة — يرجّع التقرير.
  Future<Map<String, dynamic>> checkProductsFile({
    required int shopId,
    required Uint8List bytes,
    required String filename,
  }) {
    return _api.sendMultipart(
      'merchant/products/bulk/',
      method: 'POST',
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      fields: {'business': shopId, 'dry_run': 'true'},
    );
  }

  Future<Map<String, dynamic>> commitProductsFile({
    required int shopId,
    required Uint8List bytes,
    required String filename,
    bool skipInvalid = false,
  }) async {
    final result = await _api.sendMultipart(
      'merchant/products/bulk/',
      method: 'POST',
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        'business': shopId,
        'dry_run': 'false',
        'skip_invalid': skipInvalid ? 'true' : 'false',
      },
    );
    _ref.invalidate(productsProvider);
    _ref.invalidate(dashboardProvider);
    return result;
  }

  // ── العروض ──────────────────────────────────────────

  Future<void> createDeal(Map<String, dynamic> body) async {
    await _api.post('merchant/deals/', body: body);
    _ref.invalidate(dealsProvider);
    _ref.invalidate(dashboardProvider);
  }

  Future<void> updateDeal(int id, Map<String, dynamic> body) async {
    await _api.patch('merchant/deals/$id/', body: body);
    _ref.invalidate(dealsProvider);
    _ref.invalidate(dashboardProvider);
  }

  Future<void> deleteDeal(int id) async {
    await _api.delete('merchant/deals/$id/');
    _ref.invalidate(dealsProvider);
    _ref.invalidate(dashboardProvider);
  }
}
