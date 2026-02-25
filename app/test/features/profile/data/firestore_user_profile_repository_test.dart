import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/profile/data/firestore_user_profile_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreUserProfileRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = FirestoreUserProfileRepository(firestore: fakeFirestore);
  });

  group('watchProfile', () {
    test('emits null when document does not exist', () async {
      final profile = await repository.watchProfile('uid123').first;
      expect(profile, isNull);
    });

    test('emits UserProfile when document exists', () async {
      await fakeFirestore.collection('users').doc('uid123').set({
        'country': 'nl',
        'homeAddress': 'Amsterdam, NL',
        'homeLocation': const GeoPoint(52.37, 4.90),
        'hasCompletedOnboarding': true,
      });

      final profile = await repository.watchProfile('uid123').first;
      expect(profile, isNotNull);
      expect(profile!.uid, 'uid123');
      expect(profile.country, 'nl');
      expect(profile.homeAddress, 'Amsterdam, NL');
      expect(profile.homeLocation, const LatLng(52.37, 4.90));
      expect(profile.hasCompletedOnboarding, isTrue);
    });

    test('defaults hasCompletedOnboarding to false', () async {
      await fakeFirestore.collection('users').doc('uid123').set({
        'country': 'nl',
      });

      final profile = await repository.watchProfile('uid123').first;
      expect(profile!.hasCompletedOnboarding, isFalse);
    });
  });

  group('updateHomeAddress', () {
    test('writes address and location to Firestore', () async {
      await repository.updateHomeAddress(
        uid: 'uid123',
        homeAddress: 'Amsterdam, NL',
        homeLocation: const LatLng(52.37, 4.90),
      );

      final doc =
          await fakeFirestore.collection('users').doc('uid123').get();
      expect(doc.data()!['homeAddress'], 'Amsterdam, NL');
      final geo = doc.data()!['homeLocation'] as GeoPoint;
      expect(geo.latitude, 52.37);
      expect(geo.longitude, 4.90);
    });
  });

  group('updateHomeAffirmingMessage', () {
    test('writes affirming message to Firestore', () async {
      await repository.updateHomeAffirmingMessage(
        uid: 'uid123',
        message: 'You live near great riding!',
      );

      final doc =
          await fakeFirestore.collection('users').doc('uid123').get();
      expect(
        doc.data()!['homeAffirmingMessage'],
        'You live near great riding!',
      );
    });
  });

  group('markOnboardingComplete', () {
    test('sets hasCompletedOnboarding to true', () async {
      await repository.markOnboardingComplete('uid123');

      final doc =
          await fakeFirestore.collection('users').doc('uid123').get();
      expect(doc.data()!['hasCompletedOnboarding'], isTrue);
    });
  });

  group('updateGaragePersonality', () {
    test('writes personality and bike count', () async {
      await repository.updateGaragePersonality(
        uid: 'uid123',
        personality: 'An eclectic collection!',
        bikeCount: 3,
      );

      final doc =
          await fakeFirestore.collection('users').doc('uid123').get();
      expect(doc.data()!['garagePersonality'], 'An eclectic collection!');
      expect(doc.data()!['garagePersonalityBikeCount'], 3);
    });
  });
}
