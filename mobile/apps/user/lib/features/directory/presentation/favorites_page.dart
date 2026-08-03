import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/business.dart';
import 'business_card.dart';

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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final business = items[index];
                  return Stack(
                    children: [
                      BusinessCard(business: business),
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            tooltip: 'إزالة من المفضلة',
                            onPressed: _removing.contains(business.id)
                                ? null
                                : () => _remove(business),
                            icon: _removing.contains(business.id)
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.favorite,
                                    color: Colors.redAccent,
                                  ),
                          ),
                        ),
                      ),
                    ],
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
