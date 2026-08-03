import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../directory/presentation/business_card.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final content = favorites.when(
      loading: () => const _FavoritesLoading(),
      error: (_, __) => _FavoritesError(
        isArabic: isArabic,
        onRetry: () => ref.read(favoritesProvider.notifier).refresh(),
      ),
      data: (state) {
        if (state.businesses.isEmpty) {
          return _FavoritesEmpty(isArabic: isArabic);
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(favoritesProvider.notifier).refresh(),
          child: ListView.separated(
            key: const PageStorageKey('favorite-businesses'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: state.businesses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => RepaintBoundary(
              child: BusinessCard(business: state.businesses[index]),
            ),
          ),
        );
      },
    );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        title: Text(isArabic ? 'المفضلة' : 'Favorites'),
        centerTitle: false,
      ),
      body: SafeArea(child: content),
    );
  }
}

class _FavoritesLoading extends StatelessWidget {
  const _FavoritesLoading();

  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 124,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(child: LinearProgressIndicator()),
        ),
      );
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 72),
            const Icon(
              Icons.favorite_border_rounded,
              size: 72,
              color: AppColors.primary,
            ),
            const SizedBox(height: 18),
            Text(
              isArabic ? 'لا توجد عناصر مفضلة بعد' : 'No favorites yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'اضغط على رمز القلب بجوار أي نشاط لحفظه هنا.'
                  : 'Tap the heart beside any business to save it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
        ),
      );
}

class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.isArabic, required this.onRetry});

  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 52),
              const SizedBox(height: 12),
              Text(
                isArabic ? 'تعذر تحميل المفضلة' : 'Could not load favorites',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isArabic ? 'إعادة المحاولة' : 'Try again'),
              ),
            ],
          ),
        ),
      );
}
