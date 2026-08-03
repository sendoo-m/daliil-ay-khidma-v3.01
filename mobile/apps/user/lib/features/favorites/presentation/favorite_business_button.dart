import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../directory/data/business.dart';

class FavoriteBusinessButton extends ConsumerWidget {
  const FavoriteBusinessButton({
    required this.business,
    this.compact = false,
    super.key,
  });

  final Business business;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final state = favorites.valueOrNull;
    final isFavorite = state?.containsBusiness(business.id) ?? business.isFavorite;
    final isPending = state?.isBusinessPending(business.id) ?? false;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final addLabel = isArabic ? 'إضافة إلى المفضلة' : 'Add to favorites';
    final removeLabel = isArabic ? 'إزالة من المفضلة' : 'Remove from favorites';

    return Semantics(
      button: true,
      label: isFavorite ? removeLabel : addLabel,
      child: IconButton(
        tooltip: isFavorite ? removeLabel : addLabel,
        visualDensity: compact ? VisualDensity.compact : null,
        onPressed: isPending
            ? null
            : () async {
                try {
                  await ref
                      .read(favoritesProvider.notifier)
                      .toggleBusiness(business);
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'تعذر تحديث المفضلة. حاول مرة أخرى.'
                            : 'Could not update favorites. Try again.',
                      ),
                    ),
                  );
                }
              },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: child,
          ),
          child: isPending
              ? SizedBox.square(
                  key: const ValueKey('pending'),
                  dimension: compact ? 18 : 22,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(isFavorite),
                  color: isFavorite ? Theme.of(context).colorScheme.error : null,
                ),
        ),
      ),
    );
  }
}
