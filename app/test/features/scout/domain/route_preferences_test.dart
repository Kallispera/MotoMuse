import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

void main() {
  group('RoutePreferences', () {
    const base = RoutePreferences(
      startLocation: '51.5074,-0.1278',
      distanceKm: 150,
      curviness: 3,
      sceneryType: 'forests',
      loop: true,
    );

    test('default lunchStop is false', () {
      expect(base.lunchStop, isFalse);
    });

    test('equality — identical instances are equal', () {
      const other = RoutePreferences(
        startLocation: '51.5074,-0.1278',
        distanceKm: 150,
        curviness: 3,
        sceneryType: 'forests',
        loop: true,
      );
      expect(base, equals(other));
    });

    test('equality — instances with different curviness are not equal', () {
      final other = base.copyWith(curviness: 5);
      expect(base, isNot(equals(other)));
    });

    test('copyWith — replaces specified fields', () {
      final updated = base.copyWith(
        distanceKm: 200,
        loop: false,
        lunchStop: true,
      );
      expect(updated.distanceKm, 200);
      expect(updated.loop, isFalse);
      expect(updated.lunchStop, isTrue);
      // Unchanged fields are preserved.
      expect(updated.startLocation, base.startLocation);
      expect(updated.curviness, base.curviness);
      expect(updated.sceneryType, base.sceneryType);
    });

    test('hashCode — equal objects have the same hashCode', () {
      const other = RoutePreferences(
        startLocation: '51.5074,-0.1278',
        distanceKm: 150,
        curviness: 3,
        sceneryType: 'forests',
        loop: true,
      );
      expect(base.hashCode, equals(other.hashCode));
    });

    test('toString — includes key fields', () {
      final str = base.toString();
      expect(str, contains('150'));
      expect(str, contains('day_out'));
    });
  });
}
