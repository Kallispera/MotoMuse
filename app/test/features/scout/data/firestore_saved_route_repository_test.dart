import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/scout/data/firestore_saved_route_repository.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';
import 'package:motomuse/features/scout/domain/saved_route.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _uid = 'test-uid';

SavedRoute _testSavedRoute({
  String id = '',
  String name = 'Sunday twisties',
  String routeType = 'day_out',
}) {
  return SavedRoute(
    id: id,
    name: name,
    route: GeneratedRoute(
      encodedPolyline: 'abc123',
      distanceKm: 147.5,
      durationMin: 140,
      narrative: 'A great twisty route through the hills.',
      streetViewUrls: const ['https://example.com/sv1.jpg'],
      waypoints: const [LatLng(51.5, -0.1), LatLng(51.6, -0.2)],
      routeType: routeType,
    ),
    preferences: const RoutePreferences(
      startLocation: '51.5,-0.1',
      distanceKm: 150,
      curviness: 4,
      sceneryType: 'mountains',
      loop: true,
    ),
    savedAt: DateTime(2025, 6, 15),
  );
}

SavedRoute _testSavedRouteWithReturnLeg() {
  return SavedRoute(
    id: '',
    name: 'Breakfast ride',
    route: const GeneratedRoute(
      encodedPolyline: 'outbound123',
      distanceKm: 80,
      durationMin: 90,
      narrative: 'Scenic route to the restaurant and back.',
      streetViewUrls: ['https://example.com/sv1.jpg'],
      waypoints: [LatLng(52, 4.3), LatLng(52.1, 4.5)],
      routeType: 'breakfast_run',
      destinationName: 'Cafe De Molen',
      returnPolyline: 'return456',
      returnDistanceKm: 75,
      returnDurationMin: 85,
      returnWaypoints: [LatLng(52.1, 4.5), LatLng(52, 4.3)],
      returnStreetViewUrls: ['https://example.com/sv-return.jpg'],
    ),
    preferences: const RoutePreferences(
      startLocation: '52.0,4.3',
      distanceKm: 80,
      curviness: 3,
      sceneryType: 'coastline',
      loop: false,
      routeType: 'breakfast_run',
      destinationLat: 52.1,
      destinationLng: 4.5,
      destinationName: 'Cafe De Molen',
    ),
    savedAt: DateTime(2025, 7),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSavedRouteRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreSavedRouteRepository(firestore: firestore);
  });

  group('FirestoreSavedRouteRepository', () {
    // -----------------------------------------------------------------------
    // watchSavedRoutes
    // -----------------------------------------------------------------------

    group('watchSavedRoutes', () {
      test('emits empty list when user has no saved routes', () async {
        final stream = repo.watchSavedRoutes(_uid);
        final routes = await stream.first;
        expect(routes, isEmpty);
      });

      test('emits routes after addSavedRoute is called', () async {
        await repo.addSavedRoute(_uid, _testSavedRoute());
        await repo.addSavedRoute(
          _uid,
          _testSavedRoute(name: 'Evening cruise'),
        );

        final routes = await repo.watchSavedRoutes(_uid).first;
        expect(routes, hasLength(2));
        final names = routes.map((r) => r.name).toSet();
        expect(names, containsAll(['Sunday twisties', 'Evening cruise']));
      });

      test('each route has a non-empty Firestore-generated id', () async {
        await repo.addSavedRoute(_uid, _testSavedRoute());

        final routes = await repo.watchSavedRoutes(_uid).first;
        expect(routes.first.id, isNotEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // addSavedRoute
    // -----------------------------------------------------------------------

    group('addSavedRoute', () {
      test('creates document under users/{uid}/savedRoutes', () async {
        await repo.addSavedRoute(_uid, _testSavedRoute());

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('savedRoutes')
            .get();

        expect(snap.docs, hasLength(1));
        expect(snap.docs.first.data()['name'], 'Sunday twisties');
      });

      test('persists nested route fields correctly', () async {
        await repo.addSavedRoute(_uid, _testSavedRoute());

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('savedRoutes')
            .get();

        final routeData =
            snap.docs.first.data()['route'] as Map<String, dynamic>;
        expect(routeData['encodedPolyline'], 'abc123');
        expect(routeData['distanceKm'], 147.5);
        expect(routeData['durationMin'], 140);
        expect(routeData['narrative'], contains('twisty'));
        expect(routeData['streetViewUrls'], hasLength(1));
        expect(routeData['routeType'], 'day_out');
      });

      test('persists nested preferences fields correctly', () async {
        await repo.addSavedRoute(_uid, _testSavedRoute());

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('savedRoutes')
            .get();

        final prefsData =
            snap.docs.first.data()['preferences'] as Map<String, dynamic>;
        expect(prefsData['startLocation'], '51.5,-0.1');
        expect(prefsData['distanceKm'], 150);
        expect(prefsData['curviness'], 4);
        expect(prefsData['sceneryType'], 'mountains');
        expect(prefsData['loop'], isTrue);
      });

      test('serializes waypoints as lat/lng maps', () async {
        await repo.addSavedRoute(_uid, _testSavedRoute());

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('savedRoutes')
            .get();

        final routeData =
            snap.docs.first.data()['route'] as Map<String, dynamic>;
        final waypoints = routeData['waypoints'] as List<dynamic>;
        expect(waypoints, hasLength(2));
        final first = waypoints.first as Map<String, dynamic>;
        expect(first['lat'], closeTo(51.5, 0.01));
        expect(first['lng'], closeTo(-0.1, 0.01));
      });

      test('handles optional return-leg fields', () async {
        await repo.addSavedRoute(_uid, _testSavedRouteWithReturnLeg());

        final routes = await repo.watchSavedRoutes(_uid).first;
        final route = routes.first.route;
        expect(route.returnPolyline, 'return456');
        expect(route.returnDistanceKm, 75);
        expect(route.returnDurationMin, 85);
        expect(route.returnWaypoints, hasLength(2));
        expect(route.returnStreetViewUrls, hasLength(1));
        expect(route.destinationName, 'Cafe De Molen');
      });

      test('round-trips preferences with destination fields', () async {
        await repo.addSavedRoute(_uid, _testSavedRouteWithReturnLeg());

        final routes = await repo.watchSavedRoutes(_uid).first;
        final prefs = routes.first.preferences;
        expect(prefs.routeType, 'breakfast_run');
        expect(prefs.destinationLat, closeTo(52.1, 0.01));
        expect(prefs.destinationLng, closeTo(4.5, 0.01));
        expect(prefs.destinationName, 'Cafe De Molen');
      });

      test('ignores caller-supplied id and uses Firestore-generated id',
          () async {
        await repo.addSavedRoute(
          _uid,
          _testSavedRoute(id: 'caller-supplied-id'),
        );

        final routes = await repo.watchSavedRoutes(_uid).first;
        expect(routes.first.id, isNot('caller-supplied-id'));
        expect(routes.first.id, isNotEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // deleteSavedRoute
    // -----------------------------------------------------------------------

    group('deleteSavedRoute', () {
      test('removes the document from Firestore', () async {
        await repo.addSavedRoute(_uid, _testSavedRoute());

        final id = (await repo.watchSavedRoutes(_uid).first).first.id;

        await repo.deleteSavedRoute(_uid, id);

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('savedRoutes')
            .get();

        expect(snap.docs, isEmpty);
      });

      test('does not throw for non-existent route', () async {
        await expectLater(
          () => repo.deleteSavedRoute(_uid, 'non-existent-id'),
          returnsNormally,
        );
      });
    });

    // -----------------------------------------------------------------------
    // Data isolation
    // -----------------------------------------------------------------------

    test('routes are stored per-user and do not bleed across uids', () async {
      await repo.addSavedRoute('uid-alice', _testSavedRoute(name: 'Alice'));
      await repo.addSavedRoute('uid-bob', _testSavedRoute(name: 'Bob'));

      final aliceRoutes = await repo.watchSavedRoutes('uid-alice').first;
      final bobRoutes = await repo.watchSavedRoutes('uid-bob').first;

      expect(aliceRoutes.map((r) => r.name), contains('Alice'));
      expect(aliceRoutes.map((r) => r.name), isNot(contains('Bob')));
      expect(bobRoutes.map((r) => r.name), contains('Bob'));
    });
  });
}
