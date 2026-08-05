import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import 'product_editor_page.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);

    return products.when(
      loading: () => const Loading(),
      error: (e, _) => ShopError(
        failure: ApiFailure.from(e),
        onRetry: () => ref.invalidate(productsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return ShopEmpty(
            title: 'لسه مضفتش منتجات',
            hint: 'المحلات اللي عندها منتجات بأسعار واضحة بتجيب زيارات أكتر.',
            action: FilledButton(
              onPressed: () => openProductEditor(context),
              child: const Text('ضيف أول منتج'),
            ),
          );
        }
        return RefreshIndicator(
          color: Shop.sign,
          onRefresh: () async => ref.invalidate(productsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(Gap.md),
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == items.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  child: OutlinedButton.icon(
                    onPressed: () => openProductEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('منتج أو خدمة جديدة'),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _ProductRow(product: items[i]),
              );
            },
          ),
        );
      },
    );
  }
}

class _ProductRow extends ConsumerStatefulWidget {
  const _ProductRow({required this.product});
  final ProductItem product;

  @override
  ConsumerState<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends ConsumerState<_ProductRow> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(merchantActionsProvider)
          .setProductAvailability(widget.product.id, value);
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Shop.clay,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => openProductEditor(context, product: p),
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.rule),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nameAr,
                  style: text.titleMedium?.copyWith(
                    color: p.isAvailable ? Shop.ink : Shop.inkFaint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${p.price} ج.م',
                      style: MerchantTheme.figure(
                        size: 16,
                        color: p.isAvailable ? Shop.sign : Shop.inkFaint,
                      ),
                    ),
                    if (p.hasDiscount) ...[
                      const SizedBox(width: Gap.sm),
                      Text(
                        '${p.oldPrice}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Shop.inkFaint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            children: [
              _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: p.isAvailable,
                      activeThumbColor: Shop.jade,
                      onChanged: _toggle,
                    ),
              Text(
                p.isAvailable ? 'متاح' : 'مش متاح',
                style: text.labelSmall,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

void openProductEditor(BuildContext context, {ProductItem? product}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProductEditorPage(product: product),
    ),
  );
}
