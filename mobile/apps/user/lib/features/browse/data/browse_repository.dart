import 'package:dio/dio.dart';

/// دليل واحد من التلاتة — محلات، حرف، خدمات عامة.
class Directory {
  const Directory({
    required this.key,
    required this.name,
    required this.description,
    required this.count,
    this.categories = const [],
  });

  final String key;
  final String name;
  final String description;
  final int count;
  final List<BrowseCategory> categories;

  bool get isEmpty => count == 0;

  factory Directory.fromJson(Map<String, dynamic> json) => Directory(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        categories: (json['categories'] is List
                ? json['categories'] as List
                : const [])
            .whereType<Map<String, dynamic>>()
            .map(BrowseCategory.fromJson)
            .toList(growable: false),
      );
}

class BrowseCategory {
  const BrowseCategory({
    required this.id,
    required this.name,
    required this.count,
    this.slug = '',
    this.image,
    this.businessType = 'shop',
  });

  final int id;
  final String slug;
  final String name;
  final int count;
  final String? image;
  final String businessType;

  factory BrowseCategory.fromJson(Map<String, dynamic> json) => BrowseCategory(
        id: (json['id'] as num?)?.toInt() ?? 0,
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        image: json['image'] as String?,
        businessType: json['business_type'] as String? ?? 'shop',
      );
}

class BrowsePlace {
  const BrowsePlace({
    required this.id,
    required this.name,
    required this.count,
    this.cityId,
  });

  final int id;
  final String name;
  final int count;

  /// للأحياء فقط — المدينة التابع لها.
  final int? cityId;

  factory BrowsePlace.fromJson(Map<String, dynamic> json) => BrowsePlace(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        cityId: (json['city'] as num?)?.toInt(),
      );
}

/// نظرة كاملة على محافظة — تأتي في نداء واحد.
class GovernorateOverview {
  const GovernorateOverview({
    required this.id,
    required this.name,
    required this.total,
    required this.directories,
    required this.cities,
    required this.districts,
  });

  final int id;
  final String name;
  final int total;
  final List<Directory> directories;
  final List<BrowsePlace> cities;
  final List<BrowsePlace> districts;

  List<BrowsePlace> districtsIn(int? cityId) {
    if (cityId == null) return districts;
    return districts.where((d) => d.cityId == cityId).toList(growable: false);
  }

  factory GovernorateOverview.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (json[key] is List ? json[key] as List : const [])
            .whereType<Map<String, dynamic>>()
            .map(parse)
            .toList(growable: false);

    return GovernorateOverview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      directories: list('directories', Directory.fromJson),
      cities: list('cities', BrowsePlace.fromJson),
      districts: list('districts', BrowsePlace.fromJson),
    );
  }
}

class BrowseRepository {
  BrowseRepository(this._dio);

  final Dio _dio;

  List<Map<String, dynamic>> _rows(dynamic data) =>
      (data is List ? data : const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

  /// الأدلة التلاتة بأعدادها. `governorate` يقصرها على محافظة.
  Future<List<Directory>> directories({int? governorate}) async {
    final res = await _dio.get<dynamic>(
      'browse/directories/',
      queryParameters: {if (governorate != null) 'governorate': governorate},
    );
    return _rows(res.data).map(Directory.fromJson).toList(growable: false);
  }

  /// كل الأقسام مجمّعة حسب الدليل — نداء واحد يبني الشاشة كلها.
  Future<List<Directory>> categoriesGrouped({int? governorate}) async {
    final res = await _dio.get<dynamic>(
      'browse/categories/',
      queryParameters: {if (governorate != null) 'governorate': governorate},
    );
    return _rows(res.data).map(Directory.fromJson).toList(growable: false);
  }

  Future<List<BrowseCategory>> categoriesOf(
    String type, {
    int? governorate,
  }) async {
    final res = await _dio.get<dynamic>(
      'browse/categories/',
      queryParameters: {
        'type': type,
        if (governorate != null) 'governorate': governorate,
      },
    );
    return _rows(res.data)
        .map(BrowseCategory.fromJson)
        .toList(growable: false);
  }

  Future<List<BrowsePlace>> governorates() async {
    final res = await _dio.get<dynamic>('browse/governorates/');
    return _rows(res.data).map(BrowsePlace.fromJson).toList(growable: false);
  }

  Future<GovernorateOverview> governorate(int id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'browse/governorates/$id/',
    );
    return GovernorateOverview.fromJson(res.data ?? const {});
  }
}
