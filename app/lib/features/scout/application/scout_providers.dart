import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/onboarding/application/onboarding_providers.dart';
import 'package:motomuse/features/scout/data/cloud_run_route_service.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides the [CloudRunRouteService] used to generate motorcycle routes.
///
/// Reuses the shared [httpClientProvider] and [cloudRunBaseUrlProvider] from
/// the garage feature so there is a single source of truth for infrastructure.
final cloudRunRouteServiceProvider = Provider<CloudRunRouteService>((ref) {
  return CloudRunRouteService(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: ref.watch(cloudRunBaseUrlProvider),
  );
});

// ---------------------------------------------------------------------------
// Preferences — persisted across the session
// ---------------------------------------------------------------------------

/// Holds the user's current ride preferences on the Scout screen.
///
/// Initialises from the user's saved riding preferences in their profile.
/// Falls back to sensible defaults (curviness 3, mixed scenery, 150 km)
/// when no profile preferences have been saved yet.
final routePreferencesProvider =
    StateProvider<RoutePreferences>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return RoutePreferences(
    startLocation: '', // empty = resolve device location at generate time
    distanceKm: profile?.defaultDistanceKm ?? 150,
    curviness: profile?.defaultCurviness ?? 3,
    sceneryType: profile?.defaultSceneryType ?? 'mixed',
    loop: true,
  );
});

// ---------------------------------------------------------------------------
// RouteGenerationNotifier
// ---------------------------------------------------------------------------

/// Manages the asynchronous flow of generating a motorcycle route.
///
/// State is `null` when idle, [GeneratedRoute] on success.
class RouteGenerationNotifier
    extends AutoDisposeAsyncNotifier<GeneratedRoute?> {
  @override
  FutureOr<GeneratedRoute?> build() => null;

  /// Sends [prefs] to the Cloud Run backend and stores the result.
  ///
  /// Sets state to [AsyncLoading] while in progress. On success, state
  /// becomes [AsyncData] wrapping the [GeneratedRoute]. On failure, state
  /// becomes [AsyncError].
  Future<void> generate(RoutePreferences prefs) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<GeneratedRoute?>(
      () => ref.read(cloudRunRouteServiceProvider).generateRoute(prefs),
    );
  }

  /// Resets state to idle so a fresh generation can be started.
  void reset() => state = const AsyncData(null);
}

/// Provider for [RouteGenerationNotifier].
final routeGenerationNotifierProvider = AutoDisposeAsyncNotifierProvider<
    RouteGenerationNotifier, GeneratedRoute?>(
  RouteGenerationNotifier.new,
);
