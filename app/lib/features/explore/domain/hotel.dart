import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A biker-friendly hotel for overnight motorcycle trips.
@immutable
class Hotel {
  /// Creates a [Hotel].
  const Hotel({
    required this.id,
    required this.country,
    required this.name,
    required this.description,
    required this.location,
    required this.ridingLocationId,
    required this.ridingLocationName,
    required this.photoUrls,
    required this.priceRange,
    required this.bikerAmenities,
    required this.order,
  });

  /// Firestore document ID.
  final String id;

  /// Country code (e.g. "nl").
  final String country;

  /// Hotel name.
  final String name;

  /// Why this is great for an overnight bike trip.
  final String description;

  /// Geographic coordinates.
  final LatLng location;

  /// ID of the parent riding location.
  final String ridingLocationId;

  /// Name of the parent riding location (denormalized for display).
  final String ridingLocationName;

  /// Photo URLs.
  final List<String> photoUrls;

  /// Price range indicator.
  final String priceRange;

  /// Biker-friendly amenities (e.g. "secure parking", "drying room").
  final List<String> bikerAmenities;

  /// Display ordering.
  final int order;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hotel && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Hotel(id: $id, name: $name)';
}
