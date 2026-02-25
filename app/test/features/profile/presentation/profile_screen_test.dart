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
  defaultCurviness: 4,
  defaultSceneryType: 'forests',
  defaultDistanceKm: 200,
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

      testWidgets('shows only email when no display name',
          (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            user: _testUserNoName,
            profile: _profileNoAddress,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('rider@test.com'), findsOneWidget);
        expect(find.text('Test Rider'), findsNothing);
      });
    });

    group('rider profile section', () {
      testWidgets('shows section header', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rider profile'), findsOneWidget);
      });

      testWidgets('shows address input when no address saved',
          (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Home address'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('shows saved address and affirming message',
          (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileWithAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Amsterdam, Netherlands'), findsOneWidget);
        expect(
          find.text('You live near great riding!'),
          findsOneWidget,
        );
      });

      testWidgets('tapping edit icon shows address form',
          (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileWithAddress),
        );
        await tester.pumpAndSettle();

        // Tap the edit icon button.
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('cancel returns to display mode', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileWithAddress),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Amsterdam, Netherlands'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('shows error when saving empty address',
          (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter an address'), findsOneWidget);
      });
    });

    group('riding preferences', () {
      testWidgets('shows preferences section', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Riding preferences'), findsOneWidget);
        expect(find.text('Curviness'), findsOneWidget);
        expect(find.text('Scenery'), findsOneWidget);
        expect(find.text('Default distance'), findsOneWidget);
      });

      testWidgets('shows scenery filter chips', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.text('Forests'), findsOneWidget);
        expect(find.text('Coast'), findsOneWidget);
        expect(find.text('Mountains'), findsOneWidget);
        expect(find.text('Mixed'), findsOneWidget);
      });

      testWidgets('shows distance slider with km label',
          (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsOneWidget);
        // Default distance label.
        expect(find.text('150 km'), findsOneWidget);
      });

      testWidgets(
        'initializes from saved profile preferences',
        (tester) async {
          await tester.pumpWidget(
            _buildSubject(profile: _profileWithAddress),
          );
          await tester.pumpAndSettle();

          // Profile has defaultDistanceKm: 200.
          expect(find.text('200 km'), findsOneWidget);
        },
      );

      testWidgets('shows save button after changing curviness',
          (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        // No save button initially.
        expect(find.text('Save preferences'), findsNothing);

        // Tap the 5th curviness star (filled stars use star_rounded).
        // Default is 3, so stars 4 and 5 are outline icons.
        // Find outline star icons and tap the first one (star 4).
        final outlineStars = find.byIcon(Icons.star_outline_rounded);
        await tester.tap(outlineStars.first);
        await tester.pumpAndSettle();

        // Scroll down to see the save button.
        await tester.dragUntilVisible(
          find.text('Save preferences'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        expect(find.text('Save preferences'), findsOneWidget);
      });
    });

    group('sign out', () {
      testWidgets('shows sign out button', (tester) async {
        await tester.pumpWidget(
          _buildSubject(profile: _profileNoAddress),
        );
        await tester.pumpAndSettle();

        // Scroll to the bottom to find sign out.
        await tester.dragUntilVisible(
          find.text('Sign out'),
          find.byType(ListView),
          const Offset(0, -200),
        );

        expect(find.text('Sign out'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });
    });
  });
}
