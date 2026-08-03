import 'package:dalil_app/features/catalog/data/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses complete product details safely', () {
    final product = ProductDetail.fromJson({
      'id': 7,
      'name_ar': 'غسيل شامل',
      'slug': 'full-wash',
      'description_ar': 'خدمة غسيل متكاملة',
      'product_type': 'service',
      'price': '150.00',
      'old_price': '200.00',
      'discount_percentage': 25,
      'is_available': true,
      'is_in_stock': true,
      'has_delivery': true,
      'delivery_cost': '0.00',
      'delivery_time_ar': 'خلال ساعتين',
      'is_featured': true,
      'view_count': 21,
      'business': {
        'name_ar': 'مركز النظافة',
        'slug': 'clean-center',
      },
      'images': [
        {
          'image': 'https://example.com/service.jpg',
          'alt_text_ar': 'صورة الخدمة',
          'is_primary': true,
        },
        {'image': ''},
      ],
    });

    expect(product.name, 'غسيل شامل');
    expect(product.typeLabel, 'خدمة');
    expect(product.price, 150);
    expect(product.hasDiscount, isTrue);
    expect(product.discountPercentage, 25);
    expect(product.canOrder, isTrue);
    expect(product.deliveryCost, 0);
    expect(product.businessName, 'مركز النظافة');
    expect(product.images, hasLength(1));
  });

  test('marks unavailable stock product as not orderable', () {
    final product = ProductDetail.fromJson({
      'id': 8,
      'name_en': 'Product',
      'product_type': 'product',
      'price': 90,
      'is_available': true,
      'is_in_stock': false,
      'business': <String, dynamic>{},
    });

    expect(product.canOrder, isFalse);
    expect(product.hasBusiness, isFalse);
    expect(product.images, isEmpty);
  });
}
