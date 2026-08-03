import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/data/catalog_models.dart';
import '../../directory/data/business.dart';
import '../data/favorites_repository.dart';

final class FavoritesState {
  const FavoritesState({
    this.businesses = const [],
    this.products = const [],
    this.deals = const [],
    this.pendingBusinessIds = const {},
  });

  final List<Business> businesses;
  final List<ProductSummary> products;      // ← > مكسورة
  final List<DealSummary> deals;            // ← > مكسورة
  final Set<int> pendingBusinessIds;        // ← > مكسورة

  bool containsBusiness(int businessId) =>
      businesses.any((item) => item.id == businessId);

  bool isBusinessPending(int businessId) =>
      pendingBusinessIds.contains(businessId);

  bool containsProduct(int productId) =>
      products.any((p) => p.id == productId);

  bool containsDeal(int dealId) =>
      deals.any((d) => d.id == dealId);

  FavoritesState copyWith({
    List<Business>? businesses,             // ← > و ? مكسورتان
    List<ProductSummary>? products,
    List<DealSummary>? deals,
    Set<int>? pendingBusinessIds,
  }) =>
      FavoritesState(
        businesses: businesses ?? this.businesses,
        products: products ?? this.products,
        deals: deals ?? this.deals,
        pendingBusinessIds: pendingBusinessIds ?? this.pendingBusinessIds,
      );
}

final class FavoritesController
    extends StateNotifier<AsyncValue<FavoritesState>> {
  FavoritesController(this._repository)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final FavoritesRepository _repository;

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        final results = await Future.wait([
          _repository.businesses(),
          _repository.products(),
          _repository.deals(),
        ]);
        return FavoritesState(
          businesses: results[0] as List<Business>,
          products: results[1] as List<ProductSummary>,
          deals: results[2] as List<DealSummary>,
          pendingBusinessIds: previous?.pendingBusinessIds ?? const {},
        );
      },
    );
  }

  Future<bool> toggleBusiness(Business business) async {
    final current = state.valueOrNull ?? const FavoritesState();
    if (current.isBusinessPending(business.id)) {
      return current.containsBusiness(business.id);
    }

    final wasFavorite =
        current.containsBusiness(business.id) || business.isFavorite;
    final optimistic = wasFavorite
        ? current.businesses
            .where((item) => item.id != business.id)
            .toList(growable: false)
        : <Business>[business, ...current.businesses];
    final pending = {...current.pendingBusinessIds, business.id};

    state = AsyncValue.data(
      current.copyWith(businesses: optimistic, pendingBusinessIds: pending),
    );

    try {
      final isFavorite = await _repository.toggleBusiness(business.id);
      final latest = state.valueOrNull ?? current;
      final reconciled = isFavorite
          ? <Business>[
              business,
              ...latest.businesses.where((item) => item.id != business.id),
            ]
          : latest.businesses
              .where((item) => item.id != business.id)
              .toList(growable: false);
      state = AsyncValue.data(
        latest.copyWith(
          businesses: reconciled,
          pendingBusinessIds: {...latest.pendingBusinessIds}..remove(business.id),
        ),
      );
      return isFavorite;
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> toggleProduct(ProductSummary product) async {
    final current = state.valueOrNull ?? const FavoritesState();
    final already = current.containsProduct(product.id);
    final updated = already
        ? current.products
            .where((p) => p.id != product.id)
            .toList(growable: false)
        : <ProductSummary>[product, ...current.products];
    state = AsyncValue.data(current.copyWith(products: updated));
    await _repository.saveProducts(updated);
    return !already;
  }

  Future<bool> toggleDeal(DealSummary deal) async {
    final current = state.valueOrNull ?? const FavoritesState();
    final already = current.containsDeal(deal.id);
    final updated = already
        ? current.deals.where((d) => d.id != deal.id).toList(growable: false)
        : <DealSummary>[deal, ...current.deals];
    state = AsyncValue.data(current.copyWith(deals: updated));
    await _repository.saveDeals(updated);
    return !already;
  }
}
