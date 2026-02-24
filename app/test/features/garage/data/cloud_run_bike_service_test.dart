import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:motomuse/features/garage/data/cloud_run_bike_service.dart';
import 'package:motomuse/features/garage/domain/bike_exception.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CloudRunBikeService _buildService(http.Client client) {
  return CloudRunBikeService(
    httpClient: client,
    baseUrl: 'https://test.example.com',
  );
}

Map<String, dynamic> _validResponseBody() => {
      'make': 'Ducati',
      'model': 'Panigale V4 S',
      'year': 2023,
      'displacement': '1103cc',
      'color': 'Ducati Red',
      'trim': 'S',
      'modifications': ['Akrapovic exhaust'],
      'category': 'sport',
      'affirming_message': 'A masterpiece of Italian engineering.',
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

  group('CloudRunBikeService.analyzeBike', () {
    test('returns BikeAnalysisResult on HTTP 200', () async {
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
      final result = await service.analyzeBike('https://example.com/bike.jpg');

      expect(result.make, 'Ducati');
      expect(result.model, 'Panigale V4 S');
      expect(result.year, 2023);
      expect(result.affirmingMessage, 'A masterpiece of Italian engineering.');
    });

    test('posts to /analyze-bike with JSON body', () async {
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
      await service.analyzeBike('https://example.com/bike.jpg');

      final captured = verify(
        () => mockClient.post(
          captureAny(),
          headers: captureAny(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;

      final uri = captured[0] as Uri;
      expect(uri.path, '/analyze-bike');

      final body = jsonDecode(captured[2] as String) as Map<String, dynamic>;
      expect(body['image_url'], 'https://example.com/bike.jpg');
    });

    test('throws BikeException on HTTP 500', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.analyzeBike('https://example.com/bike.jpg'),
        throwsA(isA<BikeException>()),
      );
    });

    test('throws BikeException on HTTP 422', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Unprocessable', 422));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.analyzeBike('https://example.com/bike.jpg'),
        throwsA(isA<BikeException>()),
      );
    });

    test('throws BikeException when response body is not a JSON object',
        () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('["not", "an", "object"]', 200));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.analyzeBike('https://example.com/bike.jpg'),
        throwsA(isA<BikeException>()),
      );
    });

    test('throws BikeException on malformed JSON', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{not valid json', 200));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.analyzeBike('https://example.com/bike.jpg'),
        throwsA(isA<BikeException>()),
      );
    });

    test('throws BikeException when network throws', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('No internet connection'));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.analyzeBike('https://example.com/bike.jpg'),
        throwsA(
          isA<BikeException>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          ),
        ),
      );
    });
  });
}
