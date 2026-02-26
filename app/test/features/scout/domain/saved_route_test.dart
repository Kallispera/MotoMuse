import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';
import 'package:motomuse/features/scout/domain/saved_route.dart';

void main() {
  group('SavedRoute', () {
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

    const prefs = RoutePreferences(
      startLocation: '51.5,-0.1',
      distanceKm: 150,
      curviness: 4,
      sceneryType: 'mountains',
      loop: true,
    );

    final savedRoute = SavedRoute(
      id: 'route-1',
      name: 'Sunday twisties',
      route: route,
      preferences: prefs,
      savedAt: DateTime(2025, 6, 15),
    );

    test('equality — identical instances are equal', () {
      final other = SavedRoute(
        id: 'route-1',
        name: 'Sunday twisties',
        route: route,
        preferences: prefs,
        savedAt: DateTime(2025, 6, 15),
      );
      expect(savedRoute, equals(other));
    });

    test('equality — instances with different name are not equal', () {
      final other = savedRoute.copyWith(name: 'Morning ride');
      expect(savedRoute, isNot(equals(other)));
    });

    test('equality — instances with different route are not equal', () {
      const otherRoute = GeneratedRoute(
        encodedPolyline: 'xyz789',
        distanceKm: 100,
        durationMin: 90,
        narrative: 'Different narrative.',
        streetViewUrls: streetViewUrls,
        waypoints: waypoints,
      );
      final other = savedRoute.copyWith(route: otherRoute);
      expect(savedRoute, isNot(equals(other)));
    });

    test('hashCode — equal objects share hashCode', () {
      final other = SavedRoute(
        id: 'route-1',
        name: 'Sunday twisties',
        route: route,
        preferences: prefs,
        savedAt: DateTime(2025, 6, 15),
      );
      expect(savedRoute.hashCode, equals(other.hashCode));
    });

    test('copyWith — replaces specified fields, preserves others', () {
      final copy = savedRoute.copyWith(name: 'Renamed route', id: 'route-2');
      expect(copy.id, 'route-2');
      expect(copy.name, 'Renamed route');
      expect(copy.route, route);
      expect(copy.preferences, prefs);
      expect(copy.savedAt, DateTime(2025, 6, 15));
    });

    test('toString — includes id and name', () {
      final str = savedRoute.toString();
      expect(str, contains('route-1'));
      expect(str, contains('Sunday twisties'));
    });
  });
}
