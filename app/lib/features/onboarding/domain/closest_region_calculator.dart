import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';

/// Finds the closest riding location to [home] using Haversine distance.
///
/// Returns `null` if [locations] is empty.
RidingLocation? findClosestRegion(
  LatLng home,
  List<RidingLocation> locations,
) {
  if (locations.isEmpty) return null;

  RidingLocation? closest;
  var minDistance = double.infinity;

  for (final loc in locations) {
    final dist = haversineDistance(home, loc.center);
    if (dist < minDistance) {
      minDistance = dist;
      closest = loc;
    }
  }

  return closest;
}

/// Returns the Haversine great-circle distance in km between two points.
double haversineDistance(LatLng a, LatLng b) {
  const earthRadius = 6371.0;
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLng = _toRadians(b.longitude - a.longitude);
  final sinDLat = math.sin(dLat / 2);
  final sinDLng = math.sin(dLng / 2);
  final h = sinDLat * sinDLat +
      math.cos(_toRadians(a.latitude)) *
          math.cos(_toRadians(b.latitude)) *
          sinDLng *
          sinDLng;
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
