import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/business.dart';
import 'business_detail_page.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({required this.business, super.key});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final area = business.area;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BusinessDetailPage(slug: business.slug),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'business-logo-${business.slug}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox.square(
                    dimension: 82,
                    child: business.logo == null || business.logo!.isEmpty
                        ? const ColoredBox(
                            color: AppColors.primarySoft,
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 34,
                              color: AppColors.primary,
                            ),
                          )
                        : Image.network(
                            business.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: AppColors.primarySoft,
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 34,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        if (business.isVerified)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(start: 6),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 19,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    if (business.categoryName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        business.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    if (area.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              area,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _InfoPill(
                          icon: Icons.star_rounded,
                          label: business.rating.toStringAsFixed(1),
                          iconColor: AppColors.accentDark,
                        ),
                        if (business.totalReviews > 0)
                          _InfoPill(
                            icon: Icons.reviews_outlined,
                            label: '${business.totalReviews} تقييم',
                          ),
                        if (business.distanceKm != null)
                          _InfoPill(
                            icon: Icons.near_me_outlined,
                            label: '${business.distanceKm!.toStringAsFixed(1)} كم',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
}
