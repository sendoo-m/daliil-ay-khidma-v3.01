import 'package:dio/dio.dart';

enum ActivityType { review, favorite, dealClaim }

ActivityType _typeFromJson(String? value) => switch (value) {
      'review' => ActivityType.review,
      'favorite' => ActivityType.favorite,
      'deal_claim' => ActivityType.dealClaim,
      _ => ActivityType.favorite,
    };

final class ActivityEntry {
  const ActivityEntry({
    required this.type,
    required this.createdAt,
    required this.businessName,
    required this.businessSlug,
    this.businessLogo,
    this.rating,
    this.dealTitle,
    this.dealSlug,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        type: _typeFromJson(json['type'] as String?),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        businessName: json['business_name'] as String? ?? '',
        businessSlug: json['business_slug'] as String? ?? '',
        businessLogo: json['business_logo'] as String?,
        rating: json['rating'] as int?,
        dealTitle: json['deal_title'] as String?,
        dealSlug: json['deal_slug'] as String?,
      );

  final ActivityType type;
  final DateTime createdAt;
  final String businessName;
  final String businessSlug;
  final String? businessLogo;
  final int? rating;
  final String? dealTitle;
  final String? dealSlug;
}

final class ActivityRepository {
  ActivityRepository(this._dio);
  final Dio _dio;

  Future<List<ActivityEntry>> recent() async {
    final response = await _dio.get<Map<String, dynamic>>('profile/activity/');
    final results = response.data?['results'] as List<dynamic>? ?? const [];
    return results
        .cast<Map<String, dynamic>>()
        .map(ActivityEntry.fromJson)
        .toList(growable: false);
  }
}
