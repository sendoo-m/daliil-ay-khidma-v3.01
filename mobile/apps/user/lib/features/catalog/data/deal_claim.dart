import 'catalog_models.dart';

final class DealClaim {
  const DealClaim({
    required this.id,
    required this.deal,
    required this.claimedAt,
    required this.isUsed,
    this.usedAt,
    this.notes = '',
  });

  factory DealClaim.fromJson(Map<String, dynamic> json) => DealClaim(
        id: json['id'] as int? ?? 0,
        deal: DealSummary.fromJson(
          json['deal'] as Map<String, dynamic>? ?? const {},
        ),
        claimedAt: DateTime.tryParse('${json['claimed_at'] ?? ''}'),
        isUsed: json['is_used'] as bool? ?? false,
        usedAt: DateTime.tryParse('${json['used_at'] ?? ''}'),
        notes: json['notes'] as String? ?? '',
      );

  final int id;
  final DealSummary deal;
  final DateTime? claimedAt;
  final bool isUsed;
  final DateTime? usedAt;
  final String notes;

  bool get isExpired => !deal.isValid && !isUsed;
}
