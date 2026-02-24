import 'package:motomuse/features/garage/domain/bike.dart';

/// Defines the contract for persisting and retrieving bikes.
///
/// The concrete implementation lives in the data layer and is injected via
/// Riverpod.
abstract interface class BikeRepository {
  /// Emits the current list of bikes for [uid], updating in real time.
  ///
  /// Emits an empty list when the user has no bikes. Never emits `null`.
  Stream<List<Bike>> watchBikes(String uid);

  /// Persists [bike] under `users/{uid}/bikes/{generatedId}` in Firestore.
  ///
  /// The repository generates the Firestore document ID; any [Bike.id] on the
  /// passed object is ignored and replaced with the generated value.
  Future<void> addBike(String uid, Bike bike);

  /// Deletes the bike identified by [bikeId] from the user's garage.
  Future<void> deleteBike(String uid, String bikeId);
}
