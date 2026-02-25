import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/profile/domain/user_profile.dart';

/// Reads and writes user profile data in Firestore (`users/{uid}`).
class FirestoreUserProfileRepository {
  /// Creates a [FirestoreUserProfileRepository].
  const FirestoreUserProfileRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Watches the user profile in real-time.
  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return _fromDocument(uid, snap.data()!);
    });
  }

  /// Saves the home address and geocoded location.
  Future<void> updateHomeAddress({
    required String uid,
    required String homeAddress,
    required LatLng homeLocation,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      {
        'homeAddress': homeAddress,
        'homeLocation': GeoPoint(
          homeLocation.latitude,
          homeLocation.longitude,
        ),
      },
      SetOptions(merge: true),
    );
  }

  /// Saves the affirming message about the rider's closest riding region.
  Future<void> updateHomeAffirmingMessage({
    required String uid,
    required String message,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      {'homeAffirmingMessage': message},
      SetOptions(merge: true),
    );
  }

  /// Marks the onboarding flow as complete.
  Future<void> markOnboardingComplete(String uid) async {
    await _firestore.collection('users').doc(uid).set(
      {'hasCompletedOnboarding': true},
      SetOptions(merge: true),
    );
  }

  /// Saves the cached garage personality message.
  Future<void> updateGaragePersonality({
    required String uid,
    required String personality,
    required int bikeCount,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      {
        'garagePersonality': personality,
        'garagePersonalityBikeCount': bikeCount,
      },
      SetOptions(merge: true),
    );
  }

  UserProfile _fromDocument(String uid, Map<String, dynamic> data) {
    final homeLoc = data['homeLocation'] as GeoPoint?;
    return UserProfile(
      uid: uid,
      homeAddress: data['homeAddress'] as String?,
      homeLocation: homeLoc != null
          ? LatLng(homeLoc.latitude, homeLoc.longitude)
          : null,
      country: data['country'] as String?,
      hasCompletedOnboarding:
          data['hasCompletedOnboarding'] as bool? ?? false,
      garagePersonality: data['garagePersonality'] as String?,
      garagePersonalityBikeCount:
          (data['garagePersonalityBikeCount'] as num?)?.toInt() ?? 0,
      homeAffirmingMessage: data['homeAffirmingMessage'] as String?,
    );
  }
}
