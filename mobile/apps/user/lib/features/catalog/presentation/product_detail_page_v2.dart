import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/config/environment.dart';
import '../../directory/presentation/business_detail_page.dart';
import '../data/catalog_models.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  late Future<ProductDetail> _future;
  var _selectedImage = 0;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _future = _load();
    Future<void>.microtask(
      () => ref
          .read(catalogRepositoryProvider)
          .incrementProductView(widget.slug)
          .catchError((_) {}),
    );
  }

  Future<ProductDetail> _load() =>
      ref.read(catalogRepositoryProvider).productDetail(widget.slug);

  @override
  Widget build(BuildContext context) => FutureBuilder<ProductDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(),
              body: _MessageState(
                title: _tr('تعذر تحميل المنتج', 'Could not load product'),
                subtitle: _tr(
                  'تحقق من الاتصال ثم حاول مرة أخرى',
                  'Check your connection and try again',
                ),
                onRetry: () => setState(() => _future = _load()),
              ),
            );
          }
          return _page(snapshot.data!);
        },
      );

  Widget _page(ProductDetail product) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_tr('تفاصيل ${product.typeLabel}', 'Product details')),
          actions: [
            IconButton(
              tooltip: _tr('مشاركة', 'Share'),
              onPressed: () => _share(product),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            _ProductGallery(
              product: product,
              selectedImage: _selectedImage,
              onSelectImage: (index) => setState(() => _selectedImage = index),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Heading(product: product, isArabic: _isArabic),
                  const SizedBox(height: 16),
                  _PriceCard(product: product, isArabic: _isArabic),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Section(
                      title: _tr('التفاصيل', 'Details'),
                      icon: Icons.description_outlined,
                      child: Text(
                        product.description,
                        style: const TextStyle(height: 1.7),
                      ),
                    ),
                  ],
                  if (product.hasDelivery) ...[
                    const SizedBox(height: 16),
                    _DeliveryCard(product: product, isArabic: _isArabic),
                  ],
                  if (product.hasBusiness) ...[
                    const SizedBox(height: 16),
                    _BusinessCard(product: product, isArabic: _isArabic),
                  ],
                  const SizedBox(height: 22),
                  _RelatedProducts(product: product, isArabic: _isArabic),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: product.hasBusiness
            ? SafeArea(
                minimum: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BusinessDetailPage(slug: product.businessSlug),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_rounded),
                  label: Text(
                    product.productType == 'service'
                        ? _tr('تواصل مع مقدم الخدمة', 'Contact provider')
                        : _tr('تواصل مع النشاط', 'Contact business'),
                  ),
                ),
              )
            : null,
      );

  Future<void> _share(ProductDetail product) async {
    final origin = Uri.parse(Environment.apiBaseUrl).origin;
    final url = '$origin/products/${product.slug}/';
    await Clipboard.setData(
      ClipboardData(text: '${product.name}\n$url'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('تم نسخ رابط المنتج', 'Product link copied'))),
    );
  }
}

class _ProductGallery extends StatelessWidget {
  const _ProductGallery({
    required this.product,
    required this.selectedImage,
    required this.onSelectImage,
  });

  final ProductDetail product;
  final int selectedImage;
  final ValueChanged<int> onSelectImage;

