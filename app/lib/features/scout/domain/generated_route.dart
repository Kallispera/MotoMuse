import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A motorcycle route produced by the Cloud Run route generation service.
///
/// All map-rendering types are imported from google_maps_flutter.
/// Firebase and HTTP types are kept out of this class; serialisation lives in
/// the data layer.
@immutable
class GeneratedRoute {
  /// Creates a [GeneratedRoute].
  const GeneratedRoute({
    required this.encodedPolyline,
    required this.distanceKm,
    required this.durationMin,
    required this.narrative,
    required this.streetViewUrls,
    required this.waypoints,
    this.returnPolyline,
    this.returnDistanceKm,
    this.returnDurationMin,
    this.returnWaypoints,
    this.returnStreetViewUrls,
    this.routeType = 'day_out',
    this.destinationName,
  });

  /// Google-encoded polyline string — decode to a list of LatLng for rendering.
  final String encodedPolyline;

  /// Outbound leg distance in kilometres.
  final double distanceKm;

  /// Outbound leg estimated riding duration in minutes.
  final int durationMin;

  /// LLM-generated narrative describing the route and why it was chosen.
  final String narrative;

  /// Street View image URLs for the outbound leg (typically 2–3).
  final List<String> streetViewUrls;

  /// Key waypoints along the outbound leg as [LatLng] coordinates.
  final List<LatLng> waypoints;

  // -- Return leg fields (breakfast_run / overnighter) ----------------------

  /// Google-encoded polyline for the return leg (different roads).
  final String? returnPolyline;

  /// Return leg distance in kilometres.
  final double? returnDistanceKm;

  /// Return leg estimated duration in minutes.
  final int? returnDurationMin;

  /// Waypoints along the return leg.
  final List<LatLng>? returnWaypoints;

  /// Street View images for the return leg.
  final List<String>? returnStreetViewUrls;

  /// The ride type that produced this route.
  final String routeType;

  /// Name of the destination (restaurant or hotel), if applicable.
  final String? destinationName;

  /// Whether this route has a separate return leg.
  bool get isThereAndBack => returnPolyline != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeneratedRoute &&
        other.encodedPolyline == encodedPolyline &&
        other.distanceKm == distanceKm &&
        other.durationMin == durationMin &&
        other.narrative == narrative &&
        other.routeType == routeType &&
        listEquals(other.streetViewUrls, streetViewUrls) &&
        listEquals(other.waypoints, waypoints);
  }

  @override
  int get hashCode => Object.hash(
        encodedPolyline,
        distanceKm,
        durationMin,
        narrative,
        routeType,
        Object.hashAll(streetViewUrls),
        Object.hashAll(waypoints),
      );

  @override
  String toString() => 'GeneratedRoute('
      'distanceKm: $distanceKm, '
      'durationMin: $durationMin, '
      'routeType: $routeType, '
      'waypoints: ${waypoints.length})';
}
