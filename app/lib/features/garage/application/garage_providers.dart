import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/garage/data/cloud_run_bike_service.dart';
import 'package:motomuse/features/garage/data/firestore_bike_repository.dart';
import 'package:motomuse/features/garage/domain/bike.dart';
import 'package:motomuse/features/garage/domain/bike_exception.dart';
import 'package:motomuse/features/garage/domain/bike_photo_analysis.dart';
import 'package:motomuse/features/garage/domain/bike_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers (overridable in tests)
// ---------------------------------------------------------------------------

/// Provides the [FirebaseStorage] singleton.
final firebaseStorageProvider = Provider<FirebaseStorage>(
  (_) => FirebaseStorage.instance,
);

/// Provides the [ImagePicker] instance.
final imagePickerProvider = Provider<ImagePicker>(
  (_) => ImagePicker(),
);

/// Provides an [http.Client] for Cloud Run calls.
final httpClientProvider = Provider<http.Client>(
  (_) => http.Client(),
);

/// The Cloud Run backend base URL.
///
/// Override this in tests or flavours to point at a local server.
const String _cloudRunBaseUrl =
    'https://motomuse-backend-887991427212.us-central1.run.app';

/// Provides the Cloud Run base URL string.
final cloudRunBaseUrlProvider = Provider<String>(
  (_) => _cloudRunBaseUrl,
);

// ---------------------------------------------------------------------------
// Service & repository providers
// ---------------------------------------------------------------------------

/// Provides the [CloudRunBikeService] used to analyse bike photos.
final cloudRunBikeServiceProvider = Provider<CloudRunBikeService>((ref) {
  return CloudRunBikeService(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: ref.watch(cloudRunBaseUrlProvider),
  );
});

/// Provides the [BikeRepository] used throughout the garage feature.
final bikeRepositoryProvider = Provider<BikeRepository>((ref) {
  return FirestoreBikeRepository(
    firestore: ref.watch(firestoreProvider),
  );
});

// ---------------------------------------------------------------------------
// Stream — the user's bikes list
// ---------------------------------------------------------------------------

/// Emits the current list of bikes for the signed-in user, updating in real
/// time. Emits an empty list while there is no signed-in user.
final userBikesProvider = StreamProvider<List<Bike>>((ref) {
  final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(bikeRepositoryProvider).watchBikes(uid);
});

// ---------------------------------------------------------------------------
// Garage personality — what the rider's collection says about them
// ---------------------------------------------------------------------------

/// Generates a one-liner about the rider's overall bike collection.
///
/// Returns `null` when the user has fewer than two bikes (no comparison to
/// make). Refreshes automatically whenever the bike list changes.
final garagePersonalityProvider = FutureProvider<String?>((ref) async {
  final bikes = ref.watch(userBikesProvider).valueOrNull;
  if (bikes == null || bikes.length < 2) return null;

  final service = ref.read(cloudRunBikeServiceProvider);
  final summaries = bikes
      .map(
        (b) => <String, dynamic>{
          'make': b.make,
          'model': b.model,
          if (b.year != null) 'year': b.year,
          if (b.category != null) 'category': b.category,
        },
      )
      .toList();

  return service.garagePersonality(summaries);
});

// ---------------------------------------------------------------------------
// AddBikeNotifier — image pick → upload → Cloud Run analysis
// ---------------------------------------------------------------------------

/// Manages the asynchronous flow of picking a photo, uploading it to Firebase
/// Storage, and calling the Cloud Run analysis endpoint.
///
/// State is `null` when idle, [BikePhotoAnalysis] on success.
class AddBikeNotifier extends AutoDisposeAsyncNotifier<BikePhotoAnalysis?> {
  @override
  FutureOr<BikePhotoAnalysis?> build() => null;

  /// Picks an image from [source], uploads it, and analyses it.
  ///
  /// Sets state to [AsyncLoading] while in progress. On success, state
  /// becomes [AsyncData] with the [BikePhotoAnalysis]. If the user cancels
  /// the picker, state returns to `AsyncData(null)`.
  Future<void> pickAndAnalyze(ImageSource source) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<BikePhotoAnalysis?>(() async {
      final picker = ref.read(imagePickerProvider);
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return null; // user cancelled the picker

      final user = ref.read(authStateChangesProvider).valueOrNull;
      if (user == null) throw const BikeException('Not signed in.');

      // Upload to Firebase Storage: bikes/{uid}/{timestamp}.jpg
      final storage = ref.read(firebaseStorageProvider);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = storage.ref('bikes/${user.uid}/$timestamp.jpg');

      final bytes = await file.readAsBytes();
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final imageUrl = await storageRef.getDownloadURL();

      // Send to Cloud Run for analysis.
      final service = ref.read(cloudRunBikeServiceProvider);
      final result = await service.analyzeBike(imageUrl);

      return BikePhotoAnalysis(result: result, imageUrl: imageUrl);
    });
  }

  /// Resets state to idle (e.g. after navigating away from the review screen).
  void reset() => state = const AsyncData(null);
}

/// Provider for [AddBikeNotifier].
final addBikeNotifierProvider =
    AutoDisposeAsyncNotifierProvider<AddBikeNotifier, BikePhotoAnalysis?>(
  AddBikeNotifier.new,
);

// ---------------------------------------------------------------------------
// ConfirmBikeNotifier — saves confirmed bike to Firestore
// ---------------------------------------------------------------------------

/// Manages saving a confirmed [Bike] to Firestore after the user reviews and
/// optionally edits the AI-extracted details.
class ConfirmBikeNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  /// Saves [bike] to `users/{uid}/bikes` in Firestore.
  ///
  /// Sets state to [AsyncLoading] while in progress. On success, state
  /// becomes `AsyncData(null)`. On failure, state becomes [AsyncError].
  Future<void> confirm(Bike bike) async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) {
      state = AsyncError(
        const BikeException('Not signed in.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () => ref.read(bikeRepositoryProvider).addBike(uid, bike),
    );
  }
}

/// Provider for [ConfirmBikeNotifier].
final confirmBikeNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ConfirmBikeNotifier, void>(
  ConfirmBikeNotifier.new,
);
