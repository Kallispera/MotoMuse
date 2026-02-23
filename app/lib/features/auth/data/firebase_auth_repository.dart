import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/auth/domain/auth_exception.dart';
import 'package:motomuse/features/auth/domain/auth_repository.dart';

/// Firebase implementation of [AuthRepository].
///
/// Depends on [FirebaseAuth], [GoogleSignIn], and [FirebaseFirestore] being
/// injected so that all three can be replaced with fakes in tests.
///
/// **Android setup:** Before Google Sign-In will work on a physical device or
/// release build, register the app's SHA-1 fingerprint in the Firebase Console
/// (Project settings → Your apps → Android app → Add fingerprint). The debug
/// SHA-1 from `./gradlew signingReport` is sufficient for development.
///
/// **iOS setup:** Add the REVERSED_CLIENT_ID value from
/// `GoogleService-Info.plist` as a URL scheme in
/// `ios/Runner/Info.plist` under CFBundleURLSchemes.
class FirebaseAuthRepository implements AuthRepository {
  /// Creates a [FirebaseAuthRepository].
  const FirebaseAuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FirebaseFirestore firestore,
  })  : _auth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  @override
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().map(
          (user) => user == null ? null : _mapUser(user),
        );
  }

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const AuthException('Sign-in failed. Please try again.');
      }

      await _ensureUserProfile(user);
      return _mapUser(user);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw const AuthException('Sign-in failed. Please try again.');
      }

      await _ensureUserProfile(user);
      return _mapUser(user);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw const AuthException('Account creation failed. Please try again.');
      }

      await _ensureUserProfile(user);
      return _mapUser(user);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Creates a user profile document in Firestore on first sign-in, or
  /// updates `lastSignInAt` on subsequent sign-ins.
  Future<void> _ensureUserProfile(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set(<String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignInAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update(<String, dynamic>{
        'lastSignInAt': FieldValue.serverTimestamp(),
      });
    }
  }

  AppUser _mapUser(User user) => AppUser(
        uid: user.uid,
        email: user.email ?? '',
        isEmailVerified: user.emailVerified,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );

  AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        const AuthException('Incorrect email or password. Please try again.'),
      'email-already-in-use' =>
        const AuthException('An account with this email already exists.'),
      'invalid-email' =>
        const AuthException('Please enter a valid email address.'),
      'weak-password' =>
        const AuthException('Password must be at least 6 characters.'),
      'network-request-failed' =>
        const AuthException('Network error. Please check your connection.'),
      'too-many-requests' =>
        const AuthException('Too many attempts. Please try again later.'),
      _ => const AuthException('Sign-in failed. Please try again.'),
    };
  }
}
