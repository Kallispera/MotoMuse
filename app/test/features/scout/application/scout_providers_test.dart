import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:motomuse/features/scout/application/scout_providers.dart';
import 'package:motomuse/features/scout/data/cloud_run_route_service.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockCloudRunRouteService extends Mock implements CloudRunRouteService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _prefs = RoutePreferences(
  startLocation: '51.5,0.0',
  distanceKm: 100,
  curviness: 3,
  sceneryType: 'forests',
  loop: true,
);

const _route = GeneratedRoute(
  encodedPolyline: 'abc',
  distanceKm: 100,
  durationMin: 90,
  narrative: 'A great route.',
  streetViewUrls: [],
  waypoints: [],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockCloudRunRouteService mockService;

  setUpAll(() {
    registerFallbackValue(_prefs);
  });

  setUp(() {
    mockService = _MockCloudRunRouteService();
  });

  group('routePreferencesProvider', () {
    test('starts with default values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = container.read(routePreferencesProvider);
      expect(prefs.distanceKm, 150);
      expect(prefs.curviness, 3);
      expect(prefs.loop, isTrue);
      expect(prefs.sceneryType, 'mixed');
    });

    test('can be updated via notifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(routePreferencesProvider.notifier).update(
            (p) => p.copyWith(distanceKm: 200, curviness: 5),
          );

      final updated = container.read(routePreferencesProvider);
      expect(updated.distanceKm, 200);
      expect(updated.curviness, 5);
    });
  });

  group('RouteGenerationNotifier', () {
    test('initial state is AsyncData(null)', () {
      when(() => mockService.generateRoute(any()))
          .thenAnswer((_) async => _route);

      final container = ProviderContainer(
        overrides: [
          cloudRunRouteServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(routeGenerationNotifierProvider);
      expect(state, isA<AsyncData<GeneratedRoute?>>());
      expect(state.valueOrNull, isNull);
    });

    test('generate sets state to AsyncData with route on success', () async {
      when(() => mockService.generateRoute(any()))
          .thenAnswer((_) async => _route);

      final container = ProviderContainer(
        overrides: [
          cloudRunRouteServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(routeGenerationNotifierProvider.notifier)
          .generate(_prefs);

      final state = container.read(routeGenerationNotifierProvider);
      expect(state, isA<AsyncData<GeneratedRoute?>>());
      expect(state.valueOrNull, equals(_route));
    });

    test('generate sets state to AsyncError on RouteException', () async {
      when(() => mockService.generateRoute(any()))
          .thenThrow(const RouteException('Generation failed.'));

      final container = ProviderContainer(
        overrides: [
          cloudRunRouteServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(routeGenerationNotifierProvider.notifier)
          .generate(_prefs);

      final state = container.read(routeGenerationNotifierProvider);
      expect(state, isA<AsyncError<GeneratedRoute?>>());
    });

    test('reset returns state to AsyncData(null)', () async {
      when(() => mockService.generateRoute(any()))
          .thenAnswer((_) async => _route);

      final container = ProviderContainer(
        overrides: [
          cloudRunRouteServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(routeGenerationNotifierProvider.notifier)
          .generate(_prefs);

      container.read(routeGenerationNotifierProvider.notifier).reset();

      final state = container.read(routeGenerationNotifierProvider);
      expect(state.valueOrNull, isNull);
    });
  });
}
