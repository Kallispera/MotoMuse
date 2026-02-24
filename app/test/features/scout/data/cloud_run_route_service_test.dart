import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:motomuse/features/scout/data/cloud_run_route_service.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CloudRunRouteService _buildService(http.Client client) {
  return CloudRunRouteService(
    httpClient: client,
    baseUrl: 'https://test.example.com',
  );
}

const _prefs = RoutePreferences(
  startLocation: '51.5074,-0.1278',
  distanceKm: 150,
  curviness: 3,
  sceneryType: 'mixed',
  loop: true,
);

Map<String, dynamic> _validResponseBody() => {
      'encoded_polyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      'distance_km': 147.5,
      'duration_min': 140,
      'narrative': 'This route winds through ancient oak forest.',
      'street_view_urls': ['https://sv.example.com/1.jpg'],
      'waypoints': [
        {'lat': 51.6, 'lng': -0.2},
        {'lat': 51.7, 'lng': -0.3},
      ],
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  setUp(() {
    mockClient = _MockHttpClient();
  });

  group('CloudRunRouteService.generateRoute', () {
    test('returns GeneratedRoute on HTTP 200', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode(_validResponseBody()), 200),
      );

      final service = _buildService(mockClient);
      final result = await service.generateRoute(_prefs);

      expect(result.distanceKm, closeTo(147.5, 0.01));
      expect(result.durationMin, 140);
      expect(result.narrative, contains('oak forest'));
      expect(result.waypoints, hasLength(2));
      expect(result.streetViewUrls, hasLength(1));
    });

    test('posts to /generate-route with correct JSON body', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode(_validResponseBody()), 200),
      );

      final service = _buildService(mockClient);
      await service.generateRoute(_prefs);

      final captured = verify(
        () => mockClient.post(
          captureAny(),
          headers: captureAny(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;

      final uri = captured[0] as Uri;
      expect(uri.path, '/generate-route');

      final body =
          jsonDecode(captured[2] as String) as Map<String, dynamic>;
      expect(body['start_location'], '51.5074,-0.1278');
      expect(body['distance_km'], 150);
      expect(body['curviness'], 3);
      expect(body['loop'], isTrue);
    });

    test('throws RouteException on HTTP 500', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.generateRoute(_prefs),
        throwsA(isA<RouteException>()),
      );
    });

    test('throws RouteException on HTTP 400', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Bad request', 400));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.generateRoute(_prefs),
        throwsA(isA<RouteException>()),
      );
    });

    test('throws RouteException when response body is not a JSON object',
        () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
          (_) async => http.Response('["not", "an", "object"]', 200));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.generateRoute(_prefs),
        throwsA(isA<RouteException>()),
      );
    });

    test('throws RouteException on malformed JSON', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{not valid json', 200));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.generateRoute(_prefs),
        throwsA(isA<RouteException>()),
      );
    });

    test('throws RouteException when network throws', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('No internet'));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.generateRoute(_prefs),
        throwsA(
          isA<RouteException>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          ),
        ),
      );
    });

    test('handles empty waypoints list gracefully', () async {
      final body = _validResponseBody();
      body['waypoints'] = <dynamic>[];
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(body), 200));

      final service = _buildService(mockClient);
      final result = await service.generateRoute(_prefs);

      expect(result.waypoints, isEmpty);
    });
  });
}
