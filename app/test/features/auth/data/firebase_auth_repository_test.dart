import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:motomuse/features/auth/data/firebase_auth_repository.dart';
import 'package:motomuse/features/auth/domain/auth_exception.dart';

// ---------------------------------------------------------------------------
// Mocks — only Firebase Auth and Google Sign-In are mocked; Firestore uses
// FakeFirebaseFirestore so we never subtype the sealed Firestore classes.
// ---------------------------------------------------------------------------

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class _MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

/// Fake used only for registering a fallback value for [AuthCredential] so
/// that `any()` matchers work in tests that mock
/// [FirebaseAuth.signInWithCredential].
class _FakeAuthCredential extends Fake implements AuthCredential {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FirebaseAuthRepository _buildRepo({
  required FirebaseAuth auth,
  required GoogleSignIn googleSignIn,
  required FirebaseFirestore firestore,
}) {
  return FirebaseAuthRepository(
    firebaseAuth: auth,
    googleSignIn: googleSignIn,
    firestore: firestore,
  );
}

_MockUser _stubUser({
  String uid = 'uid-test',
  String email = 'test@motomuse.app',
  bool emailVerified = true,
  String? displayName,
}) {
  final user = _MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.email).thenReturn(email);
  when(() => user.emailVerified).thenReturn(emailVerified);
  when(() => user.displayName).thenReturn(displayName);
  when(() => user.photoURL).thenReturn(null);
  return user;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockFirebaseAuth auth;
  late _MockGoogleSignIn googleSignIn;
  late FakeFirebaseFirestore firestore;

  setUpAll(() {
    registerFallbackValue(_FakeAuthCredential());
  });

  setUp(() {
    auth = _MockFirebaseAuth();
    googleSignIn = _MockGoogleSignIn();
    firestore = FakeFirebaseFirestore();
  });

