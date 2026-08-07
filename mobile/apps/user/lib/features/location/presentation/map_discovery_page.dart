import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../directory/data/business.dart';
import '../../directory/presentation/business_detail_page.dart';
import '../data/location_service.dart';

const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
const _resultCardExtent = 320.0;

class MapDiscoveryPage extends ConsumerStatefulWidget {
  const MapDiscoveryPage({super.key});

  @override
  ConsumerState<MapDiscoveryPage> createState() => _MapDiscoveryPageState();
}

class _MapDiscoveryPageState extends ConsumerState<MapDiscoveryPage> {
  final _searchController = TextEditingController();
  final _resultsController = ScrollController();
  final Map<Circle, Business> _businessByCircle = {};

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
  double _radius = 10;
  double? _minimumRating;
  bool _featuredOnly = false;
  String? _message;
  int _requestRevision = 0;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;
  int get _filterCount =>
      (_minimumRating == null ? 0 : 1) + (_featuredOnly ? 1 : 0);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildMap()),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _MapToolbar(
                  controller: _searchController,
                  isArabic: _isArabic,
                  loading: _loading,
                  radius: _radius,
                  resultCount: _visibleItems.length,
                  filterCount: _filterCount,
                  onSearchChanged: _onSearchChanged,
                  onSearchSubmitted: (_) => _searchNow(),
                  onLocation: _loadNearby,
                  onFilters: _showFilters,
                ),
              ),
              if (_loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
              if (_pendingAreaCenter != null)
                Positioned(
                  top: 154,
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
                  top: _pendingAreaCenter == null ? 154 : 208,
                  left: 16,
                  right: 16,
                  child: _MessageCard(message: _message!),
                ),
              if (_visibleItems.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: SizedBox(
                    height: 164,
                    child: ListView.separated(
                      controller: _resultsController,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: _visibleItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        final business = _visibleItems[index];
                        return _BusinessMapCard(
                          business: business,
                          isArabic: _isArabic,
                          selected: _selected?.id == business.id,
                          onTap: () => _selectBusiness(business),
                          onDetails: () => _openDetails(business),
                        );
                      },
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
          child: Container(
            margin: const EdgeInsets.all(28),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_searching_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 20),
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
      },
      onCameraIdle: _onCameraIdle,
      onStyleLoadedCallback: () {
        _styleLoaded = true;
        _refreshMarkers();
      },
    );
  }

  Future<void> _loadNearby() async {
    setState(() {
      _loading = true;
      _message = null;
      _pendingAreaCenter = null;
    });

    try {
      final coordinates = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() => _coordinates = coordinates);
      await _moveCameraTo(coordinates, zoom: _zoomForRadius(_radius));
      await _fetchNearby(coordinates);
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = switch (error.failure) {
          LocationFailure.serviceDisabled => _tr(
              'فعّل خدمة الموقع ثم حاول مجددًا',
              'Enable location services and try again',
            ),
          LocationFailure.denied => _tr(
              'لم يتم السماح باستخدام الموقع',
              'Location permission was denied',
            ),
          LocationFailure.deniedForever => _tr(
              'صلاحية الموقع مرفوضة دائمًا؛ فعّلها من إعدادات التطبيق',
              'Location permission is permanently denied; enable it in settings',
            ),
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      _searchNow,
    );
  }

  Future<void> _searchNow() async {
    final coordinates = _coordinates;
    if (coordinates == null) {
      await _loadNearby();
      return;
    }
    await _fetchNearby(coordinates);
  }

  Future<void> _searchThisArea() async {
    final center = _pendingAreaCenter;
    if (center == null) return;
    setState(() {
      _coordinates = center;
      _pendingAreaCenter = null;
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
      final items = await ref.read(businessRepositoryProvider).nearby(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            radiusKm: _radius,
            query: _searchController.text,
            minRating: _minimumRating,
            featuredOnly: _featuredOnly,
            cancelToken: cancelToken,
          );
      if (!mounted || revision != _requestRevision) return;

      setState(() {
        _visibleItems = items;
        _selected = items.isEmpty ? null : items.first;
        _message = items.isEmpty
            ? (_searchController.text.trim().isEmpty && _filterCount == 0
                ? _tr(
                    'لا توجد أنشطة ضمن النطاق المحدد',
                    'No businesses in this radius',
                  )
                : _tr(
                    'لا توجد نتائج مطابقة للبحث والفلاتر',
                    'No results match this search and filters',
                  ))
            : null;
      });
      if (_resultsController.hasClients) {
        _resultsController.jumpTo(0);
      }
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
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _tr('خيارات الخريطة', 'Map options'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  _tr('نطاق البحث', 'Search radius'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  children: [5.0, 10.0, 20.0, 50.0]
                      .map(
                        (value) => ChoiceChip(
                          selected: radius == value,
                          label: Text(
                            _tr(
                              '${value.toInt()} كم',
                              '${value.toInt()} km',
                            ),
                          ),
                          onSelected: (_) =>
                              setModalState(() => radius = value),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
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
                  onChanged: (value) =>
                      setModalState(() => rating = value),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: featured,
                  onChanged: (value) =>
                      setModalState(() => featured = value),
                  secondary: const Icon(Icons.workspace_premium_outlined),
                  title: Text(
                    _tr(
                      'الأنشطة المميزة فقط',
                      'Featured businesses only',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
    _businessByCircle.clear();
    for (final business in _visibleItems.where((item) => item.hasCoordinates)) {
      final selected = _selected?.id == business.id;
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(business.latitude!, business.longitude!),
          circleRadius: selected ? 13 : 9,
          circleColor: selected ? '#667EEA' : '#0A8F68',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
      _businessByCircle[circle] = business;
    }
  }

  void _onCircleTapped(Circle circle) {
    final business = _businessByCircle[circle];
    if (business != null) {
      _selectBusiness(business, scrollToCard: true);
    }
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

class _MapToolbar extends StatelessWidget {
  const _MapToolbar({
    required this.controller,
    required this.isArabic,
    required this.loading,
    required this.radius,
    required this.resultCount,
    required this.filterCount,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onLocation,
    required this.onFilters,
  });

  final TextEditingController controller;
  final bool isArabic;
  final bool loading;
  final double radius;
  final int resultCount;
  final int filterCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onLocation;
  final VoidCallback onFilters;

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
                    isArabic
                        ? '$resultCount نتيجة ضمن ${radius.toInt()} كم'
                        : '$resultCount results within ${radius.toInt()} km',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
}

class _BusinessMapCard extends StatelessWidget {
  const _BusinessMapCard({
    required this.business,
    required this.isArabic,
    required this.selected,
    required this.onTap,
    required this.onDetails,
  });

  final Business business;
  final bool isArabic;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 310,
        child: Card(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          business.displayNameFor(isArabic ? 'ar' : 'en'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          business.categoryName.isEmpty
                              ? business.area
                              : business.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 17,
                              color: AppColors.accentDark,
                            ),
                            Text(' ${business.rating.toStringAsFixed(1)}'),
                            if (business.distanceKm != null) ...[
                              const Text('  •  '),
                              Text(
                                isArabic
                                    ? '${business.distanceKm!.toStringAsFixed(1)} كم'
                                    : '${business.distanceKm!.toStringAsFixed(1)} km',
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: onDetails,
                          child: Text(
                            isArabic ? 'عرض التفاصيل' : 'View details',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
