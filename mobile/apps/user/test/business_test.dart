import 'package:dalil_app/features/directory/data/business.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses decimal ratings returned as strings by API v2', () {
    final business = Business.fromJson({
      'id': 7,
      'name_ar': 'صيدلية المدينة',
      'name_en': 'City Pharmacy',
      'slug': 'city-pharmacy',
      'average_rating': '4.75',
    });

    expect(business.id, 7);
    expect(business.rating, 4.75);
  });

  test('parses business detail contacts, location and active gallery', () {
    final business = Business.fromJson({
      'id': 9,
      'name_ar': 'متجر النور',
      'name_en': 'Al Noor',
      'slug': 'al-noor',
      'average_rating': '4.20',
      'total_reviews': 8,
      'is_favorite': true,
      'whatsapp': '01000000000',
      'address_ar': 'شارع التحرير',
      'category': {'name_ar': 'إلكترونيات'},
      'district': {'name_ar': 'وسط البلد'},
      'city': {'name_ar': 'القاهرة'},
      'governorate': {'name_ar': 'القاهرة'},
      'latitude': '30.044400',
      'longitude': '31.235700',
      'images': [
        {'image': 'https://example.com/1.jpg', 'is_active': true},
        {'image': 'https://example.com/2.jpg', 'is_active': false},
      ],
    });

    expect(business.whatsapp, '01000000000');
    expect(business.categoryName, 'إلكترونيات');
    expect(business.area, 'وسط البلد، القاهرة');
    expect(business.hasCoordinates, isTrue);
    expect(business.images, hasLength(1));
    expect(business.isFavorite, isTrue);
  });
}
