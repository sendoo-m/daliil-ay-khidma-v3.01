import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/config/environment.dart';
import '../../auth/presentation/login_page.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/presentation/catalog_detail_pages.dart';
import '../../reviews/presentation/reviews_page.dart';
import '../data/business.dart';

class BusinessDetailPage extends ConsumerStatefulWidget {
  const BusinessDetailPage({required this.slug, super.key});
  final String slug;

  @override
  ConsumerState<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends ConsumerState<BusinessDetailPage> {
  late Future<Business> _future;
  bool _favorite = false;
  bool _savingFavorite = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _future = _load();
    Future<void>.microtask(
      () => ref.read(businessRepositoryProvider).incrementView(widget.slug).catchError((_) {}),
    );
  }

  Future<Business> _load() async {
    final business = await ref.read(businessRepositoryProvider).detail(widget.slug);
    _favorite = business.isFavorite;
    return business;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Business>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(),
              body: _MessageState(
                icon: Icons.cloud_off_outlined,
                title: t('تعذر تحميل بيانات النشاط', 'Could not load business'),
                actionLabel: t('إعادة المحاولة', 'Try again'),
                onAction: () => setState(() => _future = _load()),
              ),
            );
          }
          return _scaffold(snapshot.data!);
        },
      );

  Widget _scaffold(Business business) => Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 320,
              title: Text(business.displayName),
              actions: [
                IconButton(
                  tooltip: t('مشاركة', 'Share'),
                  onPressed: () => _shareBusiness(business),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
                IconButton(
                  tooltip: _favorite
                      ? t('إزالة من المفضلة', 'Remove from favorites')
                      : t('إضافة للمفضلة', 'Add to favorites'),
                  onPressed: _savingFavorite ? null : () => _toggleFavorite(business),
                  icon: _savingFavorite
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _BusinessHero(business: business),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
              sliver: SliverList.list(
                children: [
                  _OverviewCard(business: business, isArabic: _isArabic),
                  const SizedBox(height: 14),
                  _QuickActions(
                    business: business,
                    isArabic: _isArabic,
                    onLaunch: (uri) => _launchTracked(business, uri),
                    onDirections: () => _openDirections(business),
                  ),
                  if (business.description.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _Section(
                      title: t('عن النشاط', 'About'),
                      icon: Icons.info_outline_rounded,
                      child: Text(business.description, style: const TextStyle(height: 1.7)),
                    ),
                  ],
                  if (business.address.isNotEmpty || business.area.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Section(
                      title: t('العنوان', 'Address'),
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (business.address.isNotEmpty) Text(business.address),
                          if (business.area.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(business.area, style: const TextStyle(color: AppColors.muted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (business.workingHours.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Section(
                      title: t('ساعات العمل', 'Working hours'),
                      icon: Icons.schedule_outlined,
                      child: Text(business.workingHours, style: const TextStyle(height: 1.65)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _BusinessProducts(businessId: business.id, isArabic: _isArabic),
                  const SizedBox(height: 22),
                  _BusinessDeals(businessId: business.id, isArabic: _isArabic),
                  if (business.images.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _Gallery(images: business.images, isArabic: _isArabic),
                  ],
                  const SizedBox(height: 22),
                  _ReviewsEntry(business: business, isArabic: _isArabic),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _toggleFavorite(Business business) async {
    final authenticated = ref.read(authControllerProvider).valueOrNull ?? false;
    if (!authenticated) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
      return;
    }
    setState(() => _savingFavorite = true);
    try {
      final value = await ref.read(businessRepositoryProvider).toggleFavorite(business.id);
      if (!mounted) return;
      setState(() => _favorite = value);
      _message(value ? t('تمت الإضافة للمفضلة', 'Added to favorites') : t('تمت الإزالة من المفضلة', 'Removed from favorites'));
    } catch (_) {
      if (mounted) _message(t('تعذر تحديث المفضلة', 'Could not update favorites'));
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  Future<void> _shareBusiness(Business business) async {
    final origin = Uri.parse(Environment.apiBaseUrl).origin;
    final url = '$origin/business/${business.slug}/';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('مشاركة النشاط', 'Share business'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(t('نسخ الرابط', 'Copy link')),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted) _message(t('تم نسخ الرابط', 'Link copied'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded),
                title: Text(t('مشاركة عبر واتساب', 'Share on WhatsApp')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _launch(Uri.https('wa.me', '/', {'text': '${business.displayName}\n$url'}));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchTracked(Business business, Uri uri) async {
    ref.read(businessRepositoryProvider).incrementClick(business.slug).catchError((_) {});
    await _launch(uri);
  }

  Future<void> _openDirections(Business business) async {
    final uri = business.hasCoordinates
        ? Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'destination': '${business.latitude},${business.longitude}',
          })
        : _webUri(business.locationUrl);
    await _launchTracked(business, uri);
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _message(t('لا يوجد تطبيق مناسب لفتح الرابط', 'No app can open this link'));
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
}

class _BusinessHero extends StatelessWidget {
  const _BusinessHero({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final image = business.coverImage ?? business.logo;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image == null)
          const ColoredBox(color: AppColors.primary, child: Icon(Icons.storefront_rounded, size: 76, color: Colors.white))
        else
          Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.primary)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xD9000000)],
            ),
          ),
        ),
        PositionedDirectional(
          start: 18,
          end: 18,
          bottom: 18,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: business.logo == null
                      ? const Icon(Icons.storefront_rounded, color: AppColors.primary)
                      : Image.network(business.logo!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(business.displayName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
                      if (business.isVerified) const Padding(padding: EdgeInsetsDirectional.only(start: 6), child: Icon(Icons.verified_rounded, color: Colors.lightBlueAccent)),
                    ]),
                    if (business.categoryName.isNotEmpty) Text(business.categoryName, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.business, required this.isArabic});
  final Business business;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Expanded(child: _Stat(icon: Icons.star_rounded, value: business.rating.toStringAsFixed(1), label: isArabic ? 'التقييم' : 'Rating')),
            Expanded(child: _Stat(icon: Icons.reviews_outlined, value: '${business.totalReviews}', label: isArabic ? 'المراجعات' : 'Reviews')),
            Expanded(child: _Stat(icon: Icons.location_on_outlined, value: business.area.isEmpty ? '—' : business.area.split('،').first, label: isArabic ? 'المنطقة' : 'Area')),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.business, required this.isArabic, required this.onLaunch, required this.onDirections});
  final Business business;
  final bool isArabic;
  final Future<void> Function(Uri) onLaunch;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      if (business.phone.isNotEmpty) (icon: Icons.phone_rounded, label: isArabic ? 'اتصال' : 'Call', onTap: () => onLaunch(Uri(scheme: 'tel', path: business.phone))),
      if (business.whatsapp.isNotEmpty) (icon: Icons.chat_rounded, label: 'WhatsApp', onTap: () => onLaunch(Uri.https('wa.me', '/${_internationalPhone(business.whatsapp)}'))),
      if (business.hasCoordinates || business.locationUrl.isNotEmpty) (icon: Icons.directions_rounded, label: isArabic ? 'الاتجاهات' : 'Directions', onTap: onDirections),
      if (business.website.isNotEmpty) (icon: Icons.language_rounded, label: isArabic ? 'الموقع' : 'Website', onTap: () => onLaunch(_webUri(business.website))),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((action) => ActionChip(avatar: Icon(action.icon, size: 19, color: AppColors.primary), label: Text(action.label), onPressed: action.onTap)).toList(),
    );
  }
}

class _BusinessProducts extends ConsumerWidget {
  const _BusinessProducts({required this.businessId, required this.isArabic});
  final int businessId;
  final bool isArabic;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AsyncHorizontalSection<ProductSummary>(
        title: isArabic ? 'المنتجات والخدمات' : 'Products & services',
        icon: Icons.inventory_2_outlined,
        future: ref.read(catalogRepositoryProvider).searchProducts('', businessId: businessId, ordering: '-is_featured', pageSize: 8),
        emptyText: isArabic ? 'لا توجد منتجات أو خدمات حتى الآن' : 'No products or services yet',
        itemBuilder: (item) => _ProductCard(item: item, isArabic: isArabic),
      );
}

class _BusinessDeals extends ConsumerWidget {
  const _BusinessDeals({required this.businessId, required this.isArabic});
  final int businessId;
  final bool isArabic;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AsyncHorizontalSection<DealSummary>(
        title: isArabic ? 'العروض الحالية' : 'Current deals',
        icon: Icons.local_offer_outlined,
        future: ref.read(catalogRepositoryProvider).deals(businessId: businessId, pageSize: 8),
        emptyText: isArabic ? 'لا توجد عروض نشطة لهذا النشاط' : 'No active deals for this business',
        itemBuilder: (item) => _DealCard(item: item, isArabic: isArabic),
      );
}

class _AsyncHorizontalSection<T> extends StatelessWidget {
  const _AsyncHorizontalSection({required this.title, required this.icon, required this.future, required this.emptyText, required this.itemBuilder});
  final String title;
  final IconData icon;
  final Future<List<T>> future;
  final String emptyText;
  final Widget Function(T) itemBuilder;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
        future: future,
        builder: (context, snapshot) {
          final header = Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleLarge)]);
          if (snapshot.connectionState != ConnectionState.done) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, const SizedBox(height: 16), const Center(child: CircularProgressIndicator())]);
          final items = snapshot.data ?? const [];
          if (snapshot.hasError || items.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, const SizedBox(height: 10), Text(snapshot.hasError ? 'تعذر تحميل البيانات' : emptyText, style: const TextStyle(color: AppColors.muted))]);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            header,
            const SizedBox(height: 12),
            SizedBox(height: 230, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, index) => itemBuilder(items[index]))),
          ]);
        },
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.isArabic});
  final ProductSummary item;
  final bool isArabic;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductDetailPage(slug: item.slug))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: item.image == null ? const ColoredBox(color: AppColors.surfaceMuted, child: Icon(Icons.inventory_2_outlined, size: 44)) : Image.network(item.image!, fit: BoxFit.cover)),
              Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(item.numericPrice.isFinite ? '${item.price} ${isArabic ? 'ج.م' : 'EGP'}' : (isArabic ? 'السعر عند التواصل' : 'Contact for price'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              ])),
            ]),
          ),
        ),
      );
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.item, required this.isArabic});
  final DealSummary item;
  final bool isArabic;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DealDetailPage(slug: item.slug))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: item.image == null ? const ColoredBox(color: AppColors.primarySoft, child: Icon(Icons.local_offer_outlined, size: 48, color: AppColors.primary)) : Image.network(item.image!, fit: BoxFit.cover)),
              Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(isArabic ? 'متبقي ${item.daysRemaining} يوم' : '${item.daysRemaining} days left', style: const TextStyle(color: AppColors.muted)),
                if (item.discountPercentage > 0) Text('${item.discountPercentage.toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
              ])),
            ]),
          ),
        ),
      );
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.images, required this.isArabic});
  final List<BusinessImage> images;
  final bool isArabic;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isArabic ? 'معرض الصور' : 'Gallery', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(height: 180, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: images.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, index) => InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _GalleryViewer(images: images, initialIndex: index))), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(images[index].url, width: 250, fit: BoxFit.cover))))),
      ]);
}

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({required this.images, required this.initialIndex});
  final List<BusinessImage> images;
  final int initialIndex;
  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${_index + 1} / ${widget.images.length}')),
        body: PageView.builder(controller: _controller, itemCount: widget.images.length, onPageChanged: (value) => setState(() => _index = value), itemBuilder: (_, index) => InteractiveViewer(maxScale: 4, child: Center(child: Image.network(widget.images[index].url, fit: BoxFit.contain)))),
      );
}

class _ReviewsEntry extends StatelessWidget {
  const _ReviewsEntry({required this.business, required this.isArabic});
  final Business business;
  final bool isArabic;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const CircleAvatar(child: Icon(Icons.reviews_outlined)),
          title: Text(isArabic ? 'تقييمات الزوار' : 'Visitor reviews'),
          subtitle: Text(isArabic ? '${business.totalReviews} تقييم' : '${business.totalReviews} reviews'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewsPage(businessId: business.id, businessName: business.displayName, averageRating: business.rating, totalReviews: business.totalReviews))),
        ),
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
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium)]), const SizedBox(height: 12), child]),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.title, required this.actionLabel, required this.onAction});
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 60, color: AppColors.primary), const SizedBox(height: 14), Text(title), const SizedBox(height: 16), FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh_rounded), label: Text(actionLabel))])));
}

Uri _webUri(String value) {
  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) return parsed;
  return Uri.parse('https://$value');
}

String _internationalPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) return '20${digits.substring(1)}';
  return digits;
}

String _money(double value) => NumberFormat('#,##0.##').format(value);
