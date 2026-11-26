import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service result holding coordinates or a user-friendly error reason.
class LocationResult {
  final Position? position;
  final bool isSuccess;
  final String? errorMessage;
  final bool isServiceDisabled;
  final bool isPermissionDenied;

  const LocationResult({
    this.position,
    required this.isSuccess,
    this.errorMessage,
    this.isServiceDisabled = false,
    this.isPermissionDenied = false,
  });

  double? get latitude => position?.latitude;
  double? get longitude => position?.longitude;
}

/// Helper service for GPS Geofencing verification (100% Free, device-native GPS).
class LocationService {
  LocationService._();

  /// Gets the device's live GPS coordinates for geofence validation.
  static Future<LocationResult> getCurrentPosition() async {
    try {
      // 1. Verify device GPS service is turned on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          isSuccess: false,
          isServiceDisabled: true,
          errorMessage: 'Device GPS / Location service is turned off. Please turn on GPS.',
        );
      }

      // 2. Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            isSuccess: false,
            isPermissionDenied: true,
            errorMessage: 'Location permission denied. Location is required to verify library attendance.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          isSuccess: false,
          isPermissionDenied: true,
          errorMessage: 'Location permission permanently denied. Please allow location in App Settings.',
        );
      }

      // 3. Query current device GPS fix with 8-second safety timeout
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        return LocationResult(isSuccess: true, position: pos);
      } catch (_) {
        // Fallback to last known position if fresh fix timed out
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LocationResult(isSuccess: true, position: lastKnown);
        }
        return const LocationResult(
          isSuccess: false,
          errorMessage: 'Could not obtain GPS fix. Please ensure you have a clear GPS signal.',
        );
      }
    } catch (e) {
      debugPrint('LocationService error: $e');
      return LocationResult(
        isSuccess: false,
        errorMessage: 'Location error: $e',
      );
    }
  }

  /// Calculates straight-line distance in meters between two GPS coordinates using Haversine.
  static double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
