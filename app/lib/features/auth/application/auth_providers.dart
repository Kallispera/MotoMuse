import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:motomuse/features/auth/data/firebase_auth_repository.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/auth/domain/auth_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers (overridable in tests)
// ---------------------------------------------------------------------------

/// Provides the [FirebaseAuth] singleton.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

/// Provides the [GoogleSignIn] instance.
final googleSignInProvider = Provider<GoogleSignIn>(
  (_) => GoogleSignIn(),
);

/// Provides the [FirebaseFirestore] singleton.
final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Provides the [AuthRepository] used throughout the app.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

// ---------------------------------------------------------------------------
// Auth state stream
// ---------------------------------------------------------------------------

/// Emits the current [AppUser] (or `null`) whenever Firebase auth state
/// changes. Used by the router to protect routes.
final authStateChangesProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

// ---------------------------------------------------------------------------
// Auth notifier — drives sign-in/sign-out operations
// ---------------------------------------------------------------------------

/// Manages auth operation state (loading, error) for the sign-in screen.
///
/// Use [authNotifierProvider] to trigger sign-in or sign-out; use
/// [authStateChangesProvider] to react to the resulting auth state change.
class AuthNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  /// Signs in with Google. Sets state to [AsyncLoading] while in progress.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  /// Signs in with [email] and [password].
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () => ref.read(authRepositoryProvider).signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
    );
  }

  /// Creates a new account with [email] and [password].
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () => ref.read(authRepositoryProvider).createUserWithEmailAndPassword(
            email: email,
            password: password,
          ),
    );
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}

/// Provider for [AuthNotifier].
final authNotifierProvider =
    AutoDisposeAsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
