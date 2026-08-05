/// نماذج تطبيق الأنشطة — تطابق ما يعيده `/api/v2/merchant/`.

class ShopSummary {
  const ShopSummary({
    required this.id,
    required this.nameAr,
    required this.isVerified,
    required this.isFeatured,
    required this.isActive,
    this.categoryName = '',
    this.cityName = '',
    this.governorateName = '',
    this.phone = '',
    this.whatsapp = '',
    this.addressAr = '',
    this.descriptionAr = '',
    this.email = '',
    this.website = '',
    this.facebook = '',
    this.instagram = '',
    this.workingHoursAr = '',
    this.viewCount = 0,
    this.clickCount = 0,
    this.logo,
  });

  final int id;
  final String nameAr;
  final bool isVerified;
  final bool isFeatured;
  final bool isActive;
  final String categoryName;
  final String cityName;
  final String governorateName;
  final String phone;
  final String whatsapp;
  final String addressAr;
  final String descriptionAr;
  final String email;
  final String website;
  final String facebook;
  final String instagram;
  final String workingHoursAr;
  final int viewCount;
  final int clickCount;
  final String? logo;

  /// سطر الموقع كما يُعرض تحت الاسم على اللافتة.
  String get placeLine {
    final parts = [categoryName, cityName].where((p) => p.isNotEmpty);
    return parts.join(' · ');
  }

  factory ShopSummary.fromJson(Map<String, dynamic> json) => ShopSummary(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nameAr: json['name_ar'] as String? ?? 'نشاط بلا اسم',
        isVerified: json['is_verified'] as bool? ?? false,
        isFeatured: json['is_featured'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        categoryName: json['category_name'] as String? ?? '',
        cityName: json['city_name'] as String? ?? '',
        governorateName: json['governorate_name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        addressAr: json['address_ar'] as String? ?? '',
        descriptionAr: json['description_ar'] as String? ?? '',
        email: json['email'] as String? ?? '',
        website: json['website'] as String? ?? '',
        facebook: json['facebook'] as String? ?? '',
        instagram: json['instagram'] as String? ?? '',
        workingHoursAr: json['working_hours_ar'] as String? ?? '',
        viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
        clickCount: (json['click_count'] as num?)?.toInt() ?? 0,
        logo: json['logo'] as String?,
      );
}

class MerchantSession {
  const MerchantSession({
    required this.fullName,
    required this.shops,
    this.phone = '',
  });

  final String fullName;
  final String phone;
  final List<ShopSummary> shops;

  bool get hasMultipleShops => shops.length > 1;
  ShopSummary? get firstShop => shops.isEmpty ? null : shops.first;

  factory MerchantSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final raw = json['businesses'];
    return MerchantSession(
      fullName: user['full_name'] as String? ??
          user['username'] as String? ??
          'صاحب النشاط',
      phone: user['phone'] as String? ?? '',
      shops: (raw is List ? raw : const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopSummary.fromJson)
          .toList(growable: false),
    );
  }
}

/// ما يحتاج تدخّل التاجر — أساس الشاشة الرئيسية.
class NeedsAttention {
  const NeedsAttention({
    required this.reviewsWithoutReply,
    required this.dealsExpiringSoon,
    required this.awaitingVerification,
  });

  final int reviewsWithoutReply;
  final int dealsExpiringSoon;
  final int awaitingVerification;

  int get total =>
      reviewsWithoutReply + dealsExpiringSoon + awaitingVerification;

  factory NeedsAttention.fromJson(Map<String, dynamic> json) => NeedsAttention(
        reviewsWithoutReply:
            (json['reviews_without_reply'] as num?)?.toInt() ?? 0,
        dealsExpiringSoon: (json['deals_expiring_soon'] as num?)?.toInt() ?? 0,
        awaitingVerification:
            (json['businesses_awaiting_verification'] as num?)?.toInt() ?? 0,
      );
}

class ShopTotals {
  const ShopTotals({
    required this.views,
    required this.clicks,
    required this.products,
    required this.reviews,
    required this.averageRating,
    required this.verified,
    required this.businesses,
  });

  final int views;
  final int clicks;
  final int products;
  final int reviews;
  final double averageRating;
  final int verified;
  final int businesses;

  factory ShopTotals.fromJson(Map<String, dynamic> json) => ShopTotals(
        views: (json['views'] as num?)?.toInt() ?? 0,
        clicks: (json['clicks'] as num?)?.toInt() ?? 0,
        products: (json['products'] as num?)?.toInt() ?? 0,
        reviews: (json['reviews'] as num?)?.toInt() ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
        verified: (json['verified'] as num?)?.toInt() ?? 0,
        businesses: (json['businesses'] as num?)?.toInt() ?? 0,
      );
}

class MerchantDashboard {
  const MerchantDashboard({required this.attention, required this.totals});

  final NeedsAttention attention;
  final ShopTotals totals;

  factory MerchantDashboard.fromJson(Map<String, dynamic> json) =>
      MerchantDashboard(
        attention: NeedsAttention.fromJson(
          json['needs_attention'] as Map<String, dynamic>? ?? const {},
        ),
        totals: ShopTotals.fromJson(
          json['totals'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

class ReviewReply {
  const ReviewReply({required this.id, required this.comment});

  final int id;
  final String comment;

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
        id: (json['id'] as num?)?.toInt() ?? 0,
        comment: json['comment'] as String? ?? '',
      );
}

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.businessName,
    required this.createdAt,
    this.reply,
  });

