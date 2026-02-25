import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/explore/domain/explore_repository.dart';
import 'package:motomuse/features/explore/domain/hotel.dart';
import 'package:motomuse/features/explore/domain/restaurant.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';

/// Firestore implementation of [ExploreRepository].
///
/// Curated riding content is stored in top-level collections:
/// `riding_locations`, `restaurants`, `hotels` — filtered by country.
class FirestoreExploreRepository implements ExploreRepository {
  /// Creates a [FirestoreExploreRepository].
  const FirestoreExploreRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<RidingLocation>> watchLocations(String country) {
    return _firestore
        .collection('riding_locations')
        .where('country', isEqualTo: country)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_locationFromDoc).toList(),
        );
  }

  @override
  Stream<List<Restaurant>> watchRestaurants(String country) {
    return _firestore
        .collection('restaurants')
        .where('country', isEqualTo: country)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_restaurantFromDoc).toList(),
        );
  }

  @override
  Stream<List<Hotel>> watchHotels(String country) {
    return _firestore
        .collection('hotels')
        .where('country', isEqualTo: country)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_hotelFromDoc).toList(),
        );
  }

  @override
  Stream<List<Restaurant>> watchRestaurantsForLocation(String locationId) {
    return _firestore
        .collection('restaurants')
        .where('riding_location_id', isEqualTo: locationId)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_restaurantFromDoc).toList(),
        );
  }

  @override
  Stream<List<Hotel>> watchHotelsForLocation(String locationId) {
    return _firestore
        .collection('hotels')
        .where('riding_location_id', isEqualTo: locationId)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_hotelFromDoc).toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  RidingLocation _locationFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final center = data['center'] as GeoPoint?;
    final ne = data['bounds_ne'] as GeoPoint?;
    final sw = data['bounds_sw'] as GeoPoint?;

    return RidingLocation(
      id: doc.id,
      country: data['country'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      center: LatLng(
        center?.latitude ?? 0,
        center?.longitude ?? 0,
      ),
      boundsNe: LatLng(
        ne?.latitude ?? 0,
        ne?.longitude ?? 0,
      ),
      boundsSw: LatLng(
        sw?.latitude ?? 0,
        sw?.longitude ?? 0,
      ),
      photoUrls: _stringList(data['photo_urls']),
      tags: _stringList(data['tags']),
      sceneryType: data['scenery_type'] as String? ?? 'mixed',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Restaurant _restaurantFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final location = data['location'] as GeoPoint?;

    return Restaurant(
      id: doc.id,
      country: data['country'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: LatLng(
        location?.latitude ?? 0,
        location?.longitude ?? 0,
      ),
      ridingLocationId: data['riding_location_id'] as String? ?? '',
      ridingLocationName: data['riding_location_name'] as String? ?? '',
      photoUrls: _stringList(data['photo_urls']),
      cuisineType: data['cuisine_type'] as String? ?? '',
      priceRange: data['price_range'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Hotel _hotelFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final location = data['location'] as GeoPoint?;

    return Hotel(
      id: doc.id,
      country: data['country'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: LatLng(
        location?.latitude ?? 0,
        location?.longitude ?? 0,
      ),
      ridingLocationId: data['riding_location_id'] as String? ?? '',
      ridingLocationName: data['riding_location_name'] as String? ?? '',
      photoUrls: _stringList(data['photo_urls']),
      priceRange: data['price_range'] as String? ?? '',
      bikerAmenities: _stringList(data['biker_amenities']),
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.cast<String>();
    }
    return const [];
  }
}
