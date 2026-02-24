import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:motomuse/features/garage/domain/bike_analysis_result.dart';
import 'package:motomuse/features/garage/domain/bike_exception.dart';

/// Calls the Cloud Run backend to analyse a motorcycle photograph.
///
/// Depends on [http.Client] being injected so it can be replaced with a
/// mock in tests.
///
/// The `baseUrl` should point to the Cloud Run service root, e.g.
/// `https://motomuse-backend-xyz-ew.a.run.app`. It is injected via a
/// provider so it can be overridden in tests.
class CloudRunBikeService {
  /// Creates a [CloudRunBikeService].
  const CloudRunBikeService({
    required http.Client httpClient,
    required String baseUrl,
  })  : _httpClient = httpClient,
        _baseUrl = baseUrl;

  final http.Client _httpClient;
  final String _baseUrl;

  /// Sends [imageUrl] to `/analyze-bike` and returns a [BikeAnalysisResult].
  ///
  /// Throws [BikeException] on any network error, non-200 status, or
  /// unexpected response shape.
  Future<BikeAnalysisResult> analyzeBike(String imageUrl) async {
    final uri = Uri.parse('$_baseUrl/analyze-bike');

    final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      );
    } on Exception catch (e) {
      throw BikeException('Network error while analysing your photo: $e');
    }

    if (response.statusCode != 200) {
      throw const BikeException(
        'Could not analyse your bike photo. Please try again.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const BikeException('Unexpected response from server.');
      }
      return BikeAnalysisResult.fromJson(decoded);
    } on BikeException {
      rethrow;
    } on FormatException catch (_) {
      throw const BikeException(
        'Received an unexpected response. Please try again.',
      );
    }
  }
}
