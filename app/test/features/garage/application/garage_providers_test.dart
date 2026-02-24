import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/garage/domain/bike.dart';
import 'package:motomuse/features/garage/domain/bike_exception.dart';
import 'package:motomuse/features/garage/domain/bike_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeBikeRepository extends Fake implements BikeRepository {
  final _controller = StreamController<List<Bike>>();
  Exception? addBikeError;
  bool addBikeCalled = false;

  void emit(List<Bike> bikes) => _controller.add(bikes);

  @override
  Stream<List<Bike>> watchBikes(String uid) => _controller.stream;

  @override
  Future<void> addBike(String uid, Bike bike) async {
    addBikeCalled = true;
    if (addBikeError != null) throw addBikeError!;
  }

  @override
  Future<void> deleteBike(String uid, String bikeId) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testUser = AppUser(
  uid: 'uid-test',
  email: 'rider@test.com',
  isEmailVerified: true,
);

Bike bike({String id = 'b1', String make = 'Ducati'}) => Bike(
      id: id,
      make: make,
      model: 'Panigale V4 S',
      affirmingMessage: 'A masterpiece.',
      imageUrl: 'https://example.com/bike.jpg',
      addedAt: DateTime(2025),
    );

ProviderContainer _buildContainer({
  required _FakeBikeRepository repo,
  AppUser? user,
}) {
  return ProviderContainer(
    overrides: [
      bikeRepositoryProvider.overrideWithValue(repo),
      authStateChangesProvider.overrideWith(
        (_) => Stream.value(user),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // userBikesProvider
  // ---------------------------------------------------------------------------

  group('userBikesProvider', () {
    test('stays loading when user is null (stream never emits)', () async {
      final repo = _FakeBikeRepository();
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);

      // When user is null the provider uses Stream.empty() which never emits,
      // so the provider remains in AsyncLoading.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final value = container.read(userBikesProvider);
      expect(value, isA<AsyncLoading<List<Bike>>>());
    });

    test('emits bikes when user is signed in', () async {
      final repo = _FakeBikeRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      // Trigger the provider to be watched.
      container.listen(userBikesProvider, (_, __) {});

      final bikes = [bike()];
      repo.emit(bikes);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final value = container.read(userBikesProvider);
      expect(value.valueOrNull, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // ConfirmBikeNotifier
  // ---------------------------------------------------------------------------

  group('ConfirmBikeNotifier', () {
    test('initial state is AsyncData(null)', () {
      final repo = _FakeBikeRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      final state = container.read(confirmBikeNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('confirm() succeeds and state becomes AsyncData', () async {
      final repo = _FakeBikeRepository();
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      // Pre-warm authStateChangesProvider so the stream emits before confirm()
      // reads it (StreamProvider starts AsyncLoading until first emission).
      container.read(authStateChangesProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(confirmBikeNotifierProvider.notifier)
          .confirm(bike());

      final state = container.read(confirmBikeNotifierProvider);
      expect(state, isA<AsyncData<void>>());
      expect(repo.addBikeCalled, isTrue);
    });

    test('confirm() sets AsyncError when no user is signed in', () async {
      final repo = _FakeBikeRepository();
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);

      await container
          .read(confirmBikeNotifierProvider.notifier)
          .confirm(bike());

      final state = container.read(confirmBikeNotifierProvider);
      expect(state, isA<AsyncError<void>>());
      expect(state.error, isA<BikeException>());
    });

    test('confirm() sets AsyncError when repository throws', () async {
      final repo = _FakeBikeRepository()
        ..addBikeError = const BikeException('Firestore failed.');
      final container = _buildContainer(repo: repo, user: _testUser);
      addTearDown(container.dispose);

      // Pre-warm authStateChangesProvider so confirm() sees AsyncData.
      container.read(authStateChangesProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(confirmBikeNotifierProvider.notifier)
          .confirm(bike());

      final state = container.read(confirmBikeNotifierProvider);
      expect(state, isA<AsyncError<void>>());
      expect(
        state.error,
        isA<BikeException>().having(
          (e) => e.message,
          'message',
          contains('Firestore failed'),
        ),
      );
    });
  });
}
