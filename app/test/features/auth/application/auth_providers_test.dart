import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/auth/domain/auth_exception.dart';
import 'package:motomuse/features/auth/domain/auth_repository.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class _FakeAuthRepository extends Fake implements AuthRepository {
  AppUser? _user;
  Exception? _error;

  void setUser(AppUser user) {
    _user = user;
    _error = null;
  }

  void setError(Exception error) {
    _error = error;
    _user = null;
  }

  @override
  Stream<AppUser?> get authStateChanges => Stream.value(_user);

  @override
  AppUser? get currentUser => _user;

  @override
  Future<AppUser> signInWithGoogle() async {
    if (_error != null) throw _error!;
    return _user!;
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_error != null) throw _error!;
    return _user!;
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_error != null) throw _error!;
    return _user!;
  }

  @override
  Future<void> signOut() async {
    if (_error != null) throw _error!;
    _user = null;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testUser = AppUser(
  uid: 'uid-test',
  email: 'test@motomuse.app',
  isEmailVerified: true,
);

ProviderContainer _buildContainer(_FakeAuthRepository repo) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('authStateChangesProvider', () {
    test('emits null when no user is signed in', () async {
      final repo = _FakeAuthRepository();
      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      // Allow stream to settle.
      await container.read(authStateChangesProvider.future);

      expect(
        container.read(authStateChangesProvider).valueOrNull,
        isNull,
      );
    });

    test('emits AppUser when a user is present', () async {
      final repo = _FakeAuthRepository()..setUser(_testUser);
      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      await container.read(authStateChangesProvider.future);

      expect(
        container.read(authStateChangesProvider).valueOrNull,
        equals(_testUser),
      );
    });
  });

  group('AuthNotifier', () {
    group('signInWithGoogle', () {
      test('state is AsyncData after successful sign-in', () async {
        final repo = _FakeAuthRepository()..setUser(_testUser);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .signInWithGoogle();

        expect(
          container.read(authNotifierProvider),
          isA<AsyncData<void>>(),
        );
      });

      test('state is AsyncError when Google Sign-In fails', () async {
        final repo = _FakeAuthRepository()
          ..setError(const AuthException('Sign-in was cancelled.'));
        final container = _buildContainer(repo);
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .signInWithGoogle();

        final state = container.read(authNotifierProvider);
        expect(state, isA<AsyncError<void>>());
        expect(state.error, isA<AuthException>());
      });
    });

    group('signInWithEmail', () {
      test('state is AsyncData after successful email sign-in', () async {
        final repo = _FakeAuthRepository()..setUser(_testUser);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.notifier).signInWithEmail(
              email: 'test@motomuse.app',
              password: 'password123',
            );

        expect(
          container.read(authNotifierProvider),
          isA<AsyncData<void>>(),
        );
      });

      test('state is AsyncError on wrong credentials', () async {
        final repo = _FakeAuthRepository()
          ..setError(
            const AuthException('Incorrect email or password.'),
          );
        final container = _buildContainer(repo);
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.notifier).signInWithEmail(
              email: 'x@test.com',
              password: 'wrong',
            );

        expect(
          container.read(authNotifierProvider),
          isA<AsyncError<void>>(),
        );
      });
    });

    group('createAccount', () {
      test('state is AsyncData after successful account creation', () async {
        final repo = _FakeAuthRepository()..setUser(_testUser);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.notifier).createAccount(
              email: 'new@test.com',
              password: 'newpass123',
            );

        expect(
          container.read(authNotifierProvider),
          isA<AsyncData<void>>(),
        );
      });
    });

    group('signOut', () {
      test('state is AsyncData after sign-out', () async {
        final repo = _FakeAuthRepository()..setUser(_testUser);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.notifier).signOut();

        expect(
          container.read(authNotifierProvider),
          isA<AsyncData<void>>(),
        );
      });

      test('state is AsyncError when sign-out fails', () async {
        final repo = _FakeAuthRepository()
          ..setError(Exception('Network error'));
        final container = _buildContainer(repo);
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.notifier).signOut();

        expect(
          container.read(authNotifierProvider),
          isA<AsyncError<void>>(),
        );
      });
    });
  });
}
