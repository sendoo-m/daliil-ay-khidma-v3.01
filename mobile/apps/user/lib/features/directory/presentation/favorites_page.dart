import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../data/business.dart';
import 'business_detail_page.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({this.embedded = false, super.key});
  final bool embedded;

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  late Future<List<Business>> _future;
  final _removing = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Business>> _load() =>
      ref.read(businessRepositoryProvider).favorites();

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: const Text('المفضلة'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<Business>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _FavoritesState(
                icon: Icons.cloud_off_outlined,
                title: 'تعذر تحميل المفضلة',
                subtitle: 'تحقق من الاتصال ثم حاول مرة أخرى.',
                actionLabel: 'إعادة المحاولة',
                onAction: _reload,
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const _FavoritesState(
                icon: Icons.favorite_border,
                title: 'مفضّلتك فارغة',
                subtitle:
                    'اضغط على رمز القلب في صفحة أي محل للعودة إليه بسهولة.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                final next = _load();
                setState(() => _future = next);
                await next;
              },
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 252,
                ),
                itemBuilder: (_, index) {
                  final business = items[index];
                  return _FavoriteTile(
                    business: business,
                    removing: _removing.contains(business.id),
                    onRemove: () => _remove(business),
                  );
                },
              ),
            );
          },
        ),
      );

  Future<void> _remove(Business business) async {
    setState(() => _removing.add(business.id));
    try {
      await ref
          .read(businessRepositoryProvider)
          .toggleFavorite(business.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت إزالة ${business.displayName}')),
        );
        _reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذرت الإزالة، حاول مرة أخرى')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing.remove(business.id));
    }
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.business,
    required this.removing,
    required this.onRemove,
  });

  final Business business;
  final bool removing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final image = business.coverImage ?? business.logo;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BusinessDetailPage(slug: business.slug),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 108,
                  width: double.infinity,
                  child: image == null || image.isEmpty
                      ? const ColoredBox(
                          color: AppColors.primarySoft,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: AppColors.primarySoft,
                            child: Icon(
                              Icons.storefront_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                        ),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      tooltip: 'إزالة من المفضلة',
                      visualDensity: VisualDensity.compact,
                      onPressed: removing ? null : onRemove,
                      icon: removing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.favorite,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (business.categoryName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        business.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: AppColors.accentDark,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        business.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (business.distanceKm != null) ...[
                        const Spacer(),
                        Text(
                          '${business.distanceKm!.toStringAsFixed(1)} كم',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.muted,
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: removing ? null : onRemove,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'إزالة',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesState extends StatelessWidget {
  const _FavoritesState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                icon,
                size: 68,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.6),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}
