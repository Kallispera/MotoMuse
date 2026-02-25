import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// User profile stored in Firestore at `users/{uid}`.
@immutable
class UserProfile {
  /// Creates a [UserProfile].
  const UserProfile({
    required this.uid,
    this.homeAddress,
    this.homeLocation,
    this.country,
    this.hasCompletedOnboarding = false,
    this.garagePersonality,
    this.garagePersonalityBikeCount = 0,
    this.homeAffirmingMessage,
  });

  /// Firebase Auth UID.
  final String uid;

  /// Human-readable home address.
  final String? homeAddress;

  /// Geocoded home coordinates.
  final LatLng? homeLocation;

  /// Country code (e.g. "nl").
  final String? country;

  /// Whether the user has completed the post-bike onboarding flow.
  final bool hasCompletedOnboarding;

  /// Cached garage personality message (regenerated when bike count changes).
  final String? garagePersonality;

  /// Number of bikes when the garage personality was last generated.
  final int garagePersonalityBikeCount;

  /// Affirming message about the rider's closest riding region.
  final String? homeAffirmingMessage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