  final int id;
  final int rating;
  final String comment;
  final String reviewerName;
  final String businessName;
  final DateTime? createdAt;
  final ReviewReply? reply;

  bool get needsReply => reply == null;

  /// تقييم منخفض بلا رد — أولوية التاجر الأولى.
  bool get isUrgent => needsReply && rating <= 3;

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        comment: json['comment'] as String? ?? '',
        reviewerName: json['reviewer_name'] as String? ?? 'عميل',
        businessName: json['business_name'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        reply: json['reply'] is Map<String, dynamic>
            ? ReviewReply.fromJson(json['reply'] as Map<String, dynamic>)
            : null,
      );
}

class ProductItem {
  const ProductItem({
    required this.id,
    required this.nameAr,
    required this.price,
    required this.isAvailable,
    required this.businessId,
    this.businessName = '',
    this.oldPrice,
    this.descriptionAr = '',
    this.productType = 'product',
    this.stockQuantity,
    this.hasDelivery = false,
    this.deliveryCost,
    this.deliveryTimeAr = '',
    this.primaryImage,
    this.images = const [],
  });

  final int id;
  final String nameAr;
  final String price;
  final String? oldPrice;
  final bool isAvailable;
  final int businessId;
  final String businessName;
  final String descriptionAr;
  final String productType;
  final int? stockQuantity;
  final bool hasDelivery;
  final String? deliveryCost;
  final String deliveryTimeAr;

  /// المنتج عنده معرض صور، والرئيسية هي اللي بتظهر في الدليل.
  final String? primaryImage;
  final List<ProductImage> images;

  bool get hasImage => primaryImage != null && primaryImage!.isNotEmpty;
  bool get isService => productType == 'service';
  bool get hasDiscount => oldPrice != null && oldPrice!.isNotEmpty;

  /// نسبة الخصم للعرض. تُحسب هنا لا في الواجهة حتى لا تختلف من شاشة لأخرى.
  int? get discountPercent {
    final now = double.tryParse(price);
    final before = double.tryParse(oldPrice ?? '');
    if (now == null || before == null || before <= now) return null;
    return (((before - now) / before) * 100).round();
  }

  factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nameAr: json['name_ar'] as String? ?? '',
        price: '${json['price'] ?? '0'}',
        oldPrice: json['old_price'] == null ? null : '${json['old_price']}',
        isAvailable: json['is_available'] as bool? ?? true,
        businessId: (json['business'] as num?)?.toInt() ?? 0,
        businessName: json['business_name'] as String? ?? '',
        descriptionAr: json['description_ar'] as String? ?? '',
        productType: json['product_type'] as String? ?? 'product',
        stockQuantity: (json['stock_quantity'] as num?)?.toInt(),
        hasDelivery: json['has_delivery'] as bool? ?? false,
        deliveryCost:
            json['delivery_cost'] == null ? null : '${json['delivery_cost']}',
        deliveryTimeAr: json['delivery_time_ar'] as String? ?? '',
        primaryImage: json['primary_image'] as String?,
        images: (json['images'] is List ? json['images'] as List : const [])
            .whereType<Map<String, dynamic>>()
            .map(ProductImage.fromJson)
            .toList(growable: false),
      );
}

class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    required this.isPrimary,
    this.altTextAr = '',
  });

  final int id;
  final String url;
  final bool isPrimary;
  final String altTextAr;

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        id: (json['id'] as num?)?.toInt() ?? 0,
        url: json['image'] as String? ?? '',
        isPrimary: json['is_primary'] as bool? ?? false,
        altTextAr: json['alt_text_ar'] as String? ?? '',
      );
}

class DealItem {
  const DealItem({
    required this.id,
    required this.titleAr,
    required this.dealType,
    required this.isActive,
    required this.businessId,
    this.descriptionAr = '',
    this.dealTypeDisplay = '',
    this.discountPercentage,
    this.startDate,
    this.endDate,
    this.termsAr = '',
    this.currentUses = 0,
    this.imageUrl,
  });

  final int id;
  final String titleAr;
  final String descriptionAr;
  final String dealType;
  final String dealTypeDisplay;
  final int? discountPercentage;
  final DateTime? startDate;
  final DateTime? endDate;
  final String termsAr;
  final bool isActive;
  final int currentUses;
  final int businessId;
  final String? imageUrl;

  /// كام يوم فاضل. سالب = خلص.
  int? get daysLeft {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpired => (daysLeft ?? 1) < 0;
  bool get isEndingSoon => !isExpired && (daysLeft ?? 99) <= 3;

  bool get isLive {
    if (!isActive || isExpired) return false;
    if (startDate == null) return true;
    return !startDate!.isAfter(DateTime.now());
  }

  factory DealItem.fromJson(Map<String, dynamic> json) => DealItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        titleAr: json['title_ar'] as String? ?? '',
        descriptionAr: json['description_ar'] as String? ?? '',
        dealType: json['deal_type'] as String? ?? 'percentage',
        dealTypeDisplay: json['deal_type_display'] as String? ?? '',
        discountPercentage: (json['discount_percentage'] as num?)?.toInt(),
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
        termsAr: json['terms_ar'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? false,
        currentUses: (json['current_uses'] as num?)?.toInt() ?? 0,
        businessId: (json['business'] as num?)?.toInt() ?? 0,
        imageUrl: json['image'] as String?,
      );
}
