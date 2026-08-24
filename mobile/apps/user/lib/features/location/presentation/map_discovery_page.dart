import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../directory/data/business.dart';
import '../../directory/presentation/business_detail_page.dart';
import '../data/location_service.dart';

const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
const _resultCardExtent = 202.0;

// يُستخدم كمركز افتراضي للخريطة لما نتعذّر نجيب موقع المستخدم الحقيقي
// (صلاحية مرفوضة، متصفح ما بيدعمش الموقع، إلخ) — عشان الخريطة تفضل
// تعرض أنشطة حقيقية بدل ما تفضل شاشة بيضاء لحد الأبد.
const _defaultCoordinates = UserCoordinates(latitude: 30.0444, longitude: 31.2357);

class MapDiscoveryPage extends ConsumerStatefulWidget {
  const MapDiscoveryPage({super.key});

  @override
  ConsumerState<MapDiscoveryPage> createState() => _MapDiscoveryPageState();
}

class _MapDiscoveryPageState extends ConsumerState<MapDiscoveryPage> {
  final _searchController = TextEditingController();
  final _resultsController = ScrollController();
  final _sheetController = DraggableScrollableController();
  static const _sheetMinSize = 0.22;
  static const _sheetMaxSize = 0.75;
  final Map<Circle, Business> _businessByCircle = {};
  final Map<Symbol, Business> _businessBySymbol = {};

