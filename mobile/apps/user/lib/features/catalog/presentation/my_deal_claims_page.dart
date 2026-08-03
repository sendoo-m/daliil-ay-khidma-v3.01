import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../data/deal_claim.dart';
import 'deal_detail_page.dart';

class MyDealClaimsPage extends ConsumerStatefulWidget {
  const MyDealClaimsPage({super.key});

  @override
  ConsumerState<MyDealClaimsPage> createState() => _MyDealClaimsPageState();
}

class _MyDealClaimsPageState extends ConsumerState<MyDealClaimsPage> {
  late Future<List<DealClaim>> _future = _load();
  int _filter = 0;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;

  Future<List<DealClaim>> _load() =>
      ref.read(catalogRepositoryProvider).dealClaims();

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surfaceMuted,
        appBar: AppBar(title: Text(_tr('عروضي المحجوزة', 'My deal claims'))),
        body: FutureBuilder<List<DealClaim>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.cloud_off_outlined,
                title: _tr('تعذر تحميل الحجوزات', 'Could not load claims'),
                actionLabel: _tr('إعادة المحاولة', 'Try again'),
                onAction: _refresh,
              );
            }
            final all = snapshot.data ?? const <DealClaim>[];
            final claims = all.where((claim) {
              if (_filter == 1) return !claim.isUsed && !claim.isExpired;
              if (_filter == 2) return claim.isUsed;
              if (_filter == 3) return claim.isExpired;
              return true;
            }).toList(growable: false);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: _Summary(claims: all, isArabic: _isArabic),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 52,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _filterChip(0, _tr('الكل', 'All')),
                          _filterChip(1, _tr('نشطة', 'Active')),
                          _filterChip(2, _tr('مستخدمة', 'Used')),
                          _filterChip(3, _tr('منتهية', 'Expired')),
                        ],
                      ),
                    ),
                  ),
                  if (claims.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessageState(
                        icon: Icons.confirmation_number_outlined,
                        title: _tr(
                          'لا توجد حجوزات في هذا القسم',
                          'No claims in this section',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: claims.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _ClaimCard(
                          claim: claims[index],
                          isArabic: _isArabic,
                          onCopy: () => _copyCode(claims[index].id),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

  Widget _filterChip(int value, String label) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          selected: _filter == value,
          label: Text(label),
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Future<void> _copyCode(int id) async {
    await Clipboard.setData(ClipboardData(text: '$id'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('تم نسخ رقم المطالبة', 'Claim number copied'))),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.claims, required this.isArabic});

  final List<DealClaim> claims;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final active = claims.where((claim) => !claim.isUsed && !claim.isExpired).length;
    final used = claims.where((claim) => claim.isUsed).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _Stat(value: '${claims.length}', label: isArabic ? 'الإجمالي' : 'Total')),
          Expanded(child: _Stat(value: '$active', label: isArabic ? 'نشطة' : 'Active')),
          Expanded(child: _Stat(value: '$used', label: isArabic ? 'مستخدمة' : 'Used')),
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
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      );
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.isArabic, required this.onCopy});

  final DealClaim claim;
  final bool isArabic;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final status = claim.isUsed
        ? (isArabic ? 'تم الاستخدام' : 'Used')
        : claim.isExpired
            ? (isArabic ? 'منتهي' : 'Expired')
            : (isArabic ? 'جاهز للاستخدام' : 'Ready to use');
    final date = claim.claimedAt == null
        ? '—'
        : DateFormat('d MMM y', isArabic ? 'ar' : 'en').format(claim.claimedAt!.toLocal());
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: claim.deal.slug.isEmpty
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DealDetailPage(slug: claim.deal.slug),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      claim.deal.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(label: Text(status), visualDensity: VisualDensity.compact),
                ],
              ),
              if (claim.deal.businessName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(claim.deal.businessName, style: const TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isArabic ? 'رقم المطالبة: ${claim.id}' : 'Claim number: ${claim.id}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: isArabic ? 'نسخ' : 'Copy',
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isArabic ? 'تم الحجز في $date' : 'Claimed on $date',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 60, color: AppColors.primary),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}
