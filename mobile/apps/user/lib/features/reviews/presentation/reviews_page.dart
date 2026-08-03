import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/presentation/login_page.dart';
import '../data/review_repository.dart';

class ReviewsPage extends ConsumerStatefulWidget {
  const ReviewsPage({
    required this.businessId,
    required this.businessName,
    required this.averageRating,
    required this.totalReviews,
    super.key,
  });

  final int businessId;
  final String businessName;
  final double averageRating;
  final int totalReviews;

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  late Future<List<BusinessReview>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BusinessReview>> _load() =>
      ref.read(reviewRepositoryProvider).list(widget.businessId);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التقييمات')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('أضف تقييمًا'),
        ),
        body: FutureBuilder<List<BusinessReview>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ReviewState(
                icon: Icons.cloud_off_outlined,
                title: 'تعذر تحميل التقييمات',
                action: _reload,
              );
            }
            final items = snapshot.data ?? const [];
            final own = items.where((item) => item.isOwn).firstOrNull;
            return RefreshIndicator(
              onRefresh: () async {
                final next = _load();
                setState(() => _future = next);
                await next;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _RatingSummary(
                      businessName: widget.businessName,
                      averageRating: widget.averageRating,
                      totalReviews: widget.totalReviews,
                      ownReview: own,
                      onEdit: own == null ? null : () => _openEditor(own),
                      onDelete: own == null ? null : () => _delete(own),
                    ),
                  ),
                  if (items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ReviewState(
                        icon: Icons.star_border_rounded,
                        title: 'لا توجد تقييمات بعد',
                        subtitle: 'كن أول من يشارك تجربته مع هذا المكان.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (_, index) =>
                            _ReviewCard(review: items[index]),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

  Future<void> _openEditor([BusinessReview? current]) async {
    final authenticated =
        ref.read(authControllerProvider).valueOrNull ?? false;
    if (!authenticated) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
      return;
    }

    var rating = current?.rating ?? 5;
    final comment = TextEditingController(text: current?.comment ?? '');
    var saving = false;
    String? errorMessage;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(current == null ? 'أضف تقييمك' : 'عدّل تقييمك'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      tooltip: '${index + 1} نجوم',
                      onPressed: saving
                          ? null
                          : () => setDialogState(() => rating = index + 1),
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                Text(
                  _ratingLabel(rating),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: comment,
                  enabled: !saving,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'اكتب تجربتك (اختياري)',
                    alignLabelWithHint: true,
                  ),
                ),
                if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() {
                        saving = true;
                        errorMessage = null;
                      });
                      try {
                        final repository =
                            ref.read(reviewRepositoryProvider);
                        if (current == null) {
                          await repository.create(
                            businessId: widget.businessId,
                            rating: rating,
                            comment: comment.text,
                          );
                        } else {
                          await repository.update(
                            reviewId: current.id,
                            businessId: widget.businessId,
                            rating: rating,
                            comment: comment.text,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        setDialogState(() {
                          saving = false;
                          errorMessage = ApiFailure.message(error);
                        });
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(current == null ? 'إرسال' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
    comment.dispose();
    if (saved == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال تقييمك، وسيظهر للجميع بعد مراجعته'),
        ),
      );
    }
  }

  Future<void> _delete(BusinessReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التقييم؟'),
        content: const Text('سيُحذف تقييمك وتعليقك نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(reviewRepositoryProvider).delete(review.id);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف تقييمك')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiFailure.message(error))),
        );
      }
    }
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({
    required this.businessName,
    required this.averageRating,
    required this.totalReviews,
    required this.ownReview,
    required this.onEdit,
    required this.onDelete,
  });

  final String businessName;
  final double averageRating;
  final int totalReviews;
  final BusinessReview? ownReview;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                businessName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                averageRating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              _Stars(value: averageRating),
              Text('$totalReviews تقييم معتمد'),
              if (ownReview != null) ...[
                const Divider(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ownReview!.isApproved
                            ? 'تقييمك منشور'
                            : 'تقييمك بانتظار المراجعة',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تعديل',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final BusinessReview review;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      review.username.isEmpty
                          ? '؟'
                          : review.username.characters.first,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.username.isEmpty ? 'مستخدم' : review.username,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        _Stars(value: review.rating.toDouble(), compact: true),
                      ],
                    ),
                  ),
                  if (review.isOwn && !review.isApproved)
                    const Chip(label: Text('بانتظار المراجعة')),
                ],
              ),
              if (review.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(review.comment, style: const TextStyle(height: 1.55)),
              ],
            ],
          ),
        ),
      );
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value, this.compact = false});
  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => Icon(
            index < value.round() ? Icons.star : Icons.star_border,
            color: Colors.amber.shade700,
            size: compact ? 18 : 24,
          ),
        ),
      );
}

class _ReviewState extends StatelessWidget {
  const _ReviewState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 62),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: action,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
      );
}

String _ratingLabel(int rating) => switch (rating) {
      1 => 'سيئ',
      2 => 'مقبول',
      3 => 'جيد',
      4 => 'جيد جدًا',
      _ => 'ممتاز',
    };
