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
    this.routeType = 'day_out',
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
    this.ridingAreaLat,
    this.ridingAreaLng,
    this.ridingAreaRadiusKm,
    this.ridingAreaName,
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

  /// Ride type: `breakfast_run`, `day_out`, or `overnighter`.
  final String routeType;

  /// Destination latitude (restaurant or hotel).
  final double? destinationLat;

  /// Destination longitude (restaurant or hotel).
  final double? destinationLng;

  /// Destination name (restaurant or hotel).
  final String? destinationName;

  /// Centre latitude of the selected riding area (day_out only).
  final double? ridingAreaLat;

  /// Centre longitude of the selected riding area (day_out only).
  final double? ridingAreaLng;

  /// Approximate radius of the riding area in km.
  final double? ridingAreaRadiusKm;

  /// Name of the selected riding area.
  final String? ridingAreaName;

  /// Whether this is a there-and-back route type.
  bool get isThereAndBack =>
      routeType == 'breakfast_run' || routeType == 'overnighter';

  /// Returns a copy of this [RoutePreferences] with the specified fields
  /// replaced.
  RoutePreferences copyWith({
    String? startLocation,
    int? distanceKm,
    int? curviness,
    String? sceneryType,
    bool? loop,
    bool? lunchStop,
    String? routeType,
    double? Function()? destinationLat,
    double? Function()? destinationLng,
    String? Function()? destinationName,
    double? Function()? ridingAreaLat,
    double? Function()? ridingAreaLng,
    double? Function()? ridingAreaRadiusKm,
    String? Function()? ridingAreaName,
  }) {
    return RoutePreferences(
      startLocation: startLocation ?? this.startLocation,
      distanceKm: distanceKm ?? this.distanceKm,
      curviness: curviness ?? this.curviness,
      sceneryType: sceneryType ?? this.sceneryType,
      loop: loop ?? this.loop,
      lunchStop: lunchStop ?? this.lunchStop,
      routeType: routeType ?? this.routeType,
      destinationLat:
          destinationLat != null ? destinationLat() : this.destinationLat,
      destinationLng:
          destinationLng != null ? destinationLng() : this.destinationLng,
      destinationName:
          destinationName != null ? destinationName() : this.destinationName,
      ridingAreaLat:
          ridingAreaLat != null ? ridingAreaLat() : this.ridingAreaLat,
      ridingAreaLng:
          ridingAreaLng != null ? ridingAreaLng() : this.ridingAreaLng,
      ridingAreaRadiusKm: ridingAreaRadiusKm != null
          ? ridingAreaRadiusKm()
          : this.ridingAreaRadiusKm,
      ridingAreaName:
          ridingAreaName != null ? ridingAreaName() : this.ridingAreaName,
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
        other.lunchStop == lunchStop &&
        other.routeType == routeType &&
        other.destinationLat == destinationLat &&
        other.destinationLng == destinationLng &&
        other.destinationName == destinationName &&
        other.ridingAreaLat == ridingAreaLat &&
        other.ridingAreaLng == ridingAreaLng &&
        other.ridingAreaName == ridingAreaName;
  }

  @override
  int get hashCode => Object.hash(
        startLocation,
        distanceKm,
        curviness,
        sceneryType,
        loop,
        lunchStop,
        routeType,
        destinationLat,
        destinationLng,
        destinationName,
        ridingAreaLat,
        ridingAreaLng,
        ridingAreaName,
      );

  @override
  String toString() => 'RoutePreferences('
      'startLocation: $startLocation, '
      'distanceKm: $distanceKm, '
      'routeType: $routeType)';
}
