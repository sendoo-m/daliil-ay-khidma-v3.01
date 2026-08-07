final class Business {
  const Business({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.slug,
    required this.rating,
    this.logo,
    this.description = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.website = '',
    this.facebook = '',
    this.instagram = '',
    this.twitter = '',
    this.tiktok = '',
    this.coverImage,
    this.address = '',
    this.locationUrl = '',
    this.workingHours = '',
    this.categoryName = '',
    this.districtName = '',
    this.cityName = '',
    this.governorateName = '',
    this.businessType = '',
    this.totalReviews = 0,
    this.isVerified = false,
    this.isFeatured = false,
    this.images = const [],
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isFavorite = false,
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as int,
        nameAr: json['name_ar'] as String? ?? '',
        nameEn: json['name_en'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        rating: double.tryParse('${json['average_rating'] ?? 0}') ?? 0,
        logo: _optionalString(json['logo']),
        description: json['description_ar'] as String? ??
            json['description_en'] as String? ??
            '',
        phone: json['phone'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        email: json['email'] as String? ?? '',
        website: json['website'] as String? ?? '',
        facebook: json['facebook'] as String? ?? '',
        instagram: json['instagram'] as String? ?? '',
        twitter: json['twitter'] as String? ?? '',
        tiktok: json['tiktok'] as String? ?? '',
        coverImage: _optionalString(json['cover_image']),
        address: json['address_ar'] as String? ??
            json['address_en'] as String? ??
            '',
        locationUrl: json['location_url'] as String? ?? '',
        workingHours: json['working_hours_ar'] as String? ??
            json['working_hours_en'] as String? ??
            '',
        categoryName: _localizedName(json['category']),
        districtName: _localizedName(json['district']),
        cityName: _localizedName(json['city']),
        governorateName: _localizedName(json['governorate']),
        businessType: json['business_type'] as String? ?? '',
        totalReviews: json['total_reviews'] as int? ?? 0,
        isVerified: json['is_verified'] as bool? ?? false,
        isFeatured: json['is_featured'] as bool? ?? false,
        images: (json['images'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((item) => item['is_active'] as bool? ?? true)
            .map(BusinessImage.fromJson)
            .where((item) => item.url.isNotEmpty)
            .toList(growable: false),
        latitude: _coordinate(json['latitude']),
        longitude: _coordinate(json['longitude']),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        isFavorite: json['is_favorite'] as bool? ?? false,
      );

  final int id;
  final String nameAr;
  final String nameEn;
  final String slug;
  final double rating;
  final String? logo;
  final String description;
  final String phone;
  final String whatsapp;
  final String email;
  final String website;
  final String facebook;
  final String instagram;
  final String twitter;
  final String tiktok;
  final String? coverImage;
  final String address;
  final String locationUrl;
  final String workingHours;
  final String categoryName;
  final String districtName;
  final String cityName;
  final String governorateName;
  final String businessType;
  final int totalReviews;
  final bool isVerified;
  final bool isFeatured;
  final List<BusinessImage> images;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isFavorite;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayName => nameAr.isEmpty ? nameEn : nameAr;

  String displayNameFor(String languageCode) => languageCode == 'ar'
      ? (nameAr.isNotEmpty ? nameAr : nameEn)
      : (nameEn.isNotEmpty ? nameEn : nameAr);

  String get area {
    final parts = [districtName, cityName, governorateName]
        .where((part) => part.isNotEmpty)
        .toSet();
    return parts.join('، ');
  }

  bool get hasContactMethods =>
      phone.isNotEmpty ||
      whatsapp.isNotEmpty ||
      email.isNotEmpty ||
      website.isNotEmpty;

  bool get hasSocialLinks =>
      facebook.isNotEmpty ||
      instagram.isNotEmpty ||
      twitter.isNotEmpty ||
      tiktok.isNotEmpty;
}

final class BusinessImage {
  const BusinessImage({required this.url, this.caption = ''});

  factory BusinessImage.fromJson(Map<String, dynamic> json) => BusinessImage(
        url: json['image'] as String? ?? '',
        caption: json['caption_ar'] as String? ??
            json['caption_en'] as String? ??
            '',
      );

  final String url;
  final String caption;
}

double? _coordinate(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

String _localizedName(Object? value) {
  if (value is! Map<String, dynamic>) return '';
  return value['name_ar'] as String? ?? value['name_en'] as String? ?? '';
}

String? _optionalString(Object? value) {
  final text = value as String?;
  return text == null || text.isEmpty ? null : text;
}
