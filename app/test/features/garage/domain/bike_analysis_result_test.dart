import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/garage/domain/bike_analysis_result.dart';

void main() {
  // ---------------------------------------------------------------------------
  // fromJson
  // ---------------------------------------------------------------------------

  group('BikeAnalysisResult.fromJson', () {
    test('parses a fully populated response', () {
      final json = <String, dynamic>{
        'make': 'Ducati',
        'model': 'Panigale V4 S',
        'year': 2023,
        'displacement': '1103cc',
        'color': 'Ducati Red',
        'trim': 'S',
        'modifications': ['Akrapovic exhaust', 'carbon mirrors'],
        'category': 'sport',
        'affirming_message': 'A masterpiece of Italian engineering.',
      };

      final result = BikeAnalysisResult.fromJson(json);

      expect(result.make, 'Ducati');
      expect(result.model, 'Panigale V4 S');
      expect(result.year, 2023);
      expect(result.displacement, '1103cc');
      expect(result.color, 'Ducati Red');
      expect(result.trim, 'S');
      expect(result.modifications, ['Akrapovic exhaust', 'carbon mirrors']);
      expect(result.category, 'sport');
      expect(result.affirmingMessage, 'A masterpiece of Italian engineering.');
    });

    test('copes with all nullable fields set to null', () {
      final json = <String, dynamic>{
        'make': 'Honda',
        'model': 'CB500F',
        'year': null,
        'displacement': null,
        'color': null,
        'trim': null,
        'modifications': <dynamic>[],
        'category': null,
        'affirming_message': 'A trustworthy mount.',
      };

      final result = BikeAnalysisResult.fromJson(json);

      expect(result.year, isNull);
      expect(result.displacement, isNull);
      expect(result.color, isNull);
      expect(result.trim, isNull);
      expect(result.modifications, isEmpty);
      expect(result.category, isNull);
    });

    test('falls back to Unknown make/model when keys are missing', () {
      final result = BikeAnalysisResult.fromJson(const <String, dynamic>{
        'affirming_message': 'Interesting machine.',
      });

      expect(result.make, 'Unknown');
      expect(result.model, 'Unknown');
    });

    test('modifications defaults to empty list when key is missing', () {
      final result = BikeAnalysisResult.fromJson(const <String, dynamic>{
        'make': 'KTM',
        'model': '890 Duke',
        'affirming_message': 'Ready to play.',
      });

      expect(result.modifications, isEmpty);
    });

    test('year is parsed as int from a num response', () {
      final json = <String, dynamic>{
        'make': 'BMW',
        'model': 'R 1250 GS',
        'year': 2022.0, // numeric floating point from JSON
        'affirming_message': 'The ultimate adventure machine.',
      };

      final result = BikeAnalysisResult.fromJson(json);
      expect(result.year, 2022);
      expect(result.year, isA<int>());
    });
  });

  // ---------------------------------------------------------------------------
  // Equality & hashCode
  // ---------------------------------------------------------------------------

  group('BikeAnalysisResult equality', () {
    const a = BikeAnalysisResult(
      make: 'Triumph',
      model: 'Tiger 900',
      affirmingMessage: 'Built for adventure.',
    );
    const b = BikeAnalysisResult(
      make: 'Triumph',
      model: 'Tiger 900',
      affirmingMessage: 'Built for adventure.',
    );

    test('identical field values are equal', () {
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different make produces inequality', () {
      const c = BikeAnalysisResult(
        make: 'Honda',
        model: 'Tiger 900',
        affirmingMessage: 'Built for adventure.',
      );
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // toString
  // ---------------------------------------------------------------------------

  group('BikeAnalysisResult.toString', () {
    test('includes make, model, year', () {
      const r = BikeAnalysisResult(
        make: 'Kawasaki',
        model: 'Z900RS',
        year: 2020,
        affirmingMessage: 'Classic reborn.',
      );
      expect(r.toString(), contains('Kawasaki'));
      expect(r.toString(), contains('Z900RS'));
      expect(r.toString(), contains('2020'));
    });
  });
}
