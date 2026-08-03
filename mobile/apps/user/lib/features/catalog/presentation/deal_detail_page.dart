import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/config/environment.dart';
import '../../auth/presentation/login_page.dart';
import '../../directory/presentation/business_detail_page.dart';
import '../data/catalog_models.dart';

class DealDetailPage extends ConsumerStatefulWidget {
  const DealDetailPage({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<DealDetailPage> createState() => _DealDetailPageState();
}

class _DealDetailPageState extends ConsumerState<DealDetailPage> {
  late Future<DealDetail> _future;
  bool _claiming = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _future = _load();
    Future<void>.microtask(
      () => ref
          .read(catalogRepositoryProvider)
          .incrementDealView(widget.slug)
          .catchError((_) {}),
    );
  }

  Future<DealDetail> _load() =>
      ref.read(catalogRepositoryProvider).dealDetail(widget.slug);

  Future<void> _claim(DealDetail deal) async {
    final authenticated = ref.read(authControllerProvider).valueOrNull ?? false;
    if (!authenticated) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
      if (!mounted ||
          !(ref.read(authControllerProvider).valueOrNull ?? false)) {
        return;
      }
    }

    setState(() => _claiming = true);
    try {
      final claim =
          await ref.read(catalogRepositoryProvider).claimDeal(widget.slug);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.verified_rounded,
            size: 52,
            color: AppColors.primary,
          ),
          title: Text(_tr('تم حجز العرض', 'Deal claimed')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _tr(
                  'احتفظ برقم المطالبة وأظهره للنشاط عند استخدام العرض.',
                  'Keep this claim number and show it to the business.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  '#${claim.id}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${claim.id}'),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  _message(_tr('تم نسخ الرقم', 'Claim number copied'));
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(_tr('نسخ الرقم', 'Copy number')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tr('تم', 'Done')),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        _message(
          _tr(
            'تعذر حجز العرض. ربما انتهى أو وصلت للحد المسموح.',
            'Could not claim this deal. It may have expired or reached its limit.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _share(DealDetail deal) async {
    final origin = Uri.parse(Environment.apiBaseUrl).origin;
    final url = '$origin/deals/${deal.summary.slug}/';
    final text = '${deal.summary.title}\n$url';
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
              Text(
                _tr('مشاركة العرض', 'Share deal'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(_tr('نسخ الرابط', 'Copy link')),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted) _message(_tr('تم نسخ الرابط', 'Link copied'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy_rounded),
                title: Text(_tr('نسخ العرض كاملًا', 'Copy deal details')),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted) {
                    _message(_tr('تم نسخ تفاصيل العرض', 'Deal details copied'));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DealDetail>(
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
              body: _ErrorState(
                isArabic: _isArabic,
                onRetry: () => setState(() => _future = _load()),
              ),
            );
          }

          final deal = snapshot.data!;
          return Scaffold(
            backgroundColor: AppColors.background,
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 310,
                  title: Text(_tr('تفاصيل العرض', 'Deal details')),
                  actions: [
                    IconButton(
                      tooltip: _tr('مشاركة', 'Share'),
                      onPressed: () => _share(deal),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _DealHero(deal: deal, isArabic: _isArabic),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
                  sliver: SliverList.list(
                    children: [
                      _DealHeading(deal: deal, isArabic: _isArabic),
                      const SizedBox(height: 14),
                      _DealPriceCard(deal: deal, isArabic: _isArabic),
                      const SizedBox(height: 14),
                      _DealStatusCard(deal: deal, isArabic: _isArabic),
                      if (deal.description.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _Section(
                          title: _tr('تفاصيل العرض', 'About this deal'),
                          icon: Icons.description_outlined,
                          child: Text(
                            deal.description,
                            style: const TextStyle(height: 1.7),
                          ),
                        ),
                      ],
                      if (deal.terms.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _Section(
                          title: _tr('الشروط والأحكام', 'Terms & conditions'),
                          icon: Icons.rule_outlined,
                          child: Text(
                            deal.terms,
                            style: const TextStyle(height: 1.7),
                          ),
                        ),
                      ],
                      if (deal.summary.businessName.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _BusinessCard(deal: deal, isArabic: _isArabic),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed:
                    deal.canClaim && !_claiming ? () => _claim(deal) : null,
                icon: _claiming
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.redeem_rounded),
                label: Text(
                  deal.isExpired
                      ? _tr('انتهى العرض', 'Deal expired')
                      : deal.isUpcoming
                          ? _tr('العرض يبدأ قريبًا', 'Deal starts soon')
                          : !deal.summary.isValid
                              ? _tr('العرض غير متاح', 'Deal unavailable')
                              : _tr('احجز العرض الآن', 'Claim deal now'),
                ),
              ),
            ),
          );
        },
      );
}

class _DealHero extends StatelessWidget {
  const _DealHero({required this.deal, required this.isArabic});

  final DealDetail deal;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final image = deal.summary.image;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image == null || image.isEmpty)
          const ColoredBox(
            color: AppColors.primary,
            child: Icon(
              Icons.local_offer_outlined,
              size: 84,
              color: Colors.white,
            ),
          )
        else
          Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.primary,
              child: Icon(
                Icons.local_offer_outlined,
                size: 84,
                color: Colors.white,
              ),
            ),
          ),
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
          bottom: 18,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroBadge(
                icon: Icons.local_offer_rounded,
                label: deal.summary.typeLabel,
              ),
              if (deal.summary.isFeatured)
                _HeroBadge(
                  icon: Icons.workspace_premium_rounded,
                  label: isArabic ? 'عرض مميز' : 'Featured',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class _DealHeading extends StatelessWidget {
  const _DealHeading({required this.deal, required this.isArabic});

  final DealDetail deal;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deal.summary.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(
                  isArabic
                      ? '${deal.viewCount} مشاهدة'
                      : '${deal.viewCount} views',
                ),
              ),
              Chip(
                avatar: Icon(
                  deal.canClaim
                      ? Icons.check_circle_outline_rounded
                      : Icons.block_rounded,
                  size: 18,
                  color: deal.canClaim ? Colors.green : Colors.red,
                ),
                label: Text(
                  deal.canClaim
                      ? (isArabic ? 'متاح الآن' : 'Available now')
                      : (isArabic ? 'غير متاح حاليًا' : 'Unavailable'),
                ),
              ),
            ],
          ),
        ],
      );
}

