import 'package:motomuse/features/scout/domain/saved_route.dart';

/// Defines the contract for persisting and retrieving saved routes.
///
/// The concrete implementation lives in the data layer and is injected via
/// Riverpod.
abstract interface class SavedRouteRepository {
  /// Emits the current list of saved routes for [uid], updating in real time.
  ///
  /// Ordered by [SavedRoute.savedAt] descending (most recent first).
  /// Emits an empty list when the user has no saved routes. Never emits `null`.
  Stream<List<SavedRoute>> watchSavedRoutes(String uid);

  /// Persists [savedRoute] under `users/{uid}/savedRoutes/{generatedId}`.
  ///
  /// The repository generates the Firestore document ID; any [SavedRoute.id]
  /// on the passed object is ignored and replaced with the generated value.
  Future<void> addSavedRoute(String uid, SavedRoute savedRoute);

  /// Deletes the saved route identified by [routeId].
  Future<void> deleteSavedRoute(String uid, String routeId);
}
