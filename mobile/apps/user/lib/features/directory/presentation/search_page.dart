import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/presentation/catalog_detail_pages.dart';
import '../../home/data/home_repository.dart';
import '../../location/data/location_service.dart';
import '../data/business.dart';
import 'business_card.dart';

enum _SearchKind { businesses, products }

enum _SearchSort { featured, rating, newest, priceLow, priceHigh, alphabetical }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    this.embedded = false,
    this.initialQuery = '',
    this.initialCategoryId,
    super.key,
  });

  final bool embedded;
  final String initialQuery;
  final int? initialCategoryId;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery.trim();
  late int? _categoryId = widget.initialCategoryId;
  int? _governorateId;
  String? _businessType;
  String? _productType;
  double? _minRating;
  double? _minPrice;
  double? _maxPrice;
  double? _radiusKm;
  UserCoordinates? _cachedCoordinates;
  var _kind = _SearchKind.businesses;
  var _sort = _SearchSort.featured;
  var _revision = 0;
  Timer? _debounce;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;

  List<String> get _popularSearches => _isArabic
      ? const ['مطاعم', 'كافيهات', 'سباك', 'كهربائي', 'صيدليات', 'عروض']
      : const ['Restaurants', 'Cafes', 'Plumber', 'Electrician', 'Pharmacies', 'Deals'];

  int get _filterCount => <Object?>[
        _categoryId,
        _governorateId,
        _kind == _SearchKind.businesses ? _businessType : _productType,
        _kind == _SearchKind.businesses ? _minRating : null,
        _kind == _SearchKind.businesses ? _radiusKm : null,
        _kind == _SearchKind.products ? _minPrice : null,
        _kind == _SearchKind.products ? _maxPrice : null,
      ].where((value) => value != null).length;

  bool get _hasFilters => _filterCount > 0;

  String get _ordering {
    switch (_sort) {
      case _SearchSort.featured:
        return '-is_featured';
      case _SearchSort.rating:
        return '-average_rating';
      case _SearchSort.newest:
        return '-created_at';
      case _SearchSort.priceLow:
        return 'price';
      case _SearchSort.priceHigh:
        return '-price';
      case _SearchSort.alphabetical:
        return _isArabic ? 'name_ar' : 'name_en';
    }
  }

  @override
  void initState() {
    super.initState();
    if (_query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchHistoryProvider.notifier).add(_query);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _submit(value, dismissKeyboard: false);
    });
  }

  void _submit(String value, {bool dismissKeyboard = true}) {
    final normalized = value.trim();
    if (dismissKeyboard) FocusScope.of(context).unfocus();
    setState(() {
      _query = normalized;
      _revision++;
    });
    if (normalized.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).add(normalized);
    }
  }

  void _selectSuggestion(String value) {
    _controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    _submit(value);
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _query = '';
      _revision++;
    });
  }

  void _clearFilters() => setState(() {
        _categoryId = widget.initialCategoryId;
        _governorateId = null;
        _businessType = null;
        _productType = null;
        _minRating = null;
        _minPrice = null;
        _maxPrice = null;
        _radiusKm = null;
        _sort = _SearchSort.featured;
        _revision++;
      });

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final history = ref.watch(searchHistoryProvider);
    final discoveryMode = _query.isEmpty && !_hasFilters;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(_tr('البحث والاستكشاف', 'Search & discovery')),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: _tr('الفلاتر والترتيب', 'Filters & sorting'),
                  onPressed: home.valueOrNull == null
                      ? null
                      : () => _showFilters(home.requireValue),
                  icon: Badge(
                    isLabelVisible: _filterCount > 0,
                    label: Text('$_filterCount'),
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        top: widget.embedded,
        child: Column(
          children: [
            _SearchHero(
              controller: _controller,
              isArabic: _isArabic,
              onChanged: _onChanged,
              onSubmitted: (value) => _submit(value),
              onClear: _clearSearch,
              onFilter: home.valueOrNull == null
                  ? null
                  : () => _showFilters(home.requireValue),
              filterCount: _filterCount,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SegmentedButton<_SearchKind>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _SearchKind.businesses,
                    icon: const Icon(Icons.storefront_rounded),
                    label: Text(_tr('الأنشطة', 'Businesses')),
                  ),
                  ButtonSegment(
                    value: _SearchKind.products,
                    icon: const Icon(Icons.shopping_bag_rounded),
                    label: Text(_tr('المنتجات والخدمات', 'Products & services')),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (value) => setState(() {
                  _kind = value.first;
                  _sort = _SearchSort.featured;
                  _revision++;
                }),
              ),
            ),
            home.maybeWhen(
              data: (data) => _CategoryStrip(
                categories: data.categories,
                selectedId: _categoryId,
                isArabic: _isArabic,
                onSelected: (id) => setState(() {
                  _categoryId = id;
                  _revision++;
                }),
              ),
              orElse: () => const SizedBox(height: 16),
            ),
            if (!discoveryMode && _kind == _SearchKind.businesses)
              _DistanceFilterBar(
                value: _radiusKm,
                isArabic: _isArabic,
                onCommitted: (value) => setState(() {
                  _radiusKm = value;
                  _revision++;
                }),
              ),
            if (!discoveryMode)
              _ActiveFilters(
                isArabic: _isArabic,
                sort: _sort,
                filterCount: _filterCount,
                onSort: () => home.valueOrNull == null
                    ? null
                    : _showFilters(home.requireValue),
                onClear: _hasFilters ? _clearFilters : null,
              ),
            Expanded(
              child: discoveryMode
                  ? _DiscoveryContent(
                      isArabic: _isArabic,
                      history: history,
                      popular: _popularSearches,
                      typedValue: _controller.text,
                      onSelect: _selectSuggestion,
                      onRemove: (value) => ref
                          .read(searchHistoryProvider.notifier)
                          .remove(value),
                      onClearHistory: () => ref
                          .read(searchHistoryProvider.notifier)
                          .clear(),
                    )
                  : _kind == _SearchKind.businesses
                      ? _businessResults()
                      : _productResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _businessResults() => FutureBuilder<List<Business>>(
        key: ValueKey(
          'business-$_revision-$_query-$_categoryId-$_ordering-$_radiusKm',
        ),
        future: _fetchBusinesses(),
        builder: (context, snapshot) => _ResultsFrame<Business>(
          snapshot: snapshot,
          isArabic: _isArabic,
          itemBuilder: (item) => BusinessCard(business: item),
        ),
      );

  Future<List<Business>> _plainSearch() => ref.read(businessRepositoryProvider).search(
        _query,
        categoryId: _categoryId,
        governorateId: _governorateId,
        businessType: _businessType,
        minRating: _minRating,
        ordering: _ordering,
      );

  Future<List<Business>> _fetchBusinesses() async {
    final radius = _radiusKm;
    if (radius == null) return _plainSearch();
    try {
      // نخزّن الموقع بدل ما نطلبه من الـ GPS من جديد مع كل ضغطة مفتاح —
      // كان كل تغيير في نص البحث بيعيد تحديد الموقع كامل قبل حتى ما يوصل
      // لطلب الشبكة.
      final coordinates =
          _cachedCoordinates ??= await ref.read(locationServiceProvider).current();
      return await ref.read(businessRepositoryProvider).nearby(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            radiusKm: radius,
            query: _query,
            categoryId: _categoryId,
            governorateId: _governorateId,
            businessType: _businessType,
            minRating: _minRating,
          );
    } catch (_) {
      // موقع مرفوض، غير متاح، أو انتهت مهلة تحديده: نكمّل بدون تصفية
      // المسافة بدل ما نفشل البحث كله.
      return _plainSearch();
    }
  }

  Widget _productResults() => FutureBuilder<List<ProductSummary>>(
        key: ValueKey('product-$_revision-$_query-$_categoryId-$_ordering'),
        future: ref.read(catalogRepositoryProvider).searchProducts(
              _query,
              categoryId: _categoryId,
              governorateId: _governorateId,
              productType: _productType,
              minPrice: _minPrice,
              maxPrice: _maxPrice,
              ordering: _ordering,
            ),
        builder: (context, snapshot) => _ResultsFrame<ProductSummary>(
          snapshot: snapshot,
          isArabic: _isArabic,
          itemBuilder: (item) => _ProductResultCard(item: item, isArabic: _isArabic),
        ),
      );

  Future<void> _showFilters(HomeData home) async {
    var governorateId = _governorateId;
    var businessType = _businessType;
    var productType = _productType;
    var minRating = _minRating;
    var radiusKm = _radiusKm;
    var sort = _sort;
    final minPriceController =
        TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final maxPriceController =
        TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _tr('الفلاتر والترتيب', 'Filters & sorting'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int?>(
                  initialValue: governorateId,
                  decoration: InputDecoration(
                    labelText: _tr('المحافظة', 'Governorate'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(_tr('كل المحافظات', 'All governorates'))),
                    ...home.governorates.map((item) => DropdownMenuItem(
                          value: item['id'] as int?,
                          child: Text('${item[_isArabic ? 'name_ar' : 'name_en'] ?? item['name_ar'] ?? ''}'),
                        )),
                  ],
                  onChanged: (value) => setModalState(() => governorateId = value),
                ),
                const SizedBox(height: 14),
                if (_kind == _SearchKind.businesses) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: businessType,
                    decoration: InputDecoration(
                      labelText: _tr('نوع النشاط', 'Business type'),
                      prefixIcon: const Icon(Icons.store_mall_directory_outlined),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(_tr('الكل', 'All'))),
                      DropdownMenuItem(value: 'shop', child: Text(_tr('محلات', 'Shops'))),
                      DropdownMenuItem(value: 'craft', child: Text(_tr('حرفيون', 'Crafts'))),
                      DropdownMenuItem(value: 'public', child: Text(_tr('خدمات عامة', 'Public services'))),
                    ],
                    onChanged: (value) => setModalState(() => businessType = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<double?>(
                    initialValue: minRating,
                    decoration: InputDecoration(
                      labelText: _tr('أقل تقييم', 'Minimum rating'),
                      prefixIcon: const Icon(Icons.star_outline_rounded),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(_tr('أي تقييم', 'Any rating'))),
                      DropdownMenuItem(value: 3, child: Text(_tr('3 نجوم فأكثر', '3+ stars'))),
                      DropdownMenuItem(value: 4, child: Text(_tr('4 نجوم فأكثر', '4+ stars'))),
                      DropdownMenuItem(value: 4.5, child: Text(_tr('4.5 نجمة فأكثر', '4.5+ stars'))),
                    ],
                    onChanged: (value) => setModalState(() => minRating = value),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text(_tr('المسافة', 'Distance')),
                      const Spacer(),
                      Text(
                        radiusKm == null
                            ? _tr('بلا حد', 'No limit')
                            : _tr(
                                '${radiusKm!.toInt()} كم',
                                '${radiusKm!.toInt()} km',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    value: radiusKm ?? 20,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: radiusKm == null
                        ? _tr('بلا حد', 'No limit')
                        : '${radiusKm!.toInt()} ${_tr('كم', 'km')}',
                    onChanged: (value) =>
                        setModalState(() => radiusKm = value),
                  ),
                  if (radiusKm != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => setModalState(() => radiusKm = null),
                        child: Text(_tr('إزالة حد المسافة', 'Clear distance limit')),
                      ),
                    ),
                ] else ...[
                  DropdownButtonFormField<String?>(
                    initialValue: productType,
                    decoration: InputDecoration(
                      labelText: _tr('النوع', 'Type'),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(_tr('الكل', 'All'))),
                      DropdownMenuItem(value: 'product', child: Text(_tr('منتجات', 'Products'))),
                      DropdownMenuItem(value: 'service', child: Text(_tr('خدمات', 'Services'))),
                    ],
                    onChanged: (value) => setModalState(() => productType = value),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: TextField(
                        controller: minPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: _tr('أقل سعر', 'Min price')),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(
                        controller: maxPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: _tr('أعلى سعر', 'Max price')),
                      )),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<_SearchSort>(
                  initialValue: sort,
                  decoration: InputDecoration(
                    labelText: _tr('الترتيب', 'Sort by'),
                    prefixIcon: const Icon(Icons.sort_rounded),
                  ),
                  items: _availableSorts
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(_sortLabel(value)),
                          ))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setModalState(() => sort = value);
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(_tr('إلغاء', 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(_tr('تطبيق', 'Apply')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (apply == true && mounted) {
      setState(() {
        _governorateId = governorateId;
        _businessType = businessType;
        _productType = productType;
        _minRating = minRating;
        _radiusKm = radiusKm;
        _minPrice = double.tryParse(minPriceController.text.trim());
        _maxPrice = double.tryParse(maxPriceController.text.trim());
        _sort = sort;
        _revision++;
      });
    }
    minPriceController.dispose();
    maxPriceController.dispose();
  }

  List<_SearchSort> get _availableSorts => _kind == _SearchKind.businesses
      ? const [_SearchSort.featured, _SearchSort.rating, _SearchSort.newest, _SearchSort.alphabetical]
      : const [_SearchSort.featured, _SearchSort.newest, _SearchSort.priceLow, _SearchSort.priceHigh, _SearchSort.alphabetical];

  String _sortLabel(_SearchSort value) {
    switch (value) {
      case _SearchSort.featured:
        return _tr('المميز أولًا', 'Featured first');
      case _SearchSort.rating:
        return _tr('الأعلى تقييمًا', 'Highest rated');
      case _SearchSort.newest:
        return _tr('الأحدث', 'Newest');
      case _SearchSort.priceLow:
        return _tr('السعر: من الأقل', 'Price: low to high');
      case _SearchSort.priceHigh:
        return _tr('السعر: من الأعلى', 'Price: high to low');
      case _SearchSort.alphabetical:
        return _tr('أبجديًا', 'Alphabetical');
    }
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero({
    required this.controller,
    required this.isArabic,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onFilter,
    required this.filterCount,
  });

  final TextEditingController controller;
  final bool isArabic;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onFilter;
  final int filterCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        decoration: const BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'ماذا تبحث عنه اليوم؟' : 'What are you looking for?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'اكتشف الأنشطة والمنتجات والخدمات القريبة منك'
                  : 'Discover businesses, products and services near you',
              style: TextStyle(color: Colors.white.withValues(alpha: .84)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    decoration: InputDecoration(
                      hintText: isArabic ? 'اسم نشاط، منتج أو خدمة...' : 'Business, product or service...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: isArabic ? 'مسح' : 'Clear',
                              onPressed: onClear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  child: IconButton.filledTonal(
                    tooltip: isArabic ? 'الفلاتر' : 'Filters',
                    onPressed: onFilter,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories, required this.selectedId, required this.isArabic, required this.onSelected});
  final List<Map<String, dynamic>> categories;
  final int? selectedId;
  final bool isArabic;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 58,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            ChoiceChip(
              selected: selectedId == null,
              label: Text(isArabic ? 'الكل' : 'All'),
              avatar: const Icon(Icons.apps_rounded, size: 18),
              onSelected: (_) => onSelected(null),
            ),
            ...categories.map((item) {
              final id = item['id'] as int?;
              final name = '${item[isArabic ? 'name_ar' : 'name_en'] ?? item['name_ar'] ?? item['name_en'] ?? ''}';
              return Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ChoiceChip(
                  selected: selectedId == id,
                  label: Text(name),
                  onSelected: (_) => onSelected(id),
                ),
              );
            }),
          ],
        ),
      );
}

class _DistanceFilterBar extends StatefulWidget {
  const _DistanceFilterBar({
    required this.value,
    required this.isArabic,
    required this.onCommitted,
  });

  final double? value;
  final bool isArabic;
  final ValueChanged<double?> onCommitted;

  @override
  State<_DistanceFilterBar> createState() => _DistanceFilterBarState();
}

class _DistanceFilterBarState extends State<_DistanceFilterBar> {
  late double _draft = widget.value ?? 20;

  @override
  void didUpdateWidget(covariant _DistanceFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _draft = widget.value ?? 20;
  }

  String get _label => widget.value == null
      ? (widget.isArabic ? 'بلا حد' : 'No limit')
      : (widget.isArabic ? '${_draft.round()} كم' : '${_draft.round()} km');

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.near_me_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isArabic ? 'المسافة' : 'Distance',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    _label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  if (widget.value != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: widget.isArabic ? 'إزالة حد المسافة' : 'Clear distance limit',
                      onPressed: () => widget.onCommitted(null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
              Slider(
                value: _draft,
                min: 1,
                max: 20,
                divisions: 19,
                label: widget.isArabic ? '${_draft.round()} كم' : '${_draft.round()} km',
                onChanged: (value) => setState(() => _draft = value),
                onChangeEnd: widget.onCommitted,
              ),
            ],
          ),
        ),
      );
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.isArabic, required this.sort, required this.filterCount, required this.onSort, required this.onClear});
  final bool isArabic;
  final _SearchSort sort;
  final int filterCount;
  final VoidCallback? onSort;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            ActionChip(
              avatar: const Icon(Icons.sort_rounded, size: 18),
              label: Text(isArabic ? 'الترتيب والفلاتر' : 'Sort & filters'),
              onPressed: onSort,
            ),
            if (filterCount > 0) ...[
              const SizedBox(width: 8),
              Chip(label: Text(isArabic ? '$filterCount فلاتر نشطة' : '$filterCount active filters')),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(isArabic ? 'مسح الكل' : 'Clear all'),
                onPressed: onClear,
              ),
            ],
          ],
        ),
      );
}

