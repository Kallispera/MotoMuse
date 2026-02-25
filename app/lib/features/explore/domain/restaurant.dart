import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A biker-friendly restaurant in a riding area.
@immutable
class Restaurant {
  /// Creates a [Restaurant].
  const Restaurant({
    required this.id,
    required this.country,
    required this.name,
    required this.description,
    required this.location,
    required this.ridingLocationId,
    required this.ridingLocationName,
    required this.photoUrls,
    required this.cuisineType,
    required this.priceRange,
    required this.order,
  });

  /// Firestore document ID.
  final String id;

  /// Country code (e.g. "nl").
  final String country;

  /// Restaurant name.
  final String name;

  /// Why bikers love this place.
  final String description;

  /// Geographic coordinates.
  final LatLng location;

  /// ID of the parent riding location.
  final String ridingLocationId;

  /// Name of the parent riding location (denormalized for display).
  final String ridingLocationName;

  /// Photo URLs.
  final List<String> photoUrls;

  /// Cuisine type (e.g. "Dutch", "International").
  final String cuisineType;

  /// Price range indicator.
  final String priceRange;

  /// Display ordering.
  final int order;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Restaurant && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Restaurant(id: $id, name: $name)';
}
