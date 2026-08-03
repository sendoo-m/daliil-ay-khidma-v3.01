import 'package:dalil_app/features/catalog/data/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a complete percentage deal', () {
    final deal = DealDetail.fromJson({
      'id': 12,
      'title_ar': 'خصم الصيف',
      'slug': 'summer-sale',
      'description_ar': 'خصم على جميع الخدمات',
      'terms_ar': 'مرة واحدة لكل مستخدم',
      'deal_type': 'percentage',
      'discount_percentage': 30,
      'original_price': '500.00',
      'final_price': '350.00',
      'savings_amount': '150.00',
      'days_remaining': 4,
      'is_valid': true,
      'is_expired': false,
      'is_upcoming': false,
      'remaining_uses': 8,
      'max_uses_per_user': 1,
      'end_date': '2026-07-27T12:00:00Z',
      'business': {
        'name_ar': 'متجر الدليل',
        'slug': 'dalil-store',
      },
    });

    expect(deal.summary.title, 'خصم الصيف');
    expect(deal.summary.typeLabel, 'خصم 30٪');
    expect(deal.summary.hasDiscount, isTrue);
    expect(deal.summary.finalPrice, 350);
    expect(deal.summary.remainingUses, 8);
    expect(deal.summary.businessName, 'متجر الدليل');
    expect(deal.savingsAmount, 150);
    expect(deal.canClaim, isTrue);
  });

  test('marks expired and non-priced special offer correctly', () {
    final deal = DealDetail.fromJson({
      'id': 13,
      'title_en': 'Special offer',
      'deal_type': 'special',
      'days_remaining': 0,
      'is_valid': false,
      'is_expired': true,
      'is_upcoming': false,
      'business': <String, dynamic>{},
    });

    expect(deal.summary.typeLabel, 'عرض خاص');
    expect(deal.summary.hasPrice, isFalse);
    expect(deal.isExpired, isTrue);
    expect(deal.canClaim, isFalse);
  });
}
