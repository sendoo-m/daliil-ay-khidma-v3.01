import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../directory/data/business.dart';
import '../../directory/presentation/business_card.dart';

/// معايير عرض النتائج. أي شاشة تصفّح بتبني واحدة وتبعتها.
class BrowseQuery {
  const BrowseQuery({
    this.search = '',
    this.categoryId,
    this.governorateId,
    this.cityId,
    this.districtId,
    this.businessType,
  });

  final String search;
  final int? categoryId;
  final int? governorateId;
  final int? cityId;
  final int? districtId;
  final String? businessType;

  BrowseQuery copyWith({
    String? search,
    int? cityId,
    int? districtId,
    String? businessType,
    bool clearCity = false,
    bool clearDistrict = false,
    bool clearType = false,
  }) =>
      BrowseQuery(
        search: search ?? this.search,
        categoryId: categoryId,
        governorateId: governorateId,
        cityId: clearCity ? null : (cityId ?? this.cityId),
        districtId: clearDistrict ? null : (districtId ?? this.districtId),
        businessType: clearType ? null : (businessType ?? this.businessType),
      );

  @override
  bool operator ==(Object other) =>
      other is BrowseQuery &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.governorateId == governorateId &&
      other.cityId == cityId &&
      other.districtId == districtId &&
      other.businessType == businessType;

  @override
  int get hashCode => Object.hash(
        search,
        categoryId,
        governorateId,
        cityId,
        districtId,
        businessType,
      );
}

final browseResultsProvider = FutureProvider.autoDispose
    .family<List<Business>, BrowseQuery>((ref, query) async {
  return ref.watch(businessRepositoryProvider).search(
        query.search,
        categoryId: query.categoryId,
        governorateId: query.governorateId,
        cityId: query.cityId,
        districtId: query.districtId,
        businessType: query.businessType,
      );
});

/// شاشة نتائج مشتركة.
///
/// واحدة تخدم القسم والدليل والمدينة والحي — بدل أربع شاشات بتتشابه
/// وبتفترق مع الوقت. الفلاتر الظاهرة بتتحدد من اللي مبعوت: شاشة قسم
/// مش محتاجة فلتر قسم.
class BrowseResultsPage extends ConsumerStatefulWidget {
  const BrowseResultsPage({
    super.key,
    required this.title,
    this.subtitle,
    this.categoryId,
    this.governorateId,
    this.cityId,
    this.districtId,
    this.businessType,
    this.cities = const [],
    this.districts = const [],
  });

  final String title;
  final String? subtitle;
  final int? categoryId;
  final int? governorateId;
  final int? cityId;
  final int? districtId;
  final String? businessType;

  /// تُمرَّر من شاشة المحافظة لتظهر كفلاتر. فاضية = مفيش فلتر مكان.
  final List<({int id, String name, int count})> cities;
  final List<({int id, String name, int count, int? cityId})> districts;

  @override
  ConsumerState<BrowseResultsPage> createState() => _BrowseResultsPageState();
}

class _BrowseResultsPageState extends ConsumerState<BrowseResultsPage> {
  final _controller = TextEditingController();
  late BrowseQuery _query;

  @override
  void initState() {
    super.initState();
    _query = BrowseQuery(
      categoryId: widget.categoryId,
      governorateId: widget.governorateId,
      cityId: widget.cityId,
      districtId: widget.districtId,
      businessType: widget.businessType,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(BrowseQuery next) => setState(() => _query = next);

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(browseResultsProvider(_query));

    // الأحياء تتبع المدينة المختارة — عرض كل أحياء المحافظة بعد اختيار
    // مدينة يقدّم للمستخدم خيارات لن تعطيه نتائج.
    final districts = _query.cityId == null
        ? widget.districts
        : widget.districts.where((d) => d.cityId == _query.cityId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _controller,
            hint: 'ابحث جوه ${widget.title}',
            onSubmit: (v) => _update(_query.copyWith(search: v)),
            onClear: () {
              _controller.clear();
              _update(_query.copyWith(search: ''));
            },
          ),

          if (widget.cities.isNotEmpty || districts.isNotEmpty)
            _PlaceFilters(
              cities: widget.cities,
              districts: districts,
              selectedCity: _query.cityId,
              selectedDistrict: _query.districtId,
              onCity: (id) => _update(
                id == null
                    ? _query.copyWith(clearCity: true, clearDistrict: true)
                    : _query.copyWith(cityId: id, clearDistrict: true),
              ),
              onDistrict: (id) => _update(
                id == null
                    ? _query.copyWith(clearDistrict: true)
                    : _query.copyWith(districtId: id),
              ),
            ),

          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Message(
                text: 'تعذّر تحميل النتائج.',
                action: OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(browseResultsProvider(_query)),
                  child: const Text('حاول تاني'),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _Message(
                    text: _query.search.isEmpty
                        ? 'مفيش نتائج بالفلاتر دي.'
                        : 'مفيش نتائج لـ"${_query.search}".',
                    action: (_query.cityId != null ||
                            _query.districtId != null ||
                            _query.search.isNotEmpty)
                        ? TextButton(
                            onPressed: () {
                              _controller.clear();
                              _update(
                                BrowseQuery(
                                  categoryId: widget.categoryId,
                                  governorateId: widget.governorateId,
                                  businessType: widget.businessType,
                                ),
                              );
                            },
                            child: const Text('امسح الفلاتر'),
                          )
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(browseResultsProvider(_query)),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    itemCount: items.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: 4,
                            bottom: 10,
                          ),
                          child: Text(
                            '${items.length} نتيجة',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BusinessCard(business: items[i - 1]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final void Function(String) onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _PlaceFilters extends StatelessWidget {
  const _PlaceFilters({
    required this.cities,
    required this.districts,
    required this.selectedCity,
    required this.selectedDistrict,
    required this.onCity,
    required this.onDistrict,
  });

  final List<({int id, String name, int count})> cities;
  final List<({int id, String name, int count, int? cityId})> districts;
  final int? selectedCity;
  final int? selectedDistrict;
  final void Function(int?) onCity;
  final void Function(int?) onDistrict;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          if (cities.isNotEmpty)
            _Row(
              label: 'المدينة',
              chips: [
                (null, 'الكل', 0),
                ...cities.map((c) => (c.id, c.name, c.count)),
              ],
              selected: selectedCity,
              onTap: onCity,
            ),
          if (districts.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Row(
              label: 'الحي',
              chips: [
                (null, 'الكل', 0),
                ...districts.map((d) => (d.id, d.name, d.count)),
              ],
              selected: selectedDistrict,
              onTap: onDistrict,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.chips,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<(int?, String, int)> chips;
  final int? selected;
  final void Function(int?) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          final (id, name, count) = chips[i - 1];
          final active = id == selected;
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTap(id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count > 0 ? '$name ($count)' : name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
