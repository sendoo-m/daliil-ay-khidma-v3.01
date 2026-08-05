import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'models.dart';

/// **العنصر المميِّز: لافتة المحل.**
///
/// شريط غامق يحمل اسم النشاط وتقييمه وحالته، زي لافتة المحل في الشارع.
/// هو أول ما يشوفه التاجر، وثابت عبر الشاشات — لأنه الحاجة اللي بيفتح
/// التطبيق عشانها، وكمان بيحل مشكلة تعدد المحلات: اسم المحل قدامه دايمًا
/// فمش هيعدّل حاجة في المحل الغلط.
class ShopSign extends StatelessWidget {
  const ShopSign({
    super.key,
    required this.shop,
    this.rating,
    this.compact = false,
    this.onSwitch,
  });

  final ShopSummary shop;
  final double? rating;

  /// نسخة مضغوطة للشاشات الداخلية — اللافتة الكاملة للرئيسية فقط.
  final bool compact;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Shop.sign,
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        compact ? Gap.md : Gap.lg,
        Gap.lg,
        compact ? Gap.md : Gap.lg,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    shop.nameAr,
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                          color: Colors.white,
                          fontSize: compact ? 18 : 26,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onSwitch != null) ...[
                  const SizedBox(width: Gap.sm),
                  _SwitchButton(onTap: onSwitch!),
                ],
              ],
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (rating != null && rating! > 0) RatingStars(rating: rating!),
                if (shop.isVerified)
                  const _SignChip(
                    label: 'موثّق',
                    icon: Icons.verified_outlined,
                    tone: Shop.jade,
                  ),
                if (shop.isFeatured)
                  const _SignChip(
                    label: 'مميَّز',
                    icon: Icons.workspace_premium_outlined,
                    tone: Shop.brass,
                  ),
                if (!shop.isActive)
                  const _SignChip(
                    label: 'موقوف',
                    icon: Icons.pause_circle_outline,
                    tone: Shop.clay,
                  ),
              ],
            ),
            if (!compact && shop.placeLine.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Text(
                shop.placeLine,
                style: const TextStyle(
                  color: Color(0xFF9DB5AB),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Shop.signSoft,
      borderRadius: BorderRadius.circular(Radii.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'بدّل',
                style: TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignChip extends StatelessWidget {
  const _SignChip({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// نجوم نحاسية. النحاسي أدفأ لون في الواجهة وأندره — محجوز للتقييم
/// والتميّز، فيقرأ التاجر تقييمه بلمحة.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 15,
    this.showNumber = true,
    this.onDark = true,
  });

  final double rating;
  final double size;
  final bool showNumber;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && hasHalf
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded),
            size: size,
            color: i < full || (i == full && hasHalf)
                ? Shop.brass
                : (onDark ? Colors.white24 : Shop.rule),
          ),
        if (showNumber) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: onDark ? Colors.white : Shop.ink,
              fontSize: size - 2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// بطاقة عمل: رقم كبير + الفعل المطلوب. تقود بالفعل لا بالوصف.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.count,
    required this.label,
    required this.action,
    required this.tone,
    this.onTap,
  });

  final int count;
  final String label;
  final String action;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Shop.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onTap,
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
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Text(
                  '$count',
                  style: MerchantTheme.figure(size: 22, color: tone),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      action,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tone,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 22,
                color: Shop.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          Text(text, style: MerchantTheme.eyebrow),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ShopEmpty extends StatelessWidget {
  const ShopEmpty({super.key, required this.title, this.hint, this.action});

  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                hint!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Gap.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ShopError extends StatelessWidget {
  const ShopError({super.key, required this.failure, this.onRetry});

  final ApiFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              failure.message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (failure.isRetryable && onRetry != null) ...[
              const SizedBox(height: Gap.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('جرّب تاني'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(Gap.xl),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Shop.sign),
          ),
        ),
      );
}

/// "من ٣ أيام" — أوضح للتاجر من تاريخ كامل.
String timeAgo(DateTime? when) {
  if (when == null) return '';
  final days = DateTime.now().difference(when).inDays;
  if (days <= 0) return 'النهارده';
  if (days == 1) return 'إمبارح';
  if (days < 7) return 'من $days أيام';
  if (days < 30) return 'من ${(days / 7).floor()} أسابيع';
  if (days < 365) return 'من ${(days / 30).floor()} شهور';
  return 'من ${(days / 365).floor()} سنة';
}
