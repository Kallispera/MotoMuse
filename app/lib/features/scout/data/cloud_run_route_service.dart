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
    return <String, dynamic>{
      'start_location': prefs.startLocation,
      'distance_km': prefs.distanceKm,
      'curviness': prefs.curviness,
      'scenery_type': prefs.sceneryType,
      'loop': prefs.loop,
      'lunch_stop': prefs.lunchStop,
    };
  }

  GeneratedRoute _routeFromJson(Map<String, dynamic> json) {
    final waypointsList = (json['waypoints'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(
          (w) => LatLng(
            (w['lat'] as num).toDouble(),
            (w['lng'] as num).toDouble(),
          ),
        )
        .toList();

    return GeneratedRoute(
      encodedPolyline: json['encoded_polyline'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 0,
      narrative: json['narrative'] as String? ?? '',
      streetViewUrls: (json['street_view_urls'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      waypoints: waypointsList,
    );
  }
}
