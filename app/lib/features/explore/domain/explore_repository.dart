import 'package:motomuse/features/explore/domain/hotel.dart';
import 'package:motomuse/features/explore/domain/restaurant.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';

/// Interface for accessing curated riding content.
///
/// Implementations fetch data from Firestore or another persistence layer.
abstract class ExploreRepository {
  /// Watches all riding locations for the given [country].
  Stream<List<RidingLocation>> watchLocations(String country);

  /// Watches all restaurants for the given [country].
  Stream<List<Restaurant>> watchRestaurants(String country);

  /// Watches all hotels for the given [country].
  Stream<List<Hotel>> watchHotels(String country);

  /// Watches restaurants within a specific riding location.
  Stream<List<Restaurant>> watchRestaurantsForLocation(String locationId);

  /// Watches hotels within a specific riding location.
  Stream<List<Hotel>> watchHotelsForLocation(String locationId);
}