  MapLibreMapController? _mapController;
  UserCoordinates? _coordinates;
  UserCoordinates? _pendingAreaCenter;
  List<Business> _visibleItems = const [];
  Business? _selected;
  Timer? _searchDebounce;
  CancelToken? _searchCancelToken;
  bool _loading = false;
  bool _styleLoaded = false;
  bool _suppressNextCameraIdle = false;
  bool _listMode = false;
  // مفصولة عن _coordinates عمدًا: لو مافيش موقع حقيقي، منعرضش نتائج "قريب
  // مني" بمركز افتراضي عشوائي (القاهرة) نصف قطر صغير — لأن بيانات تجريبية
  // متفرقة على محافظات مختلفة كانت بتختفي كلها. بدلها نعرض كل الأنشطة اللي
  // ليها إحداثيات زي الصفحة القديمة (directory/map.html) بالظبط، ولما
  // الموقع الحقيقي يتوفر أو المستخدم يختار نقطة على الخريطة يدويًا، نرجع
  // لبحث "قريب مني" الحقيقي بنصف قطر.
  bool _usingRealLocation = false;
  double _radius = 10;
  double? _minimumRating;
  bool _featuredOnly = false;
  int? _categoryId;
  String? _businessType;
  String? _message;
  int _requestRevision = 0;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;
  int get _filterCount =>
      (_minimumRating == null ? 0 : 1) +
      (_featuredOnly ? 1 : 0) +
      (_categoryId == null ? 0 : 1) +
      (_businessType == null ? 0 : 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNearby());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCancelToken?.cancel('Map search disposed');
    _searchController.dispose();
    _resultsController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _listMode ? _buildListResults() : _buildMap(),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _MapToolbar(
                  controller: _searchController,
                  isArabic: _isArabic,
                  loading: _loading,
                  listMode: _listMode,
                  radius: _radius,
                  usingRealLocation: _usingRealLocation,
                  resultCount: _visibleItems.length,
                  filterCount: _filterCount,
                  onSearchChanged: _onSearchChanged,
                  onSearchSubmitted: (_) => _searchNow(),
                  onLocation: _loadNearby,
                  onFilters: _showFilters,
                  onToggleMode: () => setState(() => _listMode = !_listMode),
                ),
              ),
              Positioned(
                top: 148,
                left: 0,
                right: 0,
                child: _MapQuickFilters(
                  isArabic: _isArabic,
                  businessType: _businessType,
                  categoryId: _categoryId,
                  categories:
                      ref.watch(homeProvider).valueOrNull?.categories ?? const [],
                  onBusinessTypeChanged: _setBusinessType,
                  onCategoryChanged: _setCategory,
                  onClear: _clearQuickFilters,
                ),
              ),
              if (_loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
              if (!_listMode && _pendingAreaCenter != null)
                Positioned(
                  top: 204,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _searchThisArea,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      label: Text(
                        _tr('ابحث في هذه المنطقة', 'Search this area'),
                      ),
                    ),
                  ),
                ),
              if (_message != null)
                Positioned(
                  top: !_listMode && _pendingAreaCenter != null ? 258 : 204,
                  left: 16,
                  right: 16,
                  child: _MessageCard(message: _message!),
                ),
              if (!_listMode && _selected != null)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.sizeOf(context).height * _sheetMinSize + 14,
                  child: _SelectedBusinessPopup(
                    business: _selected!,
                    isArabic: _isArabic,
                    onClose: () => setState(() => _selected = null),
                    onDetails: () => _openDetails(_selected!),
                  ),
                ),
              if (!_listMode && _visibleItems.isNotEmpty)
                Positioned.fill(
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _sheetMinSize,
                    minChildSize: _sheetMinSize,
                    maxChildSize: _sheetMaxSize,
                    snap: true,
                    builder: (context, scrollController) => _NearbyPlacesSheet(
                      items: _visibleItems,
                      isArabic: _isArabic,
                      selectedId: _selected?.id,
                      horizontalController: _resultsController,
                      sheetScrollController: scrollController,
                      onDragUpdate: (deltaY) {
                        final screenHeight = MediaQuery.sizeOf(context).height;
                        final next = (_sheetController.size - deltaY / screenHeight)
                            .clamp(_sheetMinSize, _sheetMaxSize);
                        _sheetController.jumpTo(next);
                      },
                      onSelect: (business) => _selectBusiness(business),
                      onDetails: _openDetails,
                      onDirections: _openDirections,
                      onShowOnMap: (business) => _selectBusiness(business),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildMap() {
    final coordinates = _coordinates;
    if (coordinates == null) {
      return ColoredBox(
        color: AppColors.surfaceMuted,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_searching_rounded,
                  color: AppColors.primary,
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  _tr(
                    'جارٍ تحديد موقعك لعرض الأنشطة القريبة',
                    'Finding your location to show nearby businesses',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MapLibreMap(
      styleString: _mapStyle,
      initialCameraPosition: CameraPosition(
        target: LatLng(coordinates.latitude, coordinates.longitude),
        zoom: _zoomForRadius(_radius),
      ),
      myLocationEnabled: true,
      compassEnabled: true,
      onMapCreated: (controller) {
        _mapController = controller;
        controller.onCircleTapped.add(_onCircleTapped);
        controller.onSymbolTapped.add(_onSymbolTapped);
      },
      onCameraIdle: _onCameraIdle,
      onStyleLoadedCallback: () {
        _styleLoaded = true;
        _refreshMarkers();
      },
    );
  }

  Widget _buildListResults() => ColoredBox(
        color: AppColors.surfaceMuted,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 214, 14, 24),
          itemCount: _visibleItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final business = _visibleItems[index];
            return _BusinessListCard(
              business: business,
              isArabic: _isArabic,
              onDetails: () => _openDetails(business),
              onDirections: () => _openDirections(business),
              onShowOnMap: () async {
                setState(() => _listMode = false);
                await Future<void>.delayed(const Duration(milliseconds: 80));
                await _selectBusiness(business, scrollToCard: true);
              },
            );
          },
        ),
      );

  Future<void> _loadNearby() async {
    setState(() {
      _loading = true;
      _message = null;
      _pendingAreaCenter = null;
    });
    try {
      final coordinates = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() {
        _coordinates = coordinates;
        _usingRealLocation = true;
      });
      await _moveCameraTo(coordinates, zoom: _zoomForRadius(_radius));
      await _fetchNearby(coordinates);
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = switch (error.failure) {
          LocationFailure.serviceDisabled => _tr(
              'فعّل خدمة الموقع ثم حاول مجددًا. نعرض الآن كل الأنشطة على الخريطة.',
              'Enable location services and try again. Showing all businesses on the map for now.',
            ),
          LocationFailure.denied => _tr(
              'لم يتم السماح باستخدام الموقع. نعرض الآن كل الأنشطة على الخريطة.',
              'Location permission was denied. Showing all businesses on the map for now.',
            ),
          LocationFailure.deniedForever => _tr(
              'صلاحية الموقع مرفوضة دائمًا؛ فعّلها من إعدادات التطبيق. نعرض الآن كل الأنشطة على الخريطة.',
              'Location permission is permanently denied; enable it in settings. Showing all businesses on the map for now.',
            ),
        };
      });
      // منطقة افتراضية بدل ما تفضل الشاشة فاضية لحد الأبد لو الموقع مرفوض.
      // بدون تصفية بنصف قطر — زي الصفحة القديمة تمامًا — لأن مركز افتراضي
      // ثابت (القاهرة) ممكن يكون بعيد عن كل الأنشطة الموجودة فعليًا.
      if (_coordinates == null) {
        setState(() {
          _coordinates = _defaultCoordinates;
          _usingRealLocation = false;
        });
        await _moveCameraTo(_defaultCoordinates, zoom: 6);
        await _fetchNearby(_defaultCoordinates);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), _searchNow);
  }

  Future<void> _searchNow() async {
    final coordinates = _coordinates;
    if (coordinates == null) {
      await _loadNearby();
      return;
    }
    await _fetchNearby(coordinates);
  }

  Future<void> _setBusinessType(String? value) async {
    setState(() => _businessType = value);
    await _searchNow();
  }

  Future<void> _setCategory(int? value) async {
    setState(() => _categoryId = value);
    await _searchNow();
  }

  Future<void> _clearQuickFilters() async {
    if (_businessType == null && _categoryId == null) return;
    setState(() {
      _businessType = null;
      _categoryId = null;
    });
    await _searchNow();
  }

  Future<void> _searchThisArea() async {
    final center = _pendingAreaCenter;
    if (center == null) return;
    setState(() {
      _coordinates = center;
      _pendingAreaCenter = null;
      // المستخدم اختار نقطة بنفسه بالسحب على الخريطة — بحث "قريب من هنا"
      // بنصف قطر بقى له معنى حقيقي دلوقتي، بعكس مركز افتراضي عشوائي.
      _usingRealLocation = true;
    });
    await _fetchNearby(center);
  }

  void _onCameraIdle() {
    if (_suppressNextCameraIdle) {
      _suppressNextCameraIdle = false;
      return;
    }
    final target = _mapController?.cameraPosition?.target;
    final current = _coordinates;
    if (!mounted || target == null || current == null) return;
    final latitudeDelta = (target.latitude - current.latitude).abs();
    final longitudeDelta = (target.longitude - current.longitude).abs();
    if (latitudeDelta < 0.0005 && longitudeDelta < 0.0005) return;
    setState(() {
      _pendingAreaCenter = UserCoordinates(
        latitude: target.latitude,
        longitude: target.longitude,
      );
    });
  }

  Future<void> _fetchNearby(UserCoordinates coordinates) async {
    final revision = ++_requestRevision;
    _searchCancelToken?.cancel('Superseded by a newer map search');
    final cancelToken = CancelToken();
    _searchCancelToken = cancelToken;
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final items = _usingRealLocation
          ? await ref.read(businessRepositoryProvider).nearby(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                radiusKm: _radius,
                query: _searchController.text,
                categoryId: _categoryId,
                businessType: _businessType,
                minRating: _minimumRating,
                featuredOnly: _featuredOnly,
                cancelToken: cancelToken,
              )
          : await ref.read(businessRepositoryProvider).search(
                _searchController.text,
                categoryId: _categoryId,
                businessType: _businessType,
                minRating: _minimumRating,
                featuredOnly: _featuredOnly,
                cancelToken: cancelToken,
              );
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _visibleItems = items;
        _selected = items.isEmpty ? null : items.first;
        _message = items.isEmpty
            ? _tr(
                'لا توجد نتائج مطابقة ضمن المنطقة الحالية',
                'No matching results in this area',
              )
            : null;
      });
      if (_resultsController.hasClients) _resultsController.jumpTo(0);
      await _refreshMarkers();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || !mounted) return;
      setState(() {
        _message = _tr(
          'تعذر تحميل نتائج الخريطة. حاول مرة أخرى.',
          'Could not load map results. Please try again.',
        );
      });
    } finally {
      if (mounted && revision == _requestRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showFilters() async {
    var radius = _radius;
    var rating = _minimumRating;
    var featured = _featuredOnly;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _tr('خيارات الخريطة', 'Map options'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 18),
                Text(
                  _tr('نطاق البحث', 'Search radius'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [5.0, 10.0, 20.0, 50.0]
                      .map(
                        (value) => ChoiceChip(
                          selected: radius == value,
                          label: Text(
                            _tr('${value.toInt()} كم', '${value.toInt()} km'),
                          ),
                          onSelected: (_) =>
                              setModalState(() => radius = value),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<double?>(
                  initialValue: rating,
                  decoration: InputDecoration(
                    labelText: _tr('أقل تقييم', 'Minimum rating'),
                    prefixIcon: const Icon(Icons.star_outline_rounded),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(_tr('أي تقييم', 'Any rating')),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(_tr('3 نجوم فأكثر', '3+ stars')),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text(_tr('4 نجوم فأكثر', '4+ stars')),
                    ),
                    DropdownMenuItem(
                      value: 4.5,
                      child: Text(_tr('4.5 نجمة فأكثر', '4.5+ stars')),
                    ),
                  ],
                  onChanged: (value) => setModalState(() => rating = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: featured,
                  onChanged: (value) =>
                      setModalState(() => featured = value),
                  secondary: const Icon(Icons.workspace_premium_outlined),
                  title: Text(
                    _tr('الأنشطة المميزة فقط', 'Featured businesses only'),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_tr('تطبيق', 'Apply')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied != true || !mounted) return;
    setState(() {
      _radius = radius;
      _minimumRating = rating;
      _featuredOnly = featured;
    });
    await _searchNow();
  }

  Future<void> _refreshMarkers() async {
    final controller = _mapController;
    if (!_styleLoaded || controller == null) return;
    await controller.clearCircles();
    await controller.clearSymbols();
    _businessByCircle.clear();
    _businessBySymbol.clear();
    for (final business in _visibleItems.where((item) => item.hasCoordinates)) {
      final selected = _selected?.id == business.id;
      final geometry = LatLng(business.latitude!, business.longitude!);
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: geometry,
          circleRadius: selected ? 9 : 6,
          circleColor: selected ? '#6C5CE7' : _markerColor(business),
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: selected ? 3 : 2,
        ),
      );
      _businessByCircle[circle] = business;

      final label = _markerLabel(business);
      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: geometry,
          textField: label,
          textSize: selected ? 13 : 11.5,
          textColor: selected ? '#6C5CE7' : '#17212B',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.4,
          textAnchor: 'bottom',
          textOffset: const Offset(0, -0.9),
          textJustify: 'center',
        ),
      );
      _businessBySymbol[symbol] = business;
    }
  }

  String _markerLabel(Business business) {
    var name = business.displayNameFor(_isArabic ? 'ar' : 'en');
    if (name.length > 16) name = '${name.substring(0, 15)}…';
    final distance = business.distanceKm;
    final subtitle = distance != null
        ? _tr('${distance.toStringAsFixed(1)} كم', '${distance.toStringAsFixed(1)} km')
        : (business.categoryName.isNotEmpty ? business.categoryName : business.area);
    return subtitle.isEmpty ? name : '$name\n$subtitle';
  }

  String _markerColor(Business business) => switch (business.businessType) {
        'craft' => '#E8952E',
        'public' => '#3478F6',
        _ => '#0A8F68',
      };

  void _onCircleTapped(Circle circle) {
    final business = _businessByCircle[circle];
    if (business != null) _selectBusiness(business, scrollToCard: true);
  }

  void _onSymbolTapped(Symbol symbol) {
    final business = _businessBySymbol[symbol];
    if (business != null) _selectBusiness(business, scrollToCard: true);
  }

  Future<void> _selectBusiness(
    Business business, {
    bool scrollToCard = false,
  }) async {
    setState(() => _selected = business);
    await _refreshMarkers();
    if (scrollToCard) {
      final index = _visibleItems.indexWhere((item) => item.id == business.id);
      if (index >= 0 && _resultsController.hasClients) {
        final target = (index * _resultCardExtent).clamp(
          0.0,
          _resultsController.position.maxScrollExtent,
        );
        await _resultsController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
    if (_mapController != null && business.hasCoordinates) {
      await _moveCameraTo(
        UserCoordinates(
          latitude: business.latitude!,
          longitude: business.longitude!,
        ),
      );
    }
  }

  Future<void> _moveCameraTo(
    UserCoordinates coordinates, {
    double? zoom,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    _suppressNextCameraIdle = true;
    final update = zoom == null
        ? CameraUpdate.newLatLng(
            LatLng(coordinates.latitude, coordinates.longitude),
          )
        : CameraUpdate.newLatLngZoom(
            LatLng(coordinates.latitude, coordinates.longitude),
            zoom,
          );
    await controller.animateCamera(update);
  }

  Future<void> _openDirections(Business business) async {
    if (!business.hasCoordinates) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${business.latitude},${business.longitude}',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('تعذر فتح تطبيق الخرائط', 'Could not open maps'),
          ),
        ),
      );
    }
  }

  void _openDetails(Business business) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BusinessDetailPage(slug: business.slug),
        ),
      );

  double _zoomForRadius(double radius) => switch (radius) {
        <= 5 => 13,
        <= 10 => 12,
        <= 20 => 11,
        _ => 10,
      };
}

