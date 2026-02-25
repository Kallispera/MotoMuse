import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A curated motorcycle riding area within a country.
///
/// Immutable domain-layer value object. Firestore serialisation lives in the
/// data layer.
@immutable
class RidingLocation {
  /// Creates a [RidingLocation].
  const RidingLocation({
    required this.id,
    required this.country,
    required this.name,
    required this.description,
    required this.center,
    required this.boundsNe,
    required this.boundsSw,
    required this.photoUrls,
    required this.tags,
    required this.sceneryType,
    required this.order,
    this.polygonPoints = const [],
  });

  /// Firestore document ID.
  final String id;

  /// Country code (e.g. "nl").
  final String country;

  /// Human-readable area name (e.g. "South Limburg").
  final String name;

  /// Why this area is great for motorcyclists.
  final String description;

  /// Geographic centre of the riding area.
  final LatLng center;

  /// Northeast corner of the bounding box.
  final LatLng boundsNe;

  /// Southwest corner of the bounding box.
  final LatLng boundsSw;

  /// Google Street View image URLs of scenic roads in the area.
  final List<String> photoUrls;

  /// Descriptive tags (e.g. "twisty", "hills", "scenic").
  final List<String> tags;

  /// Primary scenery type: forests, coastline, mountains, or mixed.
  final String sceneryType;

  /// Display ordering.
  final int order;

  /// Polygon boundary coordinates defining the riding area shape.
  /// Falls back to the bounding box rectangle when empty.
  final List<LatLng> polygonPoints;

  /// Approximate radius in km (half the diagonal of the bounding box).
  double get radiusKm {
    const earthR = 6371.0;
    final dLat = (boundsNe.latitude - boundsSw.latitude) * 3.14159 / 180;
    final dLng = (boundsNe.longitude - boundsSw.longitude) * 3.14159 / 180;
    final dist =
        earthR * (dLat * dLat + dLng * dLng).abs();
    // Simplified — half the bounding box diagonal.
    return (dist > 0 ? dist : 30) / 2;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RidingLocation &&
        other.id == id &&
        other.name == name &&
        other.country == country;
  }

  @override
  int get hashCode => Object.hash(id, name, country);

  @override
  String toString() => 'RidingLocation(id: $id, name: $name)';
}
