import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/auth/token_store.dart';
import '../core/network/api_client.dart';
import '../core/notifications/push_service.dart';
import '../features/app_config/data/app_config_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/password_reset_repository.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/directory/data/business_repository.dart';
import '../features/directory/data/discovery_repository.dart';
import '../features/directory/data/search_history_repository.dart';
import '../features/directory/presentation/search_history_controller.dart';
import '../features/favorites/data/favorites_repository.dart';
import '../features/favorites/presentation/favorites_controller.dart';
import '../features/home/data/home_repository.dart';
import '../features/location/data/geocode_service.dart';
import '../features/location/data/location_service.dart';
import '../features/notifications/data/device_repository.dart';
import '../features/notifications/data/notification_preference_controller.dart';
import '../features/notifications/data/notification_repository.dart';
import '../features/profile/data/activity_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/reviews/data/review_repository.dart';
import '../features/subscriptions/data/subscription_repository.dart';

final tokenStoreProvider = Provider(
  (_) => TokenStore(const FlutterSecureStorage()),
);
final apiClientProvider = Provider((ref) => ApiClient(ref.watch(tokenStoreProvider)));
final appConfigRepositoryProvider = Provider(
  (ref) => AppConfigRepository(ref.watch(apiClientProvider).dio),
);
final deviceRepositoryProvider = Provider(
  (ref) => DeviceRepository(ref.watch(apiClientProvider).dio),
);
final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(apiClientProvider).dio),
);
final reviewRepositoryProvider = Provider(
  (ref) => ReviewRepository(ref.watch(apiClientProvider).dio),
);
final unreadNotificationsCountProvider = FutureProvider((ref) async {
  try {
    return await ref.watch(notificationRepositoryProvider).unreadCount();
  } catch (_) {
    return 0;
  }
});
final activityRepositoryProvider = Provider(
  (ref) => ActivityRepository(ref.watch(apiClientProvider).dio),
);
final recentActivityProvider = FutureProvider(
  (ref) => ref.watch(activityRepositoryProvider).recent(),
);
final myReviewsProvider = FutureProvider(
  (ref) => ref.watch(reviewRepositoryProvider).mine(),
);
final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(
    ref.watch(apiClientProvider).dio,
    ref.watch(tokenStoreProvider),
  ),
);
final subscriptionRepositoryProvider = Provider(
  (ref) => SubscriptionRepository(ref.watch(apiClientProvider).dio),
);
final locationServiceProvider = Provider((_) => LocationService());
final geocodeServiceProvider = Provider((_) => GeocodeService());
final currentLocationLabelProvider = FutureProvider((ref) async {
  try {
    final coordinates = await ref.watch(locationServiceProvider).current();
    return await ref
        .watch(geocodeServiceProvider)
        .labelFor(coordinates.latitude, coordinates.longitude);
  } catch (_) {
    // موقع مرفوض أو غير متاح: نخفي الشريحة بهدوء بدل ما نوقف الصفحة.
    return null;
  }
});
final pushServiceProvider = Provider(
  (ref) => PushService(ref.watch(deviceRepositoryProvider)),
);
final notificationPreferenceProvider =
    StateNotifierProvider<NotificationPreferenceController, bool>(
  (ref) => NotificationPreferenceController(
    ref.watch(deviceRepositoryProvider),
    const FlutterSecureStorage(),
  ),
);
final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider).dio,
    ref.watch(tokenStoreProvider),
  ),
);
final passwordResetRepositoryProvider = Provider(
  (ref) => PasswordResetRepository(ref.watch(apiClientProvider).dio),
);
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<bool>>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
final homeRepositoryProvider = Provider(
  (ref) => HomeRepository(ref.watch(apiClientProvider).dio),
);
final homeProvider = FutureProvider((ref) => ref.watch(homeRepositoryProvider).fetch());
final businessRepositoryProvider = Provider(
  (ref) => BusinessRepository(ref.watch(apiClientProvider).dio),
);
final catalogRepositoryProvider = Provider(
  (ref) => CatalogRepository(ref.watch(apiClientProvider).dio),
);
final discoveryRepositoryProvider = Provider(
  (ref) => DiscoveryRepository(ref.watch(apiClientProvider).dio),
);
final discoveryProvider = FutureProvider(
  (ref) => ref.watch(discoveryRepositoryProvider).fetch(),
);
final favoritesRepositoryProvider = Provider(
  (ref) => FavoritesRepository(ref.watch(apiClientProvider).dio),
);
final favoritesProvider = StateNotifierProvider<FavoritesController,
    AsyncValue<FavoritesState>>(
  (ref) => FavoritesController(ref.watch(favoritesRepositoryProvider)),
);
final searchHistoryRepositoryProvider = Provider(
  (_) => SearchHistoryRepository(const FlutterSecureStorage()),
);
final searchHistoryProvider = StateNotifierProvider<SearchHistoryController,
    AsyncValue<List<String>>>(
  (ref) => SearchHistoryController(ref.watch(searchHistoryRepositoryProvider)),
);
final appConfigProvider = FutureProvider(
  (ref) => ref.watch(appConfigRepositoryProvider).fetch(),
);