class _MapQuickFilters extends StatelessWidget {
  const _MapQuickFilters({
    required this.isArabic,
    required this.businessType,
    required this.categoryId,
    required this.categories,
    required this.onBusinessTypeChanged,
    required this.onCategoryChanged,
    required this.onClear,
  });

  final bool isArabic;
  final String? businessType;
  final int? categoryId;
  final List<Map<String, dynamic>> categories;
  final ValueChanged<String?> onBusinessTypeChanged;
  final ValueChanged<int?> onCategoryChanged;
  final VoidCallback onClear;

  String _categoryName(Map<String, dynamic> category) {
    final ar = category['name_ar']?.toString() ?? '';
    final en = category['name_en']?.toString() ?? '';
    return isArabic ? (ar.isNotEmpty ? ar : en) : (en.isNotEmpty ? en : ar);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          children: [
            _QuickFilterChip(
              label: isArabic ? 'الكل' : 'All',
              icon: Icons.explore_outlined,
              selected: businessType == null && categoryId == null,
              onSelected: onClear,
            ),
            _QuickFilterChip(
              label: isArabic ? 'محلات' : 'Shops',
              icon: Icons.storefront_outlined,
              selected: businessType == 'shop',
              onSelected: () =>
                  onBusinessTypeChanged(businessType == 'shop' ? null : 'shop'),
            ),
            _QuickFilterChip(
              label: isArabic ? 'حرف ومهن' : 'Crafts',
              icon: Icons.handyman_outlined,
              selected: businessType == 'craft',
              onSelected: () => onBusinessTypeChanged(
                businessType == 'craft' ? null : 'craft',
              ),
            ),
            _QuickFilterChip(
              label: isArabic ? 'خدمات عامة' : 'Public',
              icon: Icons.account_balance_outlined,
              selected: businessType == 'public',
              onSelected: () => onBusinessTypeChanged(
                businessType == 'public' ? null : 'public',
              ),
            ),
            ...categories.take(8).map((category) {
              final id = int.tryParse(category['id']?.toString() ?? '');
              if (id == null) return const SizedBox.shrink();
              return _QuickFilterChip(
                label: _categoryName(category),
                icon: Icons.category_outlined,
                selected: categoryId == id,
                onSelected: () => onCategoryChanged(categoryId == id ? null : id),
              );
            }),
          ],
        ),
      );
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: FilterChip(
          selected: selected,
          showCheckmark: false,
          avatar: Icon(icon, size: 17),
          label: Text(label),
          onSelected: (_) => onSelected(),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primarySoft,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          labelStyle: TextStyle(
            color: selected ? AppColors.primary : null,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _MapToolbar extends StatelessWidget {
  const _MapToolbar({
    required this.controller,
    required this.isArabic,
    required this.loading,
    required this.listMode,
    required this.radius,
    required this.usingRealLocation,
    required this.resultCount,
    required this.filterCount,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onLocation,
    required this.onFilters,
    required this.onToggleMode,
  });

  final TextEditingController controller;
  final bool isArabic;
  final bool loading;
  final bool listMode;
  final double radius;
  final bool usingRealLocation;
  final int resultCount;
  final int filterCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onLocation;
  final VoidCallback onFilters;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            TextField(
              controller: controller,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: isArabic
                    ? 'ابحث عن محل أو منتج أو خدمة'
                    : 'Search for a business, product, or service',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: isArabic ? 'موقعي الحالي' : 'My location',
                  onPressed: loading ? null : onLocation,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    usingRealLocation
                        ? (isArabic
                            ? '$resultCount نتيجة ضمن ${radius.toInt()} كم'
                            : '$resultCount results within ${radius.toInt()} km')
                        : (isArabic
                            ? '$resultCount نتيجة'
                            : '$resultCount results'),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: listMode
                      ? (isArabic ? 'عرض الخريطة' : 'Map view')
                      : (isArabic ? 'عرض القائمة' : 'List view'),
                  onPressed: onToggleMode,
                  icon: Icon(
                    listMode ? Icons.map_outlined : Icons.view_list_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: onFilters,
                  icon: Badge(
                    isLabelVisible: filterCount > 0,
                    label: Text('$filterCount'),
                    child: const Icon(Icons.tune_rounded, size: 19),
                  ),
                  label: Text(isArabic ? 'الفلاتر' : 'Filters'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(message, textAlign: TextAlign.center)),
            ],
          ),
        ),
      );
}

