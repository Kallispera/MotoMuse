import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';
import 'package:motomuse/features/onboarding/domain/closest_region_calculator.dart';

RidingLocation _region({
  required String name,
  required double lat,
  required double lng,
}) {
  return RidingLocation(
    id: name.toLowerCase().replaceAll(' ', '-'),
    country: 'nl',
    name: name,
    description: 'Description of $name',
    center: LatLng(lat, lng),
    boundsNe: LatLng(lat + 0.1, lng + 0.1),
    boundsSw: LatLng(lat - 0.1, lng - 0.1),
    photoUrls: const [],
    tags: const [],
    sceneryType: 'mixed',
    order: 0,
  );
}

void main() {
  group('findClosestRegion', () {
    test('returns null for empty list', () {
      final result = findClosestRegion(
        const LatLng(52.0, 5.0),
        [],
      );
      expect(result, isNull);
    });

    test('returns the only region for single-element list', () {
      final region = _region(name: 'Veluwe', lat: 52.25, lng: 5.85);
      final result = findClosestRegion(
        const LatLng(52.0, 5.0),
        [region],
      );
      expect(result, equals(region));
    });

    test('returns the closest region by distance', () {
      final veluwe = _region(name: 'Veluwe', lat: 52.25, lng: 5.85);
      final limburg = _region(name: 'South Limburg', lat: 50.84, lng: 5.87);
      final drenthe = _region(name: 'Drenthe', lat: 52.90, lng: 6.60);

      // Home near Amersfoort — closest to Veluwe.
      final result = findClosestRegion(
        const LatLng(52.15, 5.40),
        [veluwe, limburg, drenthe],
      );
      expect(result?.name, 'Veluwe');
    });

    test('returns the closest region when home is in the south', () {
      final veluwe = _region(name: 'Veluwe', lat: 52.25, lng: 5.85);
      final limburg = _region(name: 'South Limburg', lat: 50.84, lng: 5.87);
      final drenthe = _region(name: 'Drenthe', lat: 52.90, lng: 6.60);

      // Home near Maastricht — closest to South Limburg.
      final result = findClosestRegion(
        const LatLng(50.85, 5.69),
        [veluwe, limburg, drenthe],
      );
      expect(result?.name, 'South Limburg');
    });
  });

  group('haversineDistance', () {
    test('returns 0 for same point', () {
      const p = LatLng(52.0, 5.0);
      expect(haversineDistance(p, p), closeTo(0, 0.001));
    });

    test('returns reasonable distance for known points', () {
      // Amsterdam to Rotterdam ≈ ~57 km.
      const amsterdam = LatLng(52.3676, 4.9041);
      const rotterdam = LatLng(51.9225, 4.4792);
      final dist = haversineDistance(amsterdam, rotterdam);
      expect(dist, closeTo(57, 5));
    });

    test('returns large distance for far apart points', () {
      // Amsterdam to London ≈ ~357 km.
      const amsterdam = LatLng(52.3676, 4.9041);
      const london = LatLng(51.5074, -0.1278);
      final dist = haversineDistance(amsterdam, london);
      expect(dist, closeTo(357, 20));
    });
  });
}
