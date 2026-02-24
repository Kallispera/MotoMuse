import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/garage/domain/bike.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Fixtures
  // ---------------------------------------------------------------------------

  final addedAt = DateTime(2025, 6);

  // DateTime.utc is not a const constructor, so fullBike must be final.
  final fullBike = Bike(
    id: 'bike-1',
    make: 'Ducati',
    model: 'Panigale V4 S',
    year: 2023,
    displacement: '1103cc',
    color: 'Ducati Red',
    trim: 'S',
    modifications: const ['Akrapovic exhaust', 'carbon mirrors'],
    category: 'sport',
    affirmingMessage: 'A masterpiece of Italian engineering.',
    imageUrl: 'https://example.com/bike.jpg',
    addedAt: DateTime.utc(2025, 6),
  );

  Bike minimal() => Bike(
        id: 'bike-min',
        make: 'Honda',
        model: 'CB500F',
        affirmingMessage: 'A reliable companion.',
        imageUrl: 'https://example.com/cb.jpg',
        addedAt: addedAt,
      );

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  group('Bike construction', () {
    test('required fields are set correctly', () {
      final bike = minimal();
      expect(bike.id, 'bike-min');
      expect(bike.make, 'Honda');
      expect(bike.model, 'CB500F');
      expect(bike.affirmingMessage, 'A reliable companion.');
      expect(bike.imageUrl, 'https://example.com/cb.jpg');
    });

    test('optional fields default to null / empty', () {
      final bike = minimal();
      expect(bike.year, isNull);
      expect(bike.displacement, isNull);
      expect(bike.color, isNull);
      expect(bike.trim, isNull);
      expect(bike.modifications, isEmpty);
      expect(bike.category, isNull);
    });

    test('all optional fields can be provided', () {
      expect(fullBike.year, 2023);
      expect(fullBike.displacement, '1103cc');
      expect(fullBike.color, 'Ducati Red');
      expect(fullBike.trim, 'S');
      expect(fullBike.modifications, hasLength(2));
      expect(fullBike.category, 'sport');
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  group('Bike.copyWith', () {
    test('returns identical bike when no fields are provided', () {
      final copy = fullBike.copyWith();
      expect(copy, equals(fullBike));
    });

    test('replaces only specified fields', () {
      final copy = fullBike.copyWith(make: 'BMW', year: 2024);
      expect(copy.make, 'BMW');
      expect(copy.year, 2024);
      // Unchanged fields remain.
      expect(copy.model, fullBike.model);
      expect(copy.color, fullBike.color);
      expect(copy.modifications, fullBike.modifications);
    });

    test('can replace id', () {
      final copy = fullBike.copyWith(id: 'new-id');
      expect(copy.id, 'new-id');
      expect(copy.make, fullBike.make);
    });

    test('can replace modifications list', () {
      final copy = fullBike.copyWith(
        modifications: const ['Ohlins suspension'],
      );
      expect(copy.modifications, const ['Ohlins suspension']);
    });
  });

  // ---------------------------------------------------------------------------
  // Equality & hashCode
  // ---------------------------------------------------------------------------

  group('Bike equality', () {
    test('two bikes with identical fields are equal', () {
      final a = Bike(
        id: 'x',
        make: 'Yamaha',
        model: 'MT-09',
        affirmingMessage: 'Torque on demand.',
        imageUrl: 'https://example.com/mt09.jpg',
        addedAt: addedAt,
      );
      final b = Bike(
        id: 'x',
        make: 'Yamaha',
        model: 'MT-09',
        affirmingMessage: 'Torque on demand.',
        imageUrl: 'https://example.com/mt09.jpg',
        addedAt: addedAt,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('bikes with different ids are not equal', () {
      final a = fullBike;
      final b = fullBike.copyWith(id: 'bike-2');
      expect(a, isNot(equals(b)));
    });

    test('bikes with different modifications are not equal', () {
      final a = fullBike;
      final b = fullBike.copyWith(modifications: const ['different mod']);
      expect(a, isNot(equals(b)));
    });

    test('identical() short-circuits equality check', () {
      expect(fullBike == fullBike, isTrue);
    });

    test('not equal to a non-Bike object', () {
      // Verifies Bike.== returns false when the RHS is a different type.
      // ignore: unrelated_type_equality_checks
      expect(fullBike == 'not a bike', isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // toString
  // ---------------------------------------------------------------------------

  group('Bike.toString', () {
    test('contains key identifiers', () {
      final s = fullBike.toString();
      expect(s, contains('Ducati'));
      expect(s, contains('Panigale V4 S'));
      expect(s, contains('2023'));
    });
  });
}
