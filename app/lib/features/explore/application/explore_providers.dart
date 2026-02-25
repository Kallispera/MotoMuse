import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/explore/data/firestore_explore_repository.dart';
import 'package:motomuse/features/explore/domain/explore_repository.dart';
import 'package:motomuse/features/explore/domain/hotel.dart';
import 'package:motomuse/features/explore/domain/restaurant.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

/// Provides the [ExploreRepository] for accessing curated riding content.
final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return FirestoreExploreRepository(
    firestore: ref.watch(firestoreProvider),
  );
});

// ---------------------------------------------------------------------------
// Country — hardcoded to NL for now; will be derived from user profile later.
// ---------------------------------------------------------------------------

/// The country code used to filter curated content.
///
/// Currently hardcoded to the Netherlands. In a future phase this will be
/// derived from the user's profile settings.
final exploreCountryProvider = Provider<String>((_) => 'nl');

// ---------------------------------------------------------------------------
// Stream providers — real-time Firestore data
// ---------------------------------------------------------------------------

/// Watches all riding locations for the user's country.
final ridingLocationsProvider = StreamProvider<List<RidingLocation>>((ref) {
  final repo = ref.watch(exploreRepositoryProvider);
  final country = ref.watch(exploreCountryProvider);
  return repo.watchLocations(country);
});

/// Watches all restaurants for the user's country.
final restaurantsProvider = StreamProvider<List<Restaurant>>((ref) {
  final repo = ref.watch(exploreRepositoryProvider);
  final country = ref.watch(exploreCountryProvider);
  return repo.watchRestaurants(country);
});

/// Watches all hotels for the user's country.
final hotelsProvider = StreamProvider<List<Hotel>>((ref) {
  final repo = ref.watch(exploreRepositoryProvider);
  final country = ref.watch(exploreCountryProvider);
  return repo.watchHotels(country);
});

/// Watches restaurants within a specific riding location.
final restaurantsForLocationProvider =
    StreamProvider.family<List<Restaurant>, String>((ref, locationId) {
  final repo = ref.watch(exploreRepositoryProvider);
  return repo.watchRestaurantsForLocation(locationId);
});

/// Watches hotels within a specific riding location.
final hotelsForLocationProvider =
    StreamProvider.family<List<Hotel>, String>((ref, locationId) {
  final repo = ref.watch(exploreRepositoryProvider);
  return repo.watchHotelsForLocation(locationId);
});
