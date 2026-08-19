import 'package:geocoding/geocoding.dart';

/// Turns raw coordinates into a short human-readable label ("القاهرة، مصر")
/// for display in the home header. Failures (no network, unsupported
/// locale data, geocoder unavailable) are the caller's concern — this
/// only shapes a successful placemark into text.
final class GeocodeService {
  Future<String?> labelFor(double latitude, double longitude) async {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) return null;
    final place = placemarks.first;
    final parts = [place.locality, place.country]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join('، ');
  }
}
