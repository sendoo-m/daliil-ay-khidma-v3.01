import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../directory/data/business.dart';
import '../../directory/presentation/business_card.dart';
import '../../directory/presentation/business_detail_page.dart';
import '../data/location_service.dart';

const _openFreeMapStyle = 'https://tiles.openfreemap.org/styles/liberty';

class NearbyPage extends ConsumerStatefulWidget {
  const NearbyPage({super.key});
  @override
  ConsumerState<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends ConsumerState<NearbyPage> {
  double _radius = 10;
  bool _loading = false;
  String? _message;
  List<Business> _items = const [];
  UserCoordinates? _coordinates;
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  final Map<Circle, Business> _businessByCircle = {};

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('بالقرب مني')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('نطاق البحث:'),
                  const SizedBox(width: 12),
                  DropdownButton<double>(
                    value: _radius,
                    items: const [5, 10, 20, 50]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value.toDouble(),
                            child: Text('$value كم'),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (value) => setState(() => _radius = value ?? 10),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.my_location),
                    label: const Text('بحث'),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!),
              ),
            Expanded(child: _buildResults()),
          ],
        ),
      );

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final coordinates = await ref.read(locationServiceProvider).current();
      final businesses = await ref.read(businessRepositoryProvider).nearby(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            radiusKm: _radius,
          );
      if (mounted) {
        setState(() {
          _coordinates = coordinates;
          _items = businesses;
          _message = businesses.isEmpty ? 'لا توجد أنشطة ضمن هذا النطاق' : null;
        });
        await _refreshMap();
      }
    } on LocationException catch (error) {
      if (!mounted) return;
      final message = switch (error.failure) {
        LocationFailure.serviceDisabled => 'فعّل خدمة الموقع ثم حاول مجددًا',
        LocationFailure.denied => 'لم يتم السماح باستخدام الموقع',
        LocationFailure.deniedForever =>
          'صلاحية الموقع مرفوضة دائمًا؛ افتح إعدادات التطبيق لتفعيلها',
      };
      setState(() => _message = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildResults() {
    final coordinates = _coordinates;
    if (coordinates == null) {
      return const Center(
        child: Text('اضغط «بحث» لعرض الخدمات القريبة على الخريطة'),
      );
    }
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: MapLibreMap(
            styleString: _openFreeMapStyle,
            initialCameraPosition: CameraPosition(
              target: LatLng(coordinates.latitude, coordinates.longitude),
              zoom: 13,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            compassEnabled: true,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
          ),
        ),
        Expanded(
          flex: 2,
          child: _items.isEmpty
              ? const Center(child: Text('لا توجد نتائج في هذا النطاق'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (_, index) {
                    final item = _items[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (item.distanceKm != null)
                          Text('${item.distanceKm!.toStringAsFixed(1)} كم'),
                        BusinessCard(business: item),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    _refreshMap();
  }

  Future<void> _refreshMap() async {
    final controller = _mapController;
    final coordinates = _coordinates;
    if (!_styleLoaded || controller == null || coordinates == null) return;

    await controller.clearCircles();
    _businessByCircle.clear();
    for (final business in _items.where((item) => item.hasCoordinates)) {
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(business.latitude!, business.longitude!),
          circleRadius: 9,
          circleColor: '#006C51',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
      _businessByCircle[circle] = business;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(coordinates.latitude, coordinates.longitude),
        _zoomForRadius(_radius),
      ),
    );
  }

  void _onCircleTapped(Circle circle) {
    final business = _businessByCircle[circle];
    if (business == null || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              business.nameAr.isEmpty ? business.nameEn : business.nameAr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (business.distanceKm != null)
              Text('${business.distanceKm!.toStringAsFixed(1)} كم من موقعك'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  this.context,
                  MaterialPageRoute<void>(
                    builder: (_) => BusinessDetailPage(slug: business.slug),
                  ),
                );
              },
              child: const Text('عرض التفاصيل'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openDirections(business),
              icon: const Icon(Icons.directions),
              label: const Text('فتح الاتجاهات'),
            ),
          ],
        ),
      ),
    );
  }

  double _zoomForRadius(double radius) => switch (radius) {
        <= 5 => 13,
        <= 10 => 12,
        <= 20 => 11,
        _ => 10,
      };

  Future<void> _openDirections(Business business) async {
    final origin = _coordinates;
    if (origin == null || !business.hasCoordinates) return;
    final route = '${origin.latitude},${origin.longitude};'
        '${business.latitude},${business.longitude}';
    final uri = Uri.https(
      'www.openstreetmap.org',
      '/directions',
      {'engine': 'fossgis_osrm_car', 'route': route},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
