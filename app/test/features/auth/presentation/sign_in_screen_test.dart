import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/auth/domain/auth_exception.dart';
import 'package:motomuse/features/auth/domain/auth_repository.dart';
import 'package:motomuse/features/auth/presentation/sign_in_screen.dart';

// ---------------------------------------------------------------------------
// Fakes / mocks
// ---------------------------------------------------------------------------

class _FakeAuthRepository extends Fake implements AuthRepository {
  final _calls = <String>[];

  /// When non-null, every auth operation will throw this exception.
  Exception? failureOverride;

  List<String> get calls => List.unmodifiable(_calls);

  @override
  Stream<AppUser?> get authStateChanges => Stream.value(null);

  @override
  AppUser? get currentUser => null;

  @override
  Future<AppUser> signInWithGoogle() async {
    _calls.add('signInWithGoogle');
    if (failureOverride != null) throw failureOverride!;
    return const AppUser(
      uid: 'uid',
      email: 'g@test.com',
      isEmailVerified: true,
    );
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _calls.add('signInWithEmail:$email');
    if (failureOverride != null) throw failureOverride!;
    return AppUser(uid: 'uid', email: email, isEmailVerified: false);
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _calls.add('createAccount:$email');
    if (failureOverride != null) throw failureOverride!;
    return AppUser(uid: 'uid', email: email, isEmailVerified: false);
  }

  @override
  Future<void> signOut() async {
    _calls.add('signOut');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject(_FakeAuthRepository repo) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: SignInScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SignInScreen', () {
    group('initial render', () {
      testWidgets('shows app title', (tester) async {
        await tester.pumpWidget(_buildSubject(_FakeAuthRepository()));
        expect(find.text('MotoMuse'), findsOneWidget);
      });

      testWidgets('shows tagline', (tester) async {
        await tester.pumpWidget(_buildSubject(_FakeAuthRepository()));
        expect(
          find.text('The road chooses its riders.'),
          findsOneWidget,
        );
      });

      testWidgets('shows Continue with Google button', (tester) async {
        await tester.pumpWidget(_buildSubject(_FakeAuthRepository()));
        expect(find.text('Continue with Google'), findsOneWidget);
      });

      testWidgets('shows email and password fields', (tester) async {
        await tester.pumpWidget(_buildSubject(_FakeAuthRepository()));
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets('shows Sign In button by default', (tester) async {
        await tester.pumpWidget(_buildSubject(_FakeAuthRepository()));
        expect(find.text('Sign In'), findsOneWidget);
      });

      testWidgets('create account toggle switches primary button label',
          (tester) async {
        await tester.pumpWidget(_buildSubject(_FakeAuthRepository()));
        await tester.tap(find.text("Don't have an account? Create one"));
        await tester.pump();
        expect(find.text('Create Account'), findsOneWidget);
      });
    });

    group('Google sign-in', () {
      testWidgets('tapping Google button calls signInWithGoogle',
          (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_buildSubject(repo));

        await tester.tap(find.text('Continue with Google'));
        await tester.pump();

        expect(repo.calls, contains('signInWithGoogle'));
      });
    });

    group('email sign-in', () {
      testWidgets('tapping Sign In submits email and password', (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_buildSubject(repo));

        await tester.enterText(
          find.byType(TextFormField).first,
          'user@test.com',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'mypassword',
        );
        await tester.tap(find.text('Sign In'));
        await tester.pump();

        expect(repo.calls, contains('signInWithEmail:user@test.com'));
      });

      testWidgets('tapping Create Account calls createAccount', (tester) async {
        final repo = _FakeAuthRepository();
        await tester.pumpWidget(_buildSubject(repo));

        // Switch to create-account mode.
        await tester.tap(find.text("Don't have an account? Create one"));
        await tester.pump();

        await tester.enterText(
          find.byType(TextFormField).first,
          'new@test.com',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'newpass',
        );
        await tester.tap(find.text('Create Account'));
        await tester.pump();

        expect(repo.calls, contains('createAccount:new@test.com'));
      });
    });

    group('error handling', () {
      testWidgets('shows SnackBar when sign-in fails with AuthException',
          (tester) async {
        final repo = _FakeAuthRepository()
          ..failureOverride =
              const AuthException('Incorrect email or password.');
        await tester.pumpWidget(_buildSubject(repo));

        await tester.tap(find.text('Sign In'));
        // Pump through the async operation and the animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Incorrect email or password.'),
          findsOneWidget,
        );
      });

      testWidgets(
          'shows generic error message when a non-AuthException is thrown',
          (tester) async {
        final repo = _FakeAuthRepository()
          ..failureOverride = Exception('Some internal error');
        await tester.pumpWidget(_buildSubject(repo));

        await tester.tap(find.text('Sign In'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Sign-in failed. Please try again.'),
          findsOneWidget,
        );
      });
    });
  });
}
