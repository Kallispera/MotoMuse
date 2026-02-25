import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

/// Calls the Cloud Run backend to generate a motorcycle route.
///
/// Depends on an HTTP client and base URL being injected so they can be
/// replaced with mocks in tests.
class CloudRunRouteService {
  /// Creates a [CloudRunRouteService].
  const CloudRunRouteService({
    required http.Client httpClient,
    required String baseUrl,
  })  : _httpClient = httpClient,
        _baseUrl = baseUrl;

  final http.Client _httpClient;
  final String _baseUrl;

  /// Sends [prefs] to `/generate-route` and returns a [GeneratedRoute].
  ///
  /// Throws [RouteException] on any network error, non-200 status, or
  /// unexpected response shape.
  Future<GeneratedRoute> generateRoute(RoutePreferences prefs) async {
    final uri = Uri.parse('$_baseUrl/generate-route');

    final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(_preferencesToJson(prefs)),
      );
    } on Exception catch (e) {
      throw RouteException('Network error while generating your route: $e');
    }

    if (response.statusCode != 200) {
      throw const RouteException(
        'Could not generate a route. Please try again.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const RouteException('Unexpected response from server.');
      }
      return _routeFromJson(decoded);
    } on RouteException {
      rethrow;
    } on FormatException catch (_) {
      throw const RouteException(
        'Received an unexpected response. Please try again.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _preferencesToJson(RoutePreferences prefs) {
    final json = <String, dynamic>{
      'start_location': prefs.startLocation,
      'distance_km': prefs.distanceKm,
      'curviness': prefs.curviness,
      'scenery_type': prefs.sceneryType,
      'loop': prefs.loop,
      'lunch_stop': prefs.lunchStop,
      'route_type': prefs.routeType,
    };

    if (prefs.destinationLat != null) {
      json['destination_lat'] = prefs.destinationLat;
    }
    if (prefs.destinationLng != null) {
      json['destination_lng'] = prefs.destinationLng;
    }
    if (prefs.destinationName != null) {
      json['destination_name'] = prefs.destinationName;
    }
    if (prefs.ridingAreaLat != null) {
      json['riding_area_lat'] = prefs.ridingAreaLat;
    }
    if (prefs.ridingAreaLng != null) {
      json['riding_area_lng'] = prefs.ridingAreaLng;
    }
    if (prefs.ridingAreaRadiusKm != null) {
      json['riding_area_radius_km'] = prefs.ridingAreaRadiusKm;
    }
    if (prefs.ridingAreaName != null) {
      json['riding_area_name'] = prefs.ridingAreaName;
    }

    return json;
  }

  GeneratedRoute _routeFromJson(Map<String, dynamic> json) {
    final waypointsList = _parseWaypoints(json['waypoints']);

    // Parse return leg waypoints if present.
    final returnWaypointsList = json['return_waypoints'] != null
        ? _parseWaypoints(json['return_waypoints'])
        : null;

    return GeneratedRoute(
      encodedPolyline: json['encoded_polyline'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 0,
      narrative: json['narrative'] as String? ?? '',
      streetViewUrls: (json['street_view_urls'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      waypoints: waypointsList,
      returnPolyline: json['return_polyline'] as String?,
      returnDistanceKm: (json['return_distance_km'] as num?)?.toDouble(),
      returnDurationMin: (json['return_duration_min'] as num?)?.toInt(),
      returnWaypoints: returnWaypointsList,
      returnStreetViewUrls:
          (json['return_street_view_urls'] as List<dynamic>?)?.cast<String>(),
      routeType: json['route_type'] as String? ?? 'day_out',
      destinationName: json['destination_name'] as String?,
    );
  }

  List<LatLng> _parseWaypoints(dynamic waypointsJson) {
    if (waypointsJson is! List) return [];
    return waypointsJson
        .cast<Map<String, dynamic>>()
        .map(
          (w) => LatLng(
            (w['lat'] as num).toDouble(),
            (w['lng'] as num).toDouble(),
          ),
        )
        .toList();
  }
}
