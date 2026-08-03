import 'package:geolocator/geolocator.dart';

enum LocationFailure { serviceDisabled, denied, deniedForever }

final class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
}

final class UserCoordinates {
  const UserCoordinates({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

final class LocationService {
  Future<UserCoordinates> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationFailure.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.deniedForever);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return UserCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