class _DealPriceCard extends StatelessWidget {
  const _DealPriceCard({required this.deal, required this.isArabic});

  final DealDetail deal;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final summary = deal.summary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: summary.hasPrice
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _money(summary.finalPrice!, isArabic),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (summary.discountPercentage > 0)
                      Badge(
                        label: Text(
                          '${summary.discountPercentage.toStringAsFixed(0)}%',
                        ),
                      ),
                  ],
                ),
                if (summary.hasDiscount) ...[
                  const SizedBox(height: 5),
                  Text(
                    _money(summary.originalPrice!, isArabic),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                  ),
                ],
                if (deal.savingsAmount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    isArabic
                        ? 'وفّر ${_money(deal.savingsAmount, true)}'
                        : 'Save ${_money(deal.savingsAmount, false)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            )
          : Text(
              summary.typeLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
    );
  }
}

class _DealStatusCard extends StatelessWidget {
  const _DealStatusCard({required this.deal, required this.isArabic});

  final DealDetail deal;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat(
      isArabic ? 'd MMMM y' : 'MMM d, y',
      isArabic ? 'ar' : 'en',
    );
    final items = <_StatusData>[
      _StatusData(
        Icons.schedule_rounded,
        deal.isExpired
            ? (isArabic ? 'انتهى العرض' : 'Expired')
            : deal.isUpcoming
                ? (isArabic ? 'يبدأ قريبًا' : 'Starts soon')
                : (isArabic
                    ? 'متبقي ${deal.summary.daysRemaining} يوم'
                    : '${deal.summary.daysRemaining} days left'),
      ),
      if (deal.endDate != null)
        _StatusData(
          Icons.event_outlined,
          isArabic
              ? 'حتى ${formatter.format(deal.endDate!.toLocal())}'
              : 'Until ${formatter.format(deal.endDate!.toLocal())}',
        ),
      if (deal.summary.isLimited)
        _StatusData(
          Icons.confirmation_number_outlined,
          isArabic
              ? 'متاح ${deal.summary.remainingUses} استخدام'
              : '${deal.summary.remainingUses} claims left',
        ),
      _StatusData(
        Icons.person_outline_rounded,
        isArabic
            ? 'بحد أقصى ${deal.maxUsesPerUser} للمستخدم'
            : 'Up to ${deal.maxUsesPerUser} per user',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        children: items
            .map(
              (item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text(item.text),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _StatusData {
  const _StatusData(this.icon, this.text);
  final IconData icon;
  final String text;
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.deal, required this.isArabic});

  final DealDetail deal;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.storefront_rounded, color: AppColors.primary),
          ),
          title: Text(isArabic ? 'مقدم من' : 'Offered by'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              deal.summary.businessName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          trailing: deal.summary.businessSlug.isEmpty
              ? null
              : const Icon(Icons.chevron_left_rounded),
          onTap: deal.summary.businessSlug.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BusinessDetailPage(
                        slug: deal.summary.businessSlug,
                      ),
                    ),
                  ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.isArabic, required this.onRetry});

  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                isArabic ? 'تعذر تحميل العرض' : 'Could not load deal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'تحقق من الاتصال ثم حاول مرة أخرى'
                    : 'Check your connection and try again',
              ),
              const SizedBox(height: 18),
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

String _money(double value, bool isArabic) {
  final formatted = NumberFormat('#,##0.##', isArabic ? 'ar' : 'en').format(value);
  return isArabic ? '$formatted ج.م' : 'EGP $formatted';
}
