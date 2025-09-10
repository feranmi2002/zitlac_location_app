import 'dart:math';
import '../models/geofence.dart';

class GeofenceService {
  /// Returns list of geofences the user is currently inside
  static Future<List<Geofence>> checkGeofences(
      double latitude,
      double longitude,
      List<Geofence> geofences,
      ) async {
    final List<Geofence> inside = [];

    for (final geofence in geofences) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        geofence.latitude,
        geofence.longitude,
      );

      if (distance <= geofence.radius) {
        inside.add(geofence);
      }
    }

    return inside;
  }

  /// Haversine formula (distance in meters)
  static double _calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadius = 6371000; // meters
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);
}
