import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';

void main() {
  group('GeneratedRoute', () {
    const waypoints = [LatLng(51.5, -0.1), LatLng(51.6, -0.2)];
    const streetViewUrls = ['https://example.com/sv1.jpg'];

    const route = GeneratedRoute(
      encodedPolyline: 'abc123',
      distanceKm: 147.5,
      durationMin: 140,
      narrative: 'A great twisty route through the hills.',
      streetViewUrls: streetViewUrls,
      waypoints: waypoints,
    );

    test('equality — identical instances are equal', () {
      const other = GeneratedRoute(
        encodedPolyline: 'abc123',
        distanceKm: 147.5,
        durationMin: 140,
        narrative: 'A great twisty route through the hills.',
        streetViewUrls: streetViewUrls,
        waypoints: waypoints,
      );
      expect(route, equals(other));
    });

    test('equality — instances with different polyline are not equal', () {
      const other = GeneratedRoute(
        encodedPolyline: 'different',
        distanceKm: 147.5,
        durationMin: 140,
        narrative: 'A great twisty route through the hills.',
        streetViewUrls: streetViewUrls,
        waypoints: waypoints,
      );
      expect(route, isNot(equals(other)));
    });

    test('hashCode — equal objects share hashCode', () {
      const other = GeneratedRoute(
        encodedPolyline: 'abc123',
        distanceKm: 147.5,
        durationMin: 140,
        narrative: 'A great twisty route through the hills.',
        streetViewUrls: streetViewUrls,
        waypoints: waypoints,
      );
      expect(route.hashCode, equals(other.hashCode));
    });

    test('toString — includes distance and waypoint count', () {
      final str = route.toString();
      expect(str, contains('147.5'));
      expect(str, contains('2')); // 2 waypoints
    });

    test('waypoints list is accessible', () {
      expect(route.waypoints, hasLength(2));
      expect(route.waypoints.first.latitude, closeTo(51.5, 0.01));
    });

    test('streetViewUrls list is accessible', () {
      expect(route.streetViewUrls, hasLength(1));
      expect(route.streetViewUrls.first, contains('example.com'));
    });
  });
}
