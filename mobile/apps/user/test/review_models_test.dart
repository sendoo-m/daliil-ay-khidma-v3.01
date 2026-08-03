import 'package:dalil_app/features/reviews/data/review_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses review ownership and moderation state', () {
    final review = BusinessReview.fromJson({
      'id': 14,
      'rating': 4,
      'comment': 'تجربة جيدة',
      'user_name': 'أحمد علي',
      'is_approved': false,
      'is_own': true,
      'created_at': '2026-07-23T18:30:00Z',
    });

    expect(review.id, 14);
    expect(review.rating, 4);
    expect(review.username, 'أحمد علي');
    expect(review.isApproved, isFalse);
    expect(review.isOwn, isTrue);
    expect(review.createdAt, isNotNull);
  });

  test('falls back safely for incomplete review data', () {
    final review = BusinessReview.fromJson({
      'id': 2,
      'user_username': 'visitor',
    });

    expect(review.rating, 0);
    expect(review.comment, isEmpty);
    expect(review.username, 'visitor');
    expect(review.isOwn, isFalse);
  });
}