class _DiscoveryContent extends StatelessWidget {
  const _DiscoveryContent({required this.isArabic, required this.history, required this.popular, required this.typedValue, required this.onSelect, required this.onRemove, required this.onClearHistory});
  final bool isArabic;
  final AsyncValue<List<String>> history;
  final List<String> popular;
  final String typedValue;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final recent = history.valueOrNull ?? const <String>[];
    final needle = typedValue.trim().toLowerCase();
    final suggestions = <String>{...recent, ...popular}
        .where((item) => needle.isEmpty || item.toLowerCase().contains(needle))
        .take(6)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (needle.isNotEmpty && suggestions.isNotEmpty) ...[
          _SectionTitle(title: isArabic ? 'اقتراحات البحث' : 'Search suggestions', icon: Icons.auto_awesome_rounded),
          const SizedBox(height: 10),
          ...suggestions.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.north_west_rounded),
                  title: Text(item),
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onTap: () => onSelect(item),
                ),
              )),
          const SizedBox(height: 18),
        ],
        if (recent.isNotEmpty) ...[
          _SectionTitle(title: isArabic ? 'عمليات البحث الأخيرة' : 'Recent searches', icon: Icons.history_rounded, actionLabel: isArabic ? 'مسح الكل' : 'Clear all', onAction: onClearHistory),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recent.map((item) => InputChip(
                  avatar: const Icon(Icons.history_rounded, size: 17),
                  label: Text(item),
                  onPressed: () => onSelect(item),
                  onDeleted: () => onRemove(item),
                )).toList(growable: false),
          ),
          const SizedBox(height: 24),
        ],
        _SectionTitle(title: isArabic ? 'الأكثر بحثًا' : 'Popular searches', icon: Icons.trending_up_rounded),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: popular.map((item) => ActionChip(
                avatar: const Icon(Icons.search_rounded, size: 17),
                label: Text(item),
                onPressed: () => onSelect(item),
              )).toList(growable: false),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon, this.actionLabel, this.onAction});
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      );
}

