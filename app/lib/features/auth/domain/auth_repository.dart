import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/auth/domain/auth_exception.dart';

/// Contract for all authentication operations.
///
/// Implementations (e.g. `FirebaseAuthRepository`) must fulfil this interface
/// so that upper layers (presentation, application) depend only on the
/// abstraction and can be tested with fake repositories.
abstract class AuthRepository {
  /// A stream that emits the currently signed-in [AppUser] whenever the auth
  /// state changes, or `null` when the user is signed out.
  Stream<AppUser?> get authStateChanges;

  /// The synchronously available current user, or `null` if not signed in.
  AppUser? get currentUser;

  /// Signs the user in via Google OAuth.
  ///
  /// Returns the authenticated [AppUser] on success.
  /// Throws [AuthException] if the sign-in is cancelled or fails.
  Future<AppUser> signInWithGoogle();

  /// Signs the user in with [email] and [password].
  ///
  /// Throws [AuthException] with a user-friendly message on failure.
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Creates a new account with [email] and [password].
  ///
  /// Throws [AuthException] with a user-friendly message on failure.
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs the current user out from all providers.
  Future<void> signOut();
}
