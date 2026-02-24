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
  });

  /// Google-encoded polyline string — decode to a list of LatLng for rendering.
  final String encodedPolyline;

  /// Total route distance in kilometres.
  final double distanceKm;

  /// Estimated riding duration in minutes.
  final int durationMin;

  /// LLM-generated narrative describing the route and why it was chosen.
  final String narrative;

  /// Street View image URLs at scenic or curvy waypoints (typically 2–3).
  final List<String> streetViewUrls;

  /// Key waypoints along the route as [LatLng] coordinates.
  final List<LatLng> waypoints;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeneratedRoute &&
        other.encodedPolyline == encodedPolyline &&
        other.distanceKm == distanceKm &&
        other.durationMin == durationMin &&
        other.narrative == narrative &&
        listEquals(other.streetViewUrls, streetViewUrls) &&
        listEquals(other.waypoints, waypoints);
  }

  @override
  int get hashCode => Object.hash(
        encodedPolyline,
        distanceKm,
        durationMin,
        narrative,
        Object.hashAll(streetViewUrls),
        Object.hashAll(waypoints),
      );

  @override
  String toString() => 'GeneratedRoute('
      'distanceKm: $distanceKm, '
      'durationMin: $durationMin, '
      'waypoints: ${waypoints.length})';
}
