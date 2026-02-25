import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of geocoding an address via the backend.
class GeocodedAddress {
  /// Creates a [GeocodedAddress].
  const GeocodedAddress({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
  });

  /// Latitude.
  final double lat;

  /// Longitude.
  final double lng;

  /// Cleaned-up address string returned by the Google Geocoding API.
  final String formattedAddress;
}

/// Calls the Cloud Run backend for geocoding and affirming message generation.
class GeocodingService {
  /// Creates a [GeocodingService].
  const GeocodingService({
    required http.Client client,
    required String baseUrl,
  })  : _client = client,
        _baseUrl = baseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Geocodes [address] via `POST /geocode-address`.
  ///
  /// Throws [Exception] on network errors or when no results are found.
  Future<GeocodedAddress> geocodeAddress(String address) async {
    final uri = Uri.parse('$_baseUrl/geocode-address');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address}),
    );

    if (response.statusCode == 404) {
      throw Exception('Address not found. Please check and try again.');
    }
    if (response.statusCode != 200) {
      throw Exception('Could not geocode address. Please try again.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GeocodedAddress(
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      formattedAddress: data['formatted_address'] as String,
    );
  }

  /// Generates an affirming message about living near [closestRegion].
  ///
  /// Returns an empty string on failure so the UI degrades gracefully.
  Future<String> homeAffirmingMessage({
    required String address,
    required String closestRegion,
  }) async {
    final uri = Uri.parse('$_baseUrl/home-affirming-message');

    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'address': address,
          'closest_region': closestRegion,
        }),
      );
    } on Exception {
      return '';
    }

    if (response.statusCode != 200) return '';

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['message'] as String? ?? '';
    } on FormatException {
      return '';
    }
  }
}