class _NearbyPlacesSheet extends StatelessWidget {
  const _NearbyPlacesSheet({
    required this.items,
    required this.isArabic,
    required this.selectedId,
    required this.horizontalController,
    required this.sheetScrollController,
    required this.onDragUpdate,
    required this.onSelect,
    required this.onDetails,
    required this.onDirections,
    required this.onShowOnMap,
  });

  final List<Business> items;
  final bool isArabic;
  final int? selectedId;
  final ScrollController horizontalController;
  final ScrollController sheetScrollController;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<Business> onSelect;
  final ValueChanged<Business> onDetails;
  final ValueChanged<Business> onDirections;
  final ValueChanged<Business> onShowOnMap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) => onDragUpdate(details.primaryDelta ?? 0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isArabic
                              ? '${items.length} محل قريب منك'
                              : '${items.length} places near you',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 128,
              child: ListView.separated(
                controller: horizontalController,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final business = items[index];
                  return _BusinessMapCard(
                    business: business,
                    isArabic: isArabic,
                    selected: selectedId == business.id,
                    onTap: () => onSelect(business),
                    onDetails: () => onDetails(business),
                    onDirections: () => onDirections(business),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: sheetScrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final business = items[index];
                  return _BusinessListCard(
                    business: business,
                    isArabic: isArabic,
                    onDetails: () => onDetails(business),
                    onDirections: () => onDirections(business),
                    onShowOnMap: () => onShowOnMap(business),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _SelectedBusinessPopup extends StatelessWidget {
  const _SelectedBusinessPopup({
    required this.business,
    required this.isArabic,
    required this.onClose,
    required this.onDetails,
  });

  final Business business;
  final bool isArabic;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final image = business.coverImage ?? business.logo;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: image == null || image.isEmpty
                    ? const ColoredBox(
                        color: AppColors.primarySoft,
                        child: Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      )
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: AppColors.primarySoft,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: .45),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.displayNameFor(isArabic ? 'ar' : 'en'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                if (business.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          business.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
                if (business.isFeatured) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFCB9200)),
                        const SizedBox(width: 3),
                        Text(
                          isArabic ? 'مميز' : 'Featured',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A6400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (business.phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.call_rounded, size: 15, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? 'الهاتف: ${business.phone}' : 'Phone: ${business.phone}',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(isArabic ? 'عرض التفاصيل' : 'View details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessMapCard extends StatelessWidget {
  const _BusinessMapCard({
    required this.business,
    required this.isArabic,
    required this.selected,
    required this.onTap,
    required this.onDetails,
    required this.onDirections,
  });

  final Business business;
  final bool isArabic;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 192,
        child: Card(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _BusinessLogo(business: business, size: 42),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              business.displayNameFor(isArabic ? 'ar' : 'en'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: AppColors.accentDark,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  business.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (business.distanceKm != null) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isArabic
                                          ? '${business.distanceKm!.toStringAsFixed(1)} كم'
                                          : '${business.distanceKm!.toStringAsFixed(1)} km',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          onPressed: onDirections,
                          child: Icon(
                            Icons.directions_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          onPressed: onDetails,
                          child: Text(isArabic ? 'التفاصيل' : 'Details'),
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
}

class _BusinessListCard extends StatelessWidget {
  const _BusinessListCard({
    required this.business,
    required this.isArabic,
    required this.onDetails,
    required this.onDirections,
    required this.onShowOnMap,
  });

  final Business business;
  final bool isArabic;
  final VoidCallback onDetails;
  final VoidCallback onDirections;
  final VoidCallback onShowOnMap;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  _BusinessLogo(business: business, size: 78),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BusinessInfo(
                      business: business,
                      isArabic: isArabic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShowOnMap,
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: Text(isArabic ? 'على الخريطة' : 'On map'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDirections,
                      icon: const Icon(Icons.directions_outlined),
                      label: Text(isArabic ? 'الاتجاهات' : 'Directions'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onDetails,
                      child: Text(isArabic ? 'التفاصيل' : 'Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _BusinessLogo extends StatelessWidget {
  const _BusinessLogo({required this.business, this.size = 72});
  final Business business;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(19),
        ),
        child: business.logo == null
            ? const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 30,
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Image.network(
                  business.logo!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
      );
}

class _BusinessInfo extends StatelessWidget {
  const _BusinessInfo({required this.business, required this.isArabic});
  final Business business;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            business.displayNameFor(isArabic ? 'ar' : 'en'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            business.categoryName.isEmpty ? business.area : business.categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.star_rounded, size: 17, color: AppColors.accentDark),
              Text(business.rating.toStringAsFixed(1)),
              if (business.distanceKm != null)
                Text(
                  isArabic
                      ? '${business.distanceKm!.toStringAsFixed(1)} كم'
                      : '${business.distanceKm!.toStringAsFixed(1)} km',
                ),
              if (business.isFeatured)
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
            ],
          ),
        ],
      );
}
