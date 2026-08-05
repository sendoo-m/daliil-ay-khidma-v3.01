import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider);
    final needReplyOnly = ref.watch(reviewsNeedReplyOnlyProvider);

    return Column(
      children: [
        _FilterBar(
          needReplyOnly: needReplyOnly,
          onChanged: (v) =>
              ref.read(reviewsNeedReplyOnlyProvider.notifier).state = v,
        ),
        Expanded(
          child: reviews.when(
            loading: () => const Loading(),
            error: (e, _) => ShopError(
              failure: ApiFailure.from(e),
              onRetry: () => ref.invalidate(reviewsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return ShopEmpty(
                  title: needReplyOnly
                      ? 'مفيش تقييم مستني رد'
                      : 'لسه مفيش تقييمات',
                  hint: needReplyOnly
                      ? 'رديت على كل حاجة. تمام.'
                      : 'أول ما عميل يقيّم محلك هيظهر هنا.',
                );
              }
              return RefreshIndicator(
                color: Shop.sign,
                onRefresh: () async => ref.invalidate(reviewsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(Gap.md),
                  itemCount: items.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: _ReviewCard(review: items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.needReplyOnly, required this.onChanged});

  final bool needReplyOnly;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.sm,
      ),
      decoration: const BoxDecoration(
        color: Shop.surface,
        border: Border(bottom: BorderSide(color: Shop.rule)),
      ),
      child: Row(
        children: [
          _Pill(
            label: 'الكل',
            active: !needReplyOnly,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: Gap.sm),
          _Pill(
            label: 'مستني رد',
            active: needReplyOnly,
            tone: Shop.clay,
            onTap: () => onChanged(true),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? tone : Colors.transparent,
          border: Border.all(color: active ? tone : Shop.rule),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            color: active ? Colors.white : Shop.inkSoft,
          ),
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
    final text = _controller.text.trim();
    if (text.length < 2) {
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
          .replyToReview(widget.review.id, text);
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
    final r = widget.review;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: r.isUrgent ? Shop.clay.withValues(alpha: 0.4) : Shop.rule,
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
                      rating: r.rating.toDouble(),
                      size: 16,
                      showNumber: false,
                      onDark: false,
                    ),
                    const Spacer(),
                    Text(timeAgo(r.createdAt), style: text.labelSmall),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(r.reviewerName, style: text.titleMedium),
                if (r.comment.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Text(r.comment, style: text.bodyMedium),
                ],
              ],
            ),
          ),

          if (r.reply != null && !_writing)
            _ExistingReply(
              comment: r.reply!.comment,
              onEdit: () => setState(() => _writing = true),
            ),

          if (r.reply == null && !_writing)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _writing = true),
                  icon: const Icon(Icons.reply, size: 17),
                  label: const Text('رد على العميل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: r.isUrgent ? Shop.clay : Shop.sign,
                    side: BorderSide(
                      color: r.isUrgent
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
              hintText: 'ردك هيظهر تحت التقييم لكل اللي بيشوفوا محلك',
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
              const Icon(Icons.subdirectory_arrow_left, size: 15, color: Shop.jade),
              const SizedBox(width: 6),
              Text(
                'ردك',
                style: MerchantTheme.eyebrow.copyWith(color: Shop.jade),
              ),
              const Spacer(),
              InkWell(
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'تعديل',
                    style: TextStyle(fontSize: 12.5, color: Shop.inkSoft),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(comment, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
