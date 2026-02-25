import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/onboarding/application/onboarding_providers.dart';
import 'package:motomuse/features/profile/domain/user_profile.dart';
import 'package:motomuse/features/profile/presentation/profile_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testUser = AppUser(
  uid: 'uid123',
  email: 'rider@test.com',
  isEmailVerified: true,
  displayName: 'Test Rider',
);

const _testUserNoName = AppUser(
  uid: 'uid123',
  email: 'rider@test.com',
  isEmailVerified: true,
);

const _profileWithAddress = UserProfile(
  uid: 'uid123',
  homeAddress: 'Amsterdam, Netherlands',
  hasCompletedOnboarding: true,
  homeAffirmingMessage: 'You live near great riding!',
);

const _profileNoAddress = UserProfile(
  uid: 'uid123',
  hasCompletedOnboarding: true,
);

Widget _buildSubject({
  AppUser? user = _testUser,
  UserProfile? profile,
}) {
  return ProviderScope(
    overrides: [
      authStateChangesProvider.overrideWith(
        (_) => Stream.value(user),
      ),
      userProfileProvider.overrideWith(
        (_) => Stream.value(profile),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProfileScreen', () {
    group('user info card', () {
      testWidgets('shows display name and email', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Rider'), findsOneWidget);
        expect(find.text('rider@test.com'), findsOneWidget);
      });

      testWidgets('shows only email when no display name', (tester) async {
        await tester.pumpWidget(
          _buildSubject(user: _testUserNoName, profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('rider@test.com'), findsOneWidget);
        // No display name text widget — only email.
        expect(find.text('Test Rider'), findsNothing);
      });
    });

    group('home address section', () {
      testWidgets('shows address input when no address saved', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Home address'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Save address'), findsOneWidget);
      });

      testWidgets('shows saved address and affirming message', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileWithAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Amsterdam, Netherlands'), findsOneWidget);
        expect(find.text('You live near great riding!'), findsOneWidget);
        expect(find.text('Update address'), findsOneWidget);
      });

      testWidgets('tapping Update address shows edit form', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileWithAddress),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Update address'));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Save address'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('cancel returns to display mode', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileWithAddress),
        );
        await tester.pumpAndSettle();

        // Enter edit mode.
        await tester.tap(find.text('Update address'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);

        // Cancel.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Amsterdam, Netherlands'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('shows error when saving empty address', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        // Tap save with empty field.
        await tester.tap(find.text('Save address'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter an address'), findsOneWidget);
      });
    });

    group('sign out', () {
      testWidgets('shows sign out button', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign out'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });
    });
  });
}
