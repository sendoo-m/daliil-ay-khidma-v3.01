import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

enum _ReviewFilter { all, needsReply, urgent, replied }

class ReviewsPage extends ConsumerStatefulWidget {
  const ReviewsPage({super.key});

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  final _search = TextEditingController();
  _ReviewFilter _filter = _ReviewFilter.all;
  int? _rating;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // نريد القائمة كاملة هنا ثم نطبق الفلاتر محليًا، لذلك لا نستخدم
    // فلتر provider القديم الخاص بـ "مستني رد".
    ref.read(reviewsNeedReplyOnlyProvider.notifier).state = false;
    final reviews = ref.watch(reviewsProvider);

    return reviews.when(
      loading: () => const Loading(),
      error: (e, _) => ShopError(
        failure: ApiFailure.from(e),
        onRetry: () => ref.invalidate(reviewsProvider),
      ),
      data: (items) {
        final visible = _applyFilters(items);
        return RefreshIndicator(
          color: Shop.sign,
          onRefresh: () async => ref.invalidate(reviewsProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _summary(context, items)),
              SliverToBoxAdapter(child: _controls(context)),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ShopEmpty(
                    title: items.isEmpty
                        ? 'لسه مفيش تقييمات'
                        : 'مفيش تقييمات مطابقة',
                    hint: items.isEmpty
                        ? 'أول ما عميل يقيّم نشاطك هيظهر هنا.'
                        : 'جرّب تغيّر البحث أو الفلاتر.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.md,
                    Gap.md,
                    Gap.md,
                    Gap.xl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
                    itemBuilder: (context, index) =>
                        _ReviewCard(review: visible[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<ReviewItem> _applyFilters(List<ReviewItem> items) {
    final query = _search.text.trim().toLowerCase();
    final result = items.where((review) {
      if (_rating != null && review.rating != _rating) return false;
      switch (_filter) {
        case _ReviewFilter.needsReply:
          if (!review.needsReply) return false;
          break;
        case _ReviewFilter.urgent:
          if (!review.isUrgent) return false;
          break;
        case _ReviewFilter.replied:
          if (review.reply == null) return false;
          break;
        case _ReviewFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return review.reviewerName.toLowerCase().contains(query) ||
          review.comment.toLowerCase().contains(query) ||
          review.businessName.toLowerCase().contains(query) ||
          (review.reply?.comment.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);

    result.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      if (a.needsReply != b.needsReply) return a.needsReply ? -1 : 1;
      return (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000));
    });
    return result;
  }

  Widget _summary(BuildContext context, List<ReviewItem> items) {
    final total = items.length;
    final pending = items.where((r) => r.needsReply).length;
    final urgent = items.where((r) => r.isUrgent).length;
    final avg = total == 0
        ? 0.0
        : items.fold<int>(0, (sum, item) => sum + item.rating) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _Metric(label: 'التقييمات', value: '$total')),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _Metric(
                  label: 'المتوسط',
                  value: avg.toStringAsFixed(1),
                  icon: Icons.star_rounded,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(child: _Metric(label: 'مستني رد', value: '$pending')),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _Metric(
                  label: 'عاجل',
                  value: '$urgent',
                  tone: urgent > 0 ? Shop.clay : Shop.inkSoft,
                ),
              ),
            ],
          ),
          if (urgent > 0) ...[
            const SizedBox(height: Gap.sm),
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: Shop.clay.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: Shop.clay.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.priority_high_rounded, color: Shop.clay),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'عندك $urgent تقييم منخفض بدون رد. الرد السريع يوضح للعملاء إنك متابع.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) {
    return Container(
      color: Shop.surface,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'ابحث باسم العميل أو نص التقييم',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: _search.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Pill(
                  label: 'الكل',
                  active: _filter == _ReviewFilter.all,
                  onTap: () => setState(() => _filter = _ReviewFilter.all),
                ),
                const SizedBox(width: Gap.sm),
                _Pill(
                  label: 'مستني رد',
                  active: _filter == _ReviewFilter.needsReply,
                  onTap: () =>
                      setState(() => _filter = _ReviewFilter.needsReply),
                ),
                const SizedBox(width: Gap.sm),
                _Pill(
                  label: 'عاجل',
                  active: _filter == _ReviewFilter.urgent,
                  tone: Shop.clay,
                  onTap: () => setState(() => _filter = _ReviewFilter.urgent),
                ),
                const SizedBox(width: Gap.sm),
                _Pill(
                  label: 'تم الرد',
                  active: _filter == _ReviewFilter.replied,
                  tone: Shop.jade,
                  onTap: () => setState(() => _filter = _ReviewFilter.replied),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RatingPill(
                  label: 'كل النجوم',
                  active: _rating == null,
                  onTap: () => setState(() => _rating = null),
                ),
                for (var stars = 5; stars >= 1; stars--) ...[
                  const SizedBox(width: Gap.sm),
                  _RatingPill(
                    label: '$stars',
                    active: _rating == stars,
                    stars: stars,
                    onTap: () => setState(() => _rating = stars),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.icon,
    this.tone = Shop.sign,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.md),
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Shop.rule),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: tone),
                const SizedBox(width: 3),
              ],
              Text(value, style: MerchantTheme.figure(size: 18, color: tone)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    this.tone = Shop.sign,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? tone : Colors.transparent,
          border: Border.all(color: active ? tone : Shop.rule),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? Colors.white : Shop.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.stars,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? stars;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Shop.brass.withValues(alpha: 0.14) : Colors.transparent,
          border: Border.all(color: active ? Shop.brass : Shop.rule),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          children: [
            if (stars != null) ...[
              const Icon(Icons.star_rounded, size: 15, color: Shop.brass),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? Shop.brass : Shop.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({required this.review});

  final ReviewItem review;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  final _controller = TextEditingController();
  bool _writing = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.review.reply?.comment ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.length < 2) {
      setState(() => _error = 'اكتب رد أطول شوية.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(merchantActionsProvider)
          .replyToReview(widget.review.id, value);
      if (mounted) {
        setState(() => _writing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اتبعت الرد')),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: review.isUrgent
              ? Shop.clay.withValues(alpha: 0.45)
              : Shop.rule,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RatingStars(
                      rating: review.rating.toDouble(),
                      size: 16,
                      showNumber: false,
                      onDark: false,
                    ),
                    if (review.isUrgent) ...[
                      const SizedBox(width: Gap.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Shop.clay.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: const Text(
                          'يحتاج رد',
                          style: TextStyle(fontSize: 11, color: Shop.clay),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(timeAgo(review.createdAt), style: text.labelSmall),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(review.reviewerName, style: text.titleMedium),
                if (review.businessName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(review.businessName, style: text.labelSmall),
                ],
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Text(review.comment, style: text.bodyMedium),
                ],
              ],
            ),
          ),
          if (review.reply != null && !_writing)
            _ExistingReply(
              comment: review.reply!.comment,
              onEdit: () => setState(() => _writing = true),
            ),
          if (review.reply == null && !_writing)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _writing = true),
                  icon: const Icon(Icons.reply_rounded, size: 17),
                  label: const Text('رد على العميل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: review.isUrgent ? Shop.clay : Shop.sign,
                    side: BorderSide(
                      color: review.isUrgent
                          ? Shop.clay.withValues(alpha: 0.4)
                          : Shop.rule,
                    ),
                  ),
                ),
              ),
            ),
          if (_writing) _replyEditor(context),
        ],
      ),
    );
  }

  Widget _replyEditor(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: const BoxDecoration(
        color: Shop.paper,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.card)),
        border: Border(top: BorderSide(color: Shop.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            maxLength: 600,
            decoration: const InputDecoration(
              hintText: 'ردك هيظهر تحت التقييم لكل اللي بيشوفوا نشاطك',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Gap.sm),
            Text(
              _error!,
              style: const TextStyle(color: Shop.clay, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                            _writing = false;
                            _error = null;
                            _controller.text =
                                widget.review.reply?.comment ?? '';
                          }),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.review.reply == null
                              ? 'ابعت الرد'
                              : 'حدّث الرد',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExistingReply extends StatelessWidget {
  const _ExistingReply({required this.comment, required this.onEdit});

  final String comment;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: const BoxDecoration(
        color: Shop.paper,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.card)),
        border: Border(top: BorderSide(color: Shop.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.subdirectory_arrow_left,
                size: 15,
                color: Shop.jade,
              ),
              const SizedBox(width: 6),
              Text(
                'ردك',
                style: MerchantTheme.eyebrow.copyWith(color: Shop.jade),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                child: const Text('تعديل'),
              ),
            ],
          ),
          Text(comment, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