  group('FirebaseAuthRepository', () {
    // -------------------------------------------------------------------------
    // authStateChanges
    // -------------------------------------------------------------------------

    group('authStateChanges', () {
      test('emits null when user is signed out', () async {
        when(() => auth.authStateChanges())
            .thenAnswer((_) => Stream.value(null));

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await expectLater(repo.authStateChanges, emits(isNull));
      });

      test('emits AppUser when user is signed in', () async {
        final user = _stubUser(uid: 'uid-1', email: 'rider@test.com');
        when(() => auth.authStateChanges())
            .thenAnswer((_) => Stream.value(user));

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        final emitted = await repo.authStateChanges.first;
        expect(emitted, isNotNull);
        expect(emitted!.uid, equals('uid-1'));
        expect(emitted.email, equals('rider@test.com'));
      });
    });

    // -------------------------------------------------------------------------
    // currentUser
    // -------------------------------------------------------------------------

    group('currentUser', () {
      test('returns null when no user is signed in', () {
        when(() => auth.currentUser).thenReturn(null);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        expect(repo.currentUser, isNull);
      });

      test('returns AppUser when a user is signed in', () {
        final user = _stubUser(uid: 'uid-42', email: 'test@test.com');
        when(() => auth.currentUser).thenReturn(user);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        expect(repo.currentUser, isNotNull);
        expect(repo.currentUser!.uid, equals('uid-42'));
      });
    });

    // -------------------------------------------------------------------------
    // signInWithGoogle
    // -------------------------------------------------------------------------

    group('signInWithGoogle', () {
      test('returns AppUser and creates Firestore profile for new user',
          () async {
        const uid = 'uid-google';
        const email = 'google@test.com';

        final googleAccount = _MockGoogleSignInAccount();
        final googleAuthObj = _MockGoogleSignInAuthentication();
        final credential = _MockUserCredential();
        final user = _stubUser(
          uid: uid,
          email: email,
          displayName: 'Google Rider',
        );

        when(() => googleSignIn.signIn())
            .thenAnswer((_) async => googleAccount);
        when(() => googleAccount.authentication)
            .thenAnswer((_) async => googleAuthObj);
        when(() => googleAuthObj.accessToken).thenReturn('access-token');
        when(() => googleAuthObj.idToken).thenReturn('id-token');
        when(() => auth.signInWithCredential(any()))
            .thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        final result = await repo.signInWithGoogle();

        expect(result.uid, equals(uid));
        expect(result.email, equals(email));
        expect(result.displayName, equals('Google Rider'));

        // Verify Firestore profile was created.
        final doc = await firestore.collection('users').doc(uid).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['email'], equals(email));
        expect(doc.data()!['createdAt'], isNotNull);
      });

      test('updates lastSignInAt for existing user', () async {
        const uid = 'uid-existing';

        // Pre-populate to simulate a returning user.
        await firestore.collection('users').doc(uid).set(<String, dynamic>{
          'uid': uid,
          'createdAt': Timestamp.now(),
        });

        final googleAccount = _MockGoogleSignInAccount();
        final googleAuthObj = _MockGoogleSignInAuthentication();
        final credential = _MockUserCredential();
        final user = _stubUser(uid: uid, email: 'old@test.com');

        when(() => googleSignIn.signIn())
            .thenAnswer((_) async => googleAccount);
        when(() => googleAccount.authentication)
            .thenAnswer((_) async => googleAuthObj);
        when(() => googleAuthObj.accessToken).thenReturn('token');
        when(() => googleAuthObj.idToken).thenReturn('id');
        when(() => auth.signInWithCredential(any()))
            .thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await repo.signInWithGoogle();

        final doc = await firestore.collection('users').doc(uid).get();
        expect(doc.data()!['createdAt'], isNotNull);
        expect(doc.data()!['lastSignInAt'], isNotNull);
      });

      test('throws AuthException when user cancels Google Sign-In', () async {
        when(() => googleSignIn.signIn()).thenAnswer((_) async => null);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await expectLater(
          repo.signInWithGoogle,
          throwsA(isA<AuthException>()),
        );
      });

      test('maps FirebaseAuthException to AuthException', () async {
        final googleAccount = _MockGoogleSignInAccount();
        final googleAuthObj = _MockGoogleSignInAuthentication();

        when(() => googleSignIn.signIn())
            .thenAnswer((_) async => googleAccount);
        when(() => googleAccount.authentication)
            .thenAnswer((_) async => googleAuthObj);
        when(() => googleAuthObj.accessToken).thenReturn('token');
        when(() => googleAuthObj.idToken).thenReturn('id');
        when(() => auth.signInWithCredential(any()))
            .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await expectLater(
          repo.signInWithGoogle,
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Network error'),
            ),
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    // signInWithEmailAndPassword
    // -------------------------------------------------------------------------

    group('signInWithEmailAndPassword', () {
      test('returns AppUser and creates Firestore profile on success',
          () async {
        const email = 'a@b.com';
        const uid = 'uid-email';
        final credential = _MockUserCredential();
        final user = _stubUser(uid: uid, email: email);

        when(
          () => auth.signInWithEmailAndPassword(
            email: email,
            password: 'secret',
          ),
        ).thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        final result = await repo.signInWithEmailAndPassword(
          email: email,
          password: 'secret',
        );

        expect(result.uid, equals(uid));
        expect(result.email, equals(email));

        final doc = await firestore.collection('users').doc(uid).get();
        expect(doc.exists, isTrue);
      });

      test('maps user-not-found to friendly AuthException', () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: 'user-not-found'));

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await expectLater(
          () => repo.signInWithEmailAndPassword(
            email: 'nobody@test.com',
            password: 'pass',
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Incorrect email or password'),
            ),
          ),
        );
      });

      test('maps email-already-in-use to AuthException', () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await expectLater(
          () => repo.signInWithEmailAndPassword(
            email: 'x@test.com',
            password: 'pass',
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('already exists'),
            ),
          ),
        );
      });

      test('unknown FirebaseAuthException code uses generic message', () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: 'some-unknown-code'));

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await expectLater(
          () => repo.signInWithEmailAndPassword(
            email: 'x@test.com',
            password: 'pass',
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Sign-in failed'),
            ),
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    // createUserWithEmailAndPassword
    // -------------------------------------------------------------------------

    group('createUserWithEmailAndPassword', () {
      test('returns AppUser and creates Firestore profile', () async {
        const email = 'new@test.com';
        const uid = 'uid-new';
        final credential = _MockUserCredential();
        final user = _stubUser(uid: uid, email: email);

        when(
          () => auth.createUserWithEmailAndPassword(
            email: email,
            password: 'strongpass',
          ),
        ).thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        final result = await repo.createUserWithEmailAndPassword(
          email: email,
          password: 'strongpass',
        );

        expect(result.email, equals(email));

        final doc = await firestore.collection('users').doc(uid).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['email'], equals(email));
      });

      test('maps weak-password to AuthException', () async {
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: 'weak-password'));

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await expectLater(
          () => repo.createUserWithEmailAndPassword(
            email: 'x@test.com',
            password: '123',
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('6 characters'),
            ),
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    // signOut
    // -------------------------------------------------------------------------

    group('signOut', () {
      test('signs out from both Firebase and Google', () async {
        when(auth.signOut).thenAnswer((_) async {});
        when(googleSignIn.signOut).thenAnswer((_) async => null);

        final repo = _buildRepo(
          auth: auth,
          googleSignIn: googleSignIn,
          firestore: firestore,
        );

        await repo.signOut();

        verify(auth.signOut).called(1);
        verify(googleSignIn.signOut).called(1);
      });
    });
  });
}