  @override
  Widget build(BuildContext context) {
    final images = product.images;
    final safeIndex = selectedImage < images.length ? selectedImage : 0;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: InkWell(
            onTap: images.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _GalleryViewer(
                          images: images,
                          initialIndex: safeIndex,
                        ),
                      ),
                    ),
            child: ColoredBox(
              color: AppColors.surfaceMuted,
              child: images.isEmpty
                  ? Icon(
                      product.productType == 'service'
                          ? Icons.design_services_outlined
                          : Icons.inventory_2_outlined,
                      size: 82,
                      color: AppColors.primary,
                    )
                  : Hero(
                      tag: 'product-image-${images[safeIndex].url}',
                      child: Image.network(
                        images[safeIndex].url,
                        fit: BoxFit.cover,
                        semanticLabel: images[safeIndex].altText,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 72),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 92,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => InkWell(
                onTap: () => onSelectImage(index),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 76,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: index == safeIndex
                          ? AppColors.primary
                          : AppColors.border,
                      width: index == safeIndex ? 2.5 : 1,
                    ),
                  ),
                  child: Image.network(
                    images[index].url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({required this.images, required this.initialIndex});

  final List<ProductImage> images;
  final int initialIndex;

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / ${widget.images.length}'),
        ),
        body: PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (_, index) => InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Hero(
                tag: 'product-image-${widget.images[index].url}',
                child: Image.network(
                  widget.images[index].url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.product, required this.isArabic});

  final ProductDetail product;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (product.isFeatured)
                const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  product.productType == 'service'
                      ? Icons.design_services_outlined
                      : Icons.inventory_2_outlined,
                  size: 18,
                ),
                label: Text(
                  isArabic
                      ? product.typeLabel
                      : product.productType == 'service'
                          ? 'Service'
                          : 'Product',
                ),
              ),
              Chip(
                avatar: Icon(
                  product.canOrder
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 18,
                  color: product.canOrder ? Colors.green : Colors.red,
                ),
                label: Text(
                  product.canOrder
                      ? (isArabic ? 'متاح الآن' : 'Available now')
                      : (isArabic ? 'غير متاح حاليًا' : 'Unavailable'),
                ),
              ),
              if (product.viewCount > 0)
                Chip(
                  avatar: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(
                    isArabic
                        ? '${product.viewCount} مشاهدة'
                        : '${product.viewCount} views',
                  ),
                ),
            ],
          ),
        ],
      );
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.product, required this.isArabic});

  final ProductDetail product;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _money(product.price, isArabic),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (product.hasDiscount)
                  Badge(
                    label: Text(
                      isArabic
                          ? 'خصم ${product.discountPercentage.toStringAsFixed(0)}٪'
                          : '${product.discountPercentage.toStringAsFixed(0)}% off',
                    ),
                  ),
              ],
            ),
            if (product.hasDiscount) ...[
              const SizedBox(height: 4),
              Text(
                _money(product.oldPrice!, isArabic),
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
            ],
            if (product.productType == 'product' &&
                product.stockQuantity != null) ...[
              const SizedBox(height: 12),
              Text(
                product.stockQuantity! > 0
                    ? (isArabic
                        ? 'متبقي ${product.stockQuantity} في المخزون'
                        : '${product.stockQuantity} left in stock')
                    : (isArabic ? 'نفد المخزون' : 'Out of stock'),
              ),
            ],
          ],
        ),
      );
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.product, required this.isArabic});

  final ProductDetail product;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => _Section(
        title: isArabic ? 'التوصيل' : 'Delivery',
        icon: Icons.local_shipping_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.deliveryCost == null || product.deliveryCost == 0
                  ? (isArabic ? 'التوصيل مجاني' : 'Free delivery')
                  : (isArabic
                      ? 'تكلفة التوصيل: ${_money(product.deliveryCost!, true)}'
                      : 'Delivery cost: ${_money(product.deliveryCost!, false)}'),
            ),
            if (product.deliveryTime.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'المدة المتوقعة: ${product.deliveryTime}'
                    : 'Estimated time: ${product.deliveryTime}',
              ),
            ],
          ],
        ),
      );
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.product, required this.isArabic});

  final ProductDetail product;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(
            child: Text(
              product.businessName.characters.first,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(isArabic ? 'مقدم بواسطة' : 'Provided by'),
          subtitle: Text(product.businessName),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BusinessDetailPage(slug: product.businessSlug),
            ),
          ),
        ),
      );
}

class _RelatedProducts extends ConsumerWidget {
  const _RelatedProducts({required this.product, required this.isArabic});

  final ProductDetail product;
  final bool isArabic;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<List<ProductSummary>>(
        future: ref.read(catalogRepositoryProvider).searchProducts(
              product.name,
              productType: product.productType,
              ordering: '-is_featured',
              pageSize: 8,
            ),
        builder: (context, snapshot) {
          final items = (snapshot.data ?? const <ProductSummary>[])
              .where((item) => item.slug != product.slug)
              .take(6)
              .toList(growable: false);
          if (snapshot.connectionState != ConnectionState.done || items.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'منتجات وخدمات مشابهة' : 'Similar products & services',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return SizedBox(
                      width: 170,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => ProductDetailPage(slug: item.slug),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: item.image == null
                                    ? const ColoredBox(
                                        color: AppColors.surfaceMuted,
                                        child: Icon(Icons.inventory_2_outlined),
                                      )
                                    : Image.network(item.image!, fit: BoxFit.cover),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isArabic
                                          ? '${item.price} ج.م'
                                          : '${item.price} EGP',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 64),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

String _money(double value, bool isArabic) =>
    '${NumberFormat('#,##0.##', isArabic ? 'ar' : 'en').format(value)} ${isArabic ? 'ج.م' : 'EGP'}';
