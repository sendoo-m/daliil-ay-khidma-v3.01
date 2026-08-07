import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import 'bulk_import_page.dart';
import 'product_editor_page.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _search = TextEditingController();
  String _type = 'all';
  String _availability = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);

    return products.when(
      loading: () => const Loading(),
      error: (error, _) => ShopError(
        failure: ApiFailure.from(error),
        onRetry: () => ref.invalidate(productsProvider),
      ),
      data: (items) {
        final filtered = _filter(items);
        final productsCount = items.where((item) => !item.isService).length;
        final servicesCount = items.where((item) => item.isService).length;
        final availableCount = items.where((item) => item.isAvailable).length;

        return RefreshIndicator(
          color: Shop.sign,
          onRefresh: () async => ref.invalidate(productsProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.md,
                  Gap.md,
                  Gap.md,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ManagerHeader(
                        total: items.length,
                        products: productsCount,
                        services: servicesCount,
                        available: availableCount,
                        onAdd: () => openProductEditor(context),
                        onBulk: () => _openBulk(context),
                      ),
                      const SizedBox(height: Gap.md),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم المنتج أو الخدمة',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح البحث',
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: Gap.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'الكل',
                              selected: _type == 'all',
                              onTap: () => setState(() => _type = 'all'),
                            ),
                            _FilterChip(
                              label: 'المنتجات',
                              selected: _type == 'product',
                              onTap: () => setState(() => _type = 'product'),
                            ),
                            _FilterChip(
                              label: 'الخدمات',
                              selected: _type == 'service',
                              onTap: () => setState(() => _type = 'service'),
                            ),
                            const SizedBox(width: Gap.sm),
                            Container(width: 1, height: 28, color: Shop.rule),
                            const SizedBox(width: Gap.sm),
                            _FilterChip(
                              label: 'المتاح',
                              selected: _availability == 'available',
                              onTap: () => setState(() {
                                _availability = _availability == 'available'
                                    ? 'all'
                                    : 'available';
                              }),
                            ),
                            _FilterChip(
                              label: 'غير المتاح',
                              selected: _availability == 'unavailable',
                              onTap: () => setState(() {
                                _availability = _availability == 'unavailable'
                                    ? 'all'
                                    : 'unavailable';
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      Row(
                        children: [
                          Text(
                            'الكتالوج',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${filtered.length} نتيجة',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.sm),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ShopEmpty(
                    title: 'لسه مضفتش منتجات أو خدمات',
                    hint: 'ابدأ بحاجة واحدة واضحة بصورة وسعر، وبعدها كمّل الكتالوج.',
                    action: FilledButton.icon(
                      onPressed: () => openProductEditor(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('ضيف أول عنصر'),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: ShopEmpty(
                    title: 'مفيش نتائج بالفلاتر دي',
                    hint: 'جرّب تغيّر كلمة البحث أو حالة التوفر.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.md,
                    0,
                    Gap.md,
                    Gap.xl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Gap.sm),
                    itemBuilder: (context, index) =>
                        _ProductRow(product: filtered[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<ProductItem> _filter(List<ProductItem> items) {
    final query = _search.text.trim().toLowerCase();
    return items.where((item) {
      final matchesType = switch (_type) {
        'product' => !item.isService,
        'service' => item.isService,
        _ => true,
      };
      final matchesAvailability = switch (_availability) {
        'available' => item.isAvailable,
        'unavailable' => !item.isAvailable,
        _ => true,
      };
      final haystack = '${item.nameAr} ${item.descriptionAr}'.toLowerCase();
      final matchesSearch = query.isEmpty || haystack.contains(query);
      return matchesType && matchesAvailability && matchesSearch;
    }).toList(growable: false);
  }
}

class _ManagerHeader extends StatelessWidget {
  const _ManagerHeader({
    required this.total,
    required this.products,
    required this.services,
    required this.available,
    required this.onAdd,
    required this.onBulk,
  });

  final int total;
  final int products;
  final int services;
  final int available;
  final VoidCallback onAdd;
  final VoidCallback onBulk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة الكتالوج',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'حدّث الأسعار والتوفر والخدمات من مكان واحد.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(child: _Stat(value: '$total', label: 'الكل')),
              _StatDivider(),
              Expanded(child: _Stat(value: '$products', label: 'منتجات')),
              _StatDivider(),
              Expanded(child: _Stat(value: '$services', label: 'خدمات')),
              _StatDivider(),
              Expanded(child: _Stat(value: '$available', label: 'متاح')),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onBulk,
              icon: const Icon(Icons.table_chart_outlined, size: 17),
              label: const Text('رفع أو تحديث منتجات بملف إكسل'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: MerchantTheme.figure(size: 20, color: Shop.sign)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Shop.rule);
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: Gap.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: Shop.jadeWash,
          side: BorderSide(color: selected ? Shop.jade : Shop.rule),
          labelStyle: TextStyle(
            color: selected ? Shop.jade : Shop.inkSoft,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );
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
    final product = widget.product;
    final tone = product.isService ? Shop.brass : Shop.jade;

    return Material(
      color: Shop.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: () => openProductEditor(context, product: product),
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: Shop.rule),
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Shop.paper,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: Shop.rule),
                ),
                child: product.hasImage
                    ? Image.network(
                        product.primaryImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Shop.inkFaint,
                        ),
                      )
                    : Icon(
                        product.isService
                            ? Icons.design_services_outlined
                            : Icons.inventory_2_outlined,
                        color: Shop.inkFaint,
                      ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeBadge(
                          label: product.isService ? 'خدمة' : 'منتج',
                          tone: tone,
                        ),
                        if (product.hasDiscount) ...[
                          const SizedBox(width: Gap.xs),
                          _TypeBadge(
                            label: product.discountPercent == null
                                ? 'خصم'
                                : '-${product.discountPercent}%',
                            tone: Shop.clay,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      product.nameAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: product.isAvailable
                                ? Shop.ink
                                : Shop.inkFaint,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${product.price} ج.م',
                          style: MerchantTheme.figure(
                            size: 16,
                            color: product.isAvailable
                                ? Shop.sign
                                : Shop.inkFaint,
                          ),
                        ),
                        if (product.hasDiscount) ...[
                          const SizedBox(width: Gap.sm),
                          Text(
                            '${product.oldPrice} ج.م',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Shop.inkFaint,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!product.isService && product.stockQuantity != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'المخزون: ${product.stockQuantity}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Column(
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: product.isAvailable,
                      activeThumbColor: Shop.jade,
                      onChanged: _toggle,
                    ),
                  Text(
                    product.isAvailable ? 'متاح' : 'مخفي',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: Gap.xs),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Shop.inkFaint,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tone,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

void _openBulk(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const BulkImportPage()),
  );
}

void openProductEditor(BuildContext context, {ProductItem? product}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProductEditorPage(product: product),
    ),
  );
}
