final class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.businessName,
    required this.businessSlug,
    required this.productType,
    this.image,
    this.oldPrice,
  });
  factory ProductSummary.fromJson(Map<String, dynamic> json) => ProductSummary(
        id: json['id'] as int,
        name: json['name_ar'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        price: '${json['price'] ?? ''}',
        oldPrice: json['old_price'] == null ? null : '${json['old_price']}',
        businessName:
            (json['business'] as Map<String, dynamic>?)?['name_ar'] as String? ??
                '',
        businessSlug:
            (json['business'] as Map<String, dynamic>?)?['slug'] as String? ??
                '',
        productType: json['product_type'] as String? ?? 'product',
        image: (json['primary_image'] as Map<String, dynamic>?)?['image'] as String?,
      );
  final int id;
  final String name;
  final String slug;
  final String price;
  final String? oldPrice;
  final String businessName;
  final String businessSlug;
  final String productType;
  final String? image;

  double get numericPrice => double.tryParse(price) ?? double.infinity;
}

final class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.productType,
    required this.price,
    required this.businessName,
    required this.businessSlug,
    required this.isAvailable,
    required this.isInStock,
    required this.hasDelivery,
    required this.isFeatured,
    required this.viewCount,
    this.oldPrice,
    this.discountPercentage = 0,
    this.stockQuantity,
    this.deliveryCost,
    this.deliveryTime = '',
    this.images = const [],
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final business = json['business'] as Map<String, dynamic>? ?? const {};
    return ProductDetail(
      id: json['id'] as int,
      name: json['name_ar'] as String? ?? json['name_en'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description_ar'] as String? ??
          json['description_en'] as String? ??
          '',
      productType: json['product_type'] as String? ?? 'product',
      price: _number(json['price']),
      oldPrice: json['old_price'] == null ? null : _number(json['old_price']),
      discountPercentage: _number(json['discount_percentage']),
      businessName:
          business['name_ar'] as String? ?? business['name_en'] as String? ?? '',
      businessSlug: business['slug'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? false,
      isInStock: json['is_in_stock'] as bool? ?? true,
      hasDelivery: json['has_delivery'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      viewCount: json['view_count'] as int? ?? 0,
      stockQuantity: json['stock_quantity'] as int?,
      deliveryCost:
          json['delivery_cost'] == null ? null : _number(json['delivery_cost']),
      deliveryTime: json['delivery_time_ar'] as String? ??
          json['delivery_time_en'] as String? ??
          '',
      images: (json['images'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProductImage.fromJson)
          .where((image) => image.url.isNotEmpty)
          .toList(growable: false),
    );
  }

  final int id;
  final String name;
  final String slug;
  final String description;
  final String productType;
  final double price;
  final double? oldPrice;
  final double discountPercentage;
  final String businessName;
  final String businessSlug;
  final bool isAvailable;
  final bool isInStock;
  final bool hasDelivery;
  final bool isFeatured;
  final int viewCount;
  final int? stockQuantity;
  final double? deliveryCost;
  final String deliveryTime;
  final List<ProductImage> images;

  bool get hasDiscount => oldPrice != null && oldPrice! > price;
  bool get canOrder => isAvailable && (productType == 'service' || isInStock);
  bool get hasBusiness => businessName.isNotEmpty && businessSlug.isNotEmpty;
  String get typeLabel => productType == 'service' ? 'خدمة' : 'منتج';
}

final class ProductImage {
  const ProductImage({
    required this.url,
    this.altText = '',
    this.isPrimary = false,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        url: json['image'] as String? ?? '',
        altText: json['alt_text_ar'] as String? ??
            json['alt_text_en'] as String? ??
            '',
        isPrimary: json['is_primary'] as bool? ?? false,
      );

  final String url;
  final String altText;
  final bool isPrimary;
}

final class DealSummary {
  const DealSummary({
    required this.id,
    required this.title,
    required this.slug,
    required this.dealType,
    required this.daysRemaining,
    required this.isValid,
    required this.isFeatured,
    required this.businessName,
    required this.businessSlug,
    this.image,
    this.originalPrice,
    this.finalPrice,
    this.discountPercentage = 0,
    this.remainingUses,
  });
  factory DealSummary.fromJson(Map<String, dynamic> json) => DealSummary(
        id: json['id'] as int? ?? 0,
        title: json['title_ar'] as String? ??
            json['title_en'] as String? ??
            '',
        slug: json['slug'] as String? ?? '',
        dealType: json['deal_type'] as String? ?? 'special',
        originalPrice: _nullableNumber(json['original_price']),
        finalPrice: _nullableNumber(json['final_price']),
        discountPercentage: _number(json['discount_percentage']),
        daysRemaining: json['days_remaining'] as int? ?? 0,
        isValid: json['is_valid'] as bool? ?? true,
        isFeatured: json['is_featured'] as bool? ?? false,
        businessName:
            (json['business'] as Map<String, dynamic>?)?['name_ar']
                    as String? ??
                '',
        businessSlug:
            (json['business'] as Map<String, dynamic>?)?['slug'] as String? ??
                '',
        image: json['image'] as String?,
        remainingUses: json['remaining_uses'] as int?,
      );
  final int id;
  final String title;
  final String slug;
  final String dealType;
  final double? originalPrice;
  final double? finalPrice;
  final double discountPercentage;
  final int daysRemaining;
  final bool isValid;
  final bool isFeatured;
  final String businessName;
  final String businessSlug;
  final String? image;
  final int? remainingUses;

  bool get hasPrice => finalPrice != null;
  bool get hasDiscount =>
      originalPrice != null &&
      finalPrice != null &&
      originalPrice! > finalPrice!;
  bool get isLimited => remainingUses != null;
  String get typeLabel => switch (dealType) {
        'percentage' => 'خصم ${discountPercentage.toStringAsFixed(0)}٪',
        'fixed' => 'خصم بقيمة ثابتة',
        'bogo' => 'اشترِ واحدًا واحصل على آخر',
        'bundle' => 'عرض مجموعة',
        _ => 'عرض خاص',
      };
}

final class DealDetail {
  const DealDetail({
    required this.summary,
    required this.description,
    required this.terms,
    required this.startDate,
    required this.endDate,
    required this.isExpired,
    required this.isUpcoming,
    required this.savingsAmount,
    required this.viewCount,
    required this.maxUsesPerUser,
  });

  factory DealDetail.fromJson(Map<String, dynamic> json) => DealDetail(
        summary: DealSummary.fromJson(json),
        description: json['description_ar'] as String? ??
            json['description_en'] as String? ??
            '',
        terms:
            json['terms_ar'] as String? ?? json['terms_en'] as String? ?? '',
        startDate: DateTime.tryParse('${json['start_date'] ?? ''}'),
        endDate: DateTime.tryParse('${json['end_date'] ?? ''}'),
        isExpired: json['is_expired'] as bool? ?? false,
        isUpcoming: json['is_upcoming'] as bool? ?? false,
        savingsAmount: _number(json['savings_amount']),
        viewCount: json['view_count'] as int? ?? 0,
        maxUsesPerUser: json['max_uses_per_user'] as int? ?? 1,
      );

  final DealSummary summary;
  final String description;
  final String terms;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isExpired;
  final bool isUpcoming;
  final double savingsAmount;
  final int viewCount;
  final int maxUsesPerUser;

  bool get canClaim =>
      summary.isValid && !isExpired && !isUpcoming && summary.slug.isNotEmpty;
}

final class DealClaimResult {
  const DealClaimResult({required this.id, required this.claimedAt});

  factory DealClaimResult.fromJson(Map<String, dynamic> json) =>
      DealClaimResult(
        id: json['id'] as int? ?? 0,
        claimedAt: DateTime.tryParse('${json['claimed_at'] ?? ''}'),
      );

  final int id;
  final DateTime? claimedAt;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

double? _nullableNumber(Object? value) {
  if (value == null || '$value'.isEmpty) return null;
  return _number(value);
}