class _ResultsFrame<T> extends StatelessWidget {
  const _ResultsFrame({required this.snapshot, required this.itemBuilder, required this.isArabic});
  final AsyncSnapshot<List<T>> snapshot;
  final Widget Function(T item) itemBuilder;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState != ConnectionState.done) return const _SearchSkeleton();
    if (snapshot.hasError) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: isArabic ? 'تعذر تنفيذ البحث' : 'Search failed',
        subtitle: isArabic ? 'تحقق من الاتصال وحاول مرة أخرى' : 'Check your connection and try again',
      );
    }
    final items = snapshot.data ?? const [];
    if (items.isEmpty) {
      return _MessageState(
        icon: Icons.search_off_rounded,
        title: isArabic ? 'لا توجد نتائج' : 'No results found',
        subtitle: isArabic ? 'جرّب كلمة مختلفة أو وسّع نطاق الفلاتر' : 'Try another term or broaden the filters',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => itemBuilder(items[index]),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 112,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: const Center(child: LinearProgressIndicator()),
        ),
      );
}

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({required this.item, required this.isArabic});
  final ProductSummary item;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductDetailPage(slug: item.slug))),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.image == null
                      ? Container(width: 82, height: 82, color: AppColors.surfaceMuted, child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary))
                      : Image.network(item.image!, width: 82, height: 82, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.square(dimension: 82, child: Icon(Icons.broken_image_outlined))),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      Text(item.businessName, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 7),
                      Text(isArabic ? '${item.price} ج.م' : '${item.price} EGP', style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 82, height: 82, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(icon, size: 42, color: AppColors.primary)),
                const SizedBox(height: 17),
                Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.6)),
              ],
            ),
          ),
        ),
      );
}
