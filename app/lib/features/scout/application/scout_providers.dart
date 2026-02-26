import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/onboarding/application/onboarding_providers.dart';
import 'package:motomuse/features/scout/data/cloud_run_route_service.dart';
import 'package:motomuse/features/scout/data/firestore_saved_route_repository.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';
import 'package:motomuse/features/scout/domain/saved_route.dart';
import 'package:motomuse/features/scout/domain/saved_route_repository.dart';

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

// ---------------------------------------------------------------------------
// Saved routes — repository + stream + notifiers
// ---------------------------------------------------------------------------

/// Provides the [SavedRouteRepository] used to persist saved routes.
final savedRouteRepositoryProvider = Provider<SavedRouteRepository>((ref) {
  return FirestoreSavedRouteRepository(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Emits the current list of saved routes for the signed-in user, updating
/// in real time. Emits an empty list while there is no signed-in user.
final userSavedRoutesProvider = StreamProvider<List<SavedRoute>>((ref) {
  final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(savedRouteRepositoryProvider).watchSavedRoutes(uid);
});

/// Manages saving a generated route to Firestore.
///
/// State is `null` when idle.
class SaveRouteNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  /// Persists [savedRoute] to Firestore for the signed-in user.
  ///
  /// Sets state to [AsyncLoading] while in progress. On success, state
  /// becomes `AsyncData(null)`. On failure, state becomes [AsyncError].
  Future<void> save(SavedRoute savedRoute) async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) {
      state = AsyncError(
        const RouteException('Not signed in.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () => ref.read(savedRouteRepositoryProvider).addSavedRoute(
            uid,
            savedRoute,
          ),
    );
  }
}

/// Provider for [SaveRouteNotifier].
final saveRouteNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SaveRouteNotifier, void>(
  SaveRouteNotifier.new,
);

/// Manages deleting a saved route from Firestore.
///
/// State is `null` when idle.
class DeleteSavedRouteNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  /// Deletes the saved route identified by [routeId].
  Future<void> delete(String routeId) async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) {
      state = AsyncError(
        const RouteException('Not signed in.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () => ref.read(savedRouteRepositoryProvider).deleteSavedRoute(
            uid,
            routeId,
          ),
    );
  }
}

/// Provider for [DeleteSavedRouteNotifier].
final deleteSavedRouteNotifierProvider =
    AutoDisposeAsyncNotifierProvider<DeleteSavedRouteNotifier, void>(
  DeleteSavedRouteNotifier.new,
);
