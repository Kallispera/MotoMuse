import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/onboarding/data/geocoding_service.dart';
import 'package:motomuse/features/profile/data/firestore_user_profile_repository.dart';
import 'package:motomuse/features/profile/domain/user_profile.dart';

/// Provides the [FirestoreUserProfileRepository].
final userProfileRepositoryProvider =
    Provider<FirestoreUserProfileRepository>((ref) {
  return FirestoreUserProfileRepository(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Watches the user profile in real-time.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
});

/// True when the user has at least one bike but has not completed onboarding.
final needsOnboardingProvider = Provider<bool>((ref) {
  final bikes = ref.watch(userBikesProvider).valueOrNull;
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (bikes == null || profile == null) return false;
  return bikes.isNotEmpty && !profile.hasCompletedOnboarding;
});

/// Provides the [GeocodingService] for address lookup and affirming messages.
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(
    client: ref.watch(httpClientProvider),
    baseUrl: ref.watch(cloudRunBaseUrlProvider),
  );
});
