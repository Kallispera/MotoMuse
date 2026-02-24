import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/garage/data/firestore_bike_repository.dart';
import 'package:motomuse/features/garage/domain/bike.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _uid = 'test-uid';

Bike _testBike({
  String id = '',
  String make = 'Ducati',
  String model = 'Panigale V4 S',
}) {
  return Bike(
    id: id,
    make: make,
    model: model,
    affirmingMessage: 'A masterpiece.',
    imageUrl: 'https://example.com/bike.jpg',
    addedAt: DateTime(2025),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreBikeRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreBikeRepository(firestore: firestore);
  });

  group('FirestoreBikeRepository', () {
    // -------------------------------------------------------------------------
    // watchBikes
    // -------------------------------------------------------------------------

    group('watchBikes', () {
      test('emits empty list when user has no bikes', () async {
        final stream = repo.watchBikes(_uid);
        final bikes = await stream.first;
        expect(bikes, isEmpty);
      });

      test('emits bikes after addBike is called', () async {
        await repo.addBike(_uid, _testBike());
        await repo.addBike(_uid, _testBike(make: 'Honda', model: 'CB500F'));

        final bikes = await repo.watchBikes(_uid).first;
        expect(bikes, hasLength(2));
        // Ordered descending by addedAt — both have the same fake timestamp,
        // so just verify both makes are present.
        final makes = bikes.map((b) => b.make).toSet();
        expect(makes, containsAll(['Ducati', 'Honda']));
      });

      test('each bike has a non-empty id assigned by Firestore', () async {
        await repo.addBike(_uid, _testBike());

        final bikes = await repo.watchBikes(_uid).first;
        expect(bikes.first.id, isNotEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // addBike
    // -------------------------------------------------------------------------

    group('addBike', () {
      test('creates a Firestore document under users/{uid}/bikes', () async {
        await repo.addBike(_uid, _testBike());

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('bikes')
            .get();

        expect(snap.docs, hasLength(1));
        expect(snap.docs.first.data()['make'], 'Ducati');
      });

      test('persists all required fields', () async {
        final bike = Bike(
          id: '',
          make: 'Triumph',
          model: 'Tiger 900',
          year: 2022,
          displacement: '888cc',
          color: 'Graphite',
          trim: 'Rally Pro',
          modifications: const ['Akrapovic exhaust'],
          category: 'adventure',
          affirmingMessage: 'Built for anything.',
          imageUrl: 'https://example.com/triumph.jpg',
          addedAt: DateTime(2025),
        );

        await repo.addBike(_uid, bike);

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('bikes')
            .get();

        final data = snap.docs.first.data();
        expect(data['make'], 'Triumph');
        expect(data['model'], 'Tiger 900');
        expect(data['year'], 2022);
        expect(data['displacement'], '888cc');
        expect(data['color'], 'Graphite');
        expect(data['trim'], 'Rally Pro');
        expect(data['modifications'], const ['Akrapovic exhaust']);
        expect(data['category'], 'adventure');
        expect(data['affirmingMessage'], 'Built for anything.');
        expect(data['imageUrl'], 'https://example.com/triumph.jpg');
      });

      test('null optional fields are omitted from the document', () async {
        await repo.addBike(_uid, _testBike()); // year, color etc. are null

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('bikes')
            .get();

        final data = snap.docs.first.data();
        expect(data.containsKey('year'), isFalse);
        expect(data.containsKey('color'), isFalse);
        expect(data.containsKey('trim'), isFalse);
      });

      test(
          'ignores any id passed in the Bike and uses Firestore-generated id',
          () async {
        await repo.addBike(_uid, _testBike(id: 'caller-supplied-id'));

        final bikes = await repo.watchBikes(_uid).first;
        // The Firestore-generated id will never equal 'caller-supplied-id'.
        expect(bikes.first.id, isNot('caller-supplied-id'));
        expect(bikes.first.id, isNotEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // deleteBike
    // -------------------------------------------------------------------------

    group('deleteBike', () {
      test('removes the document from Firestore', () async {
        await repo.addBike(_uid, _testBike());

        final id = (await repo.watchBikes(_uid).first).first.id;

        await repo.deleteBike(_uid, id);

        final snap = await firestore
            .collection('users')
            .doc(_uid)
            .collection('bikes')
            .get();

        expect(snap.docs, isEmpty);
      });

      test('does not throw when deleting a non-existent bike', () async {
        // Firestore delete is idempotent.
        await expectLater(
          () => repo.deleteBike(_uid, 'non-existent-id'),
          returnsNormally,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Data isolation
    // -------------------------------------------------------------------------

    test('bikes are stored per-user and do not bleed across uids', () async {
      await repo.addBike('uid-alice', _testBike());
      await repo.addBike('uid-bob', _testBike(make: 'Honda'));

      final aliceBikes = await repo.watchBikes('uid-alice').first;
      final bobBikes = await repo.watchBikes('uid-bob').first;

      expect(aliceBikes.map((b) => b.make), contains('Ducati'));
      expect(aliceBikes.map((b) => b.make), isNot(contains('Honda')));
      expect(bobBikes.map((b) => b.make), contains('Honda'));
    });
  });
}
