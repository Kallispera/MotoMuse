import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/scout/application/scout_providers.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';
import 'package:motomuse/features/scout/domain/saved_route.dart';
import 'package:motomuse/features/scout/domain/saved_route_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSavedRouteRepository extends Fake implements SavedRouteRepository {
  final _controller = StreamController<List<SavedRoute>>();
  Exception? addError;
  Exception? deleteError;
  bool addCalled = false;
  bool deleteCalled = false;
  String? lastDeletedId;

  void emit(List<SavedRoute> routes) => _controller.add(routes);

  @override
  Stream<List<SavedRoute>> watchSavedRoutes(String uid) => _controller.stream;

  @override
  Future<void> addSavedRoute(String uid, SavedRoute savedRoute) async {
    addCalled = true;
    if (addError != null) throw addError!;
  }

  @override
  Future<void> deleteSavedRoute(String uid, String routeId) async {
    deleteCalled = true;
    lastDeletedId = routeId;
    if (deleteError != null) throw deleteError!;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testUser = AppUser(
  uid: 'uid-test',
  email: 'rider@test.com',
  isEmailVerified: true,
);

SavedRoute _savedRoute({String id = 'sr-1', String name = 'Test route'}) {
  return SavedRoute(
    id: id,
    name: name,
    route: const GeneratedRoute(
      encodedPolyline: 'abc123',
      distanceKm: 100,
      durationMin: 120,
      narrative: 'Test narrative.',
      streetViewUrls: ['https://example.com/sv.jpg'],
      waypoints: [LatLng(51.5, -0.1)],
    ),
    preferences: const RoutePreferences(
      startLocation: '51.5,-0.1',
      distanceKm: 100,
      curviness: 3,
      sceneryType: 'mixed',
      loop: true,
    ),
    savedAt: DateTime(2025, 6, 15),
  );
}

ProviderContainer _buildContainer({
  required _FakeSavedRouteRepository repo,
  AppUser? user,
}) {
  return ProviderContainer(
    overrides: [
      savedRouteRepositoryProvider.overrideWithValue(repo),
      authStateChangesProvider.overrideWith(
        (_) => Stream.value(user),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // userSavedRoutesProvider
  // -------------------------------------------------------------------------

  group('userSavedRoutesProvider', () {
    test('stays loading when user is null (stream never emits)', () async {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final value = container.read(userSavedRoutesProvider);
      expect(value, isA<AsyncLoading<List<SavedRoute>>>());
    });

    test('emits saved routes when user is signed in', () async {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      container.listen(userSavedRoutesProvider, (_, __) {});

      repo.emit([_savedRoute()]);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final value = container.read(userSavedRoutesProvider);
      expect(value.valueOrNull, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // SaveRouteNotifier
  // -------------------------------------------------------------------------

  group('SaveRouteNotifier', () {
    test('initial state is AsyncData(null)', () {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      final state = container.read(saveRouteNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('save() succeeds and state becomes AsyncData', () async {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      // Pre-warm authStateChangesProvider.
      container.read(authStateChangesProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(saveRouteNotifierProvider.notifier)
          .save(_savedRoute());

      final state = container.read(saveRouteNotifierProvider);
      expect(state, isA<AsyncData<void>>());
      expect(repo.addCalled, isTrue);
    });

    test('save() sets AsyncError when no user is signed in', () async {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);

      await container
          .read(saveRouteNotifierProvider.notifier)
          .save(_savedRoute());

      final state = container.read(saveRouteNotifierProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<RouteException>());
    });

    test('save() sets AsyncError when repository throws', () async {
      final repo = _FakeSavedRouteRepository()
        ..addError = const RouteException('Firestore failed.');
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      container.read(authStateChangesProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(saveRouteNotifierProvider.notifier)
          .save(_savedRoute());

      final state = container.read(saveRouteNotifierProvider);
      expect(state, isA<AsyncError<void>>());
      expect(
        state.error,
        isA<RouteException>().having(
          (e) => e.message,
          'message',
          contains('Firestore failed'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // DeleteSavedRouteNotifier
  // -------------------------------------------------------------------------

  group('DeleteSavedRouteNotifier', () {
    test('initial state is AsyncData(null)', () {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      final state = container.read(deleteSavedRouteNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('delete() succeeds and state becomes AsyncData', () async {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      container.read(authStateChangesProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(deleteSavedRouteNotifierProvider.notifier)
          .delete('route-1');

      final state = container.read(deleteSavedRouteNotifierProvider);
      expect(state, isA<AsyncData<void>>());
      expect(repo.deleteCalled, isTrue);
      expect(repo.lastDeletedId, 'route-1');
    });

    test('delete() sets AsyncError when no user is signed in', () async {
      final repo = _FakeSavedRouteRepository();
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);

      await container
          .read(deleteSavedRouteNotifierProvider.notifier)
          .delete('route-1');

      final state = container.read(deleteSavedRouteNotifierProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<RouteException>());
    });

    test('delete() sets AsyncError when repository throws', () async {
      final repo = _FakeSavedRouteRepository()
        ..deleteError = const RouteException('Firestore failed.');
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      container.read(authStateChangesProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(deleteSavedRouteNotifierProvider.notifier)
          .delete('route-1');

      final state = container.read(deleteSavedRouteNotifierProvider);
      expect(state, isA<AsyncError<void>>());
      expect(
        state.error,
        isA<RouteException>().having(
          (e) => e.message,
          'message',
          contains('Firestore failed'),
        ),
      );
    });
  });
}
