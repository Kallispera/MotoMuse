import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:motomuse/features/onboarding/data/geocoding_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

GeocodingService _buildService(http.Client client) {
  return GeocodingService(
    client: client,
    baseUrl: 'https://test.example.com',
  );
}

void main() {
  late _MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  setUp(() {
    mockClient = _MockHttpClient();
  });

  group('geocodeAddress', () {
    test('returns GeocodedAddress on HTTP 200', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'lat': 52.37,
            'lng': 4.90,
            'formatted_address': 'Amsterdam, Netherlands',
          }),
          200,
        ),
      );

      final service = _buildService(mockClient);
      final result = await service.geocodeAddress('Amsterdam');

      expect(result.lat, 52.37);
      expect(result.lng, 4.90);
      expect(result.formattedAddress, 'Amsterdam, Netherlands');
    });

    test('throws on HTTP 404', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Not found', 404));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.geocodeAddress('nonexistent address xyz'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on HTTP 500', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Server error', 500));

      final service = _buildService(mockClient);

      await expectLater(
        () => service.geocodeAddress('Amsterdam'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('homeAffirmingMessage', () {
    test('returns message on HTTP 200', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'message':
                'You live near one of the best riding areas in the Netherlands!',
          }),
          200,
        ),
      );

      final service = _buildService(mockClient);
      final result = await service.homeAffirmingMessage(
        address: 'Amsterdam',
        closestRegion: 'Veluwe',
      );

      expect(result, contains('best riding areas'));
    });

    test('returns empty string on HTTP error', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Error', 500));

      final service = _buildService(mockClient);
      final result = await service.homeAffirmingMessage(
        address: 'Amsterdam',
        closestRegion: 'Veluwe',
      );

      expect(result, isEmpty);
    });

    test('returns empty string on network exception', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(Exception('No internet'));

      final service = _buildService(mockClient);
      final result = await service.homeAffirmingMessage(
        address: 'Amsterdam',
        closestRegion: 'Veluwe',
      );

      expect(result, isEmpty);
    });
  });
}
