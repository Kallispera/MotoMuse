import 'package:flutter/foundation.dart';

/// The user's ride preferences used to generate a motorcycle route.
@immutable
class RoutePreferences {
  /// Creates a [RoutePreferences] with the given fields.
  const RoutePreferences({
    required this.startLocation,
    required this.distanceKm,
    required this.curviness,
    required this.sceneryType,
    required this.loop,
    this.lunchStop = false,
  });

  /// Starting address or `"lat,lng"` string. Empty means use device location.
  final String startLocation;

  /// Target ride distance in kilometres (30–300).
  final int distanceKm;

  /// Desired curviness on a 1–5 scale.
  final int curviness;

  /// Preferred scenery type: `forests`, `coastline`, `mountains`, or `mixed`.
  final String sceneryType;

  /// `true` for a circular loop back to the start; `false` for point-to-point.
  final bool loop;

  /// Whether to include a restaurant stop at roughly the halfway point.
  final bool lunchStop;

  /// Returns a copy of this [RoutePreferences] with the specified fields
  /// replaced.
  RoutePreferences copyWith({
    String? startLocation,
    int? distanceKm,
    int? curviness,
    String? sceneryType,
    bool? loop,
    bool? lunchStop,
  }) {
    return RoutePreferences(
      startLocation: startLocation ?? this.startLocation,
      distanceKm: distanceKm ?? this.distanceKm,
      curviness: curviness ?? this.curviness,
      sceneryType: sceneryType ?? this.sceneryType,
      loop: loop ?? this.loop,
      lunchStop: lunchStop ?? this.lunchStop,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutePreferences &&
        other.startLocation == startLocation &&
        other.distanceKm == distanceKm &&
        other.curviness == curviness &&
        other.sceneryType == sceneryType &&
        other.loop == loop &&
        other.lunchStop == lunchStop;
  }

  @override
  int get hashCode => Object.hash(
        startLocation,
        distanceKm,
        curviness,
        sceneryType,
        loop,
        lunchStop,
      );

  @override
  String toString() => 'RoutePreferences('
      'startLocation: $startLocation, '
      'distanceKm: $distanceKm, '
      'curviness: $curviness, '
      'sceneryType: $sceneryType, '
      'loop: $loop, '
      'lunchStop: $lunchStop)';
}
