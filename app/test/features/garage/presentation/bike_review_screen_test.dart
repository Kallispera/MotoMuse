import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/garage/domain/bike.dart';
import 'package:motomuse/features/garage/domain/bike_analysis_result.dart';
import 'package:motomuse/features/garage/domain/bike_photo_analysis.dart';
import 'package:motomuse/features/garage/domain/bike_repository.dart';
import 'package:motomuse/features/garage/presentation/bike_review_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeBikeRepository extends Fake implements BikeRepository {
  bool addBikeCalled = false;
  Exception? error;

  @override
  Future<void> addBike(String uid, Bike bike) async {
    addBikeCalled = true;
    if (error != null) throw error!;
  }

  @override
  Stream<List<Bike>> watchBikes(String uid) => const Stream.empty();

  @override
  Future<void> deleteBike(String uid, String bikeId) async {}
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testUser = AppUser(
  uid: 'uid-test',
  email: 'rider@test.com',
  isEmailVerified: true,
);

BikePhotoAnalysis testAnalysis({
  String message = 'A magnificent machine!',
}) =>
    BikePhotoAnalysis(
      result: BikeAnalysisResult(
        make: 'Ducati',
        model: 'Panigale V4 S',
        year: 2023,
        color: 'Ducati Red',
        trim: 'S',
        modifications: const ['Akrapovic exhaust'],
        category: 'sport',
        affirmingMessage: message,
      ),
      imageUrl: 'https://example.com/bike.jpg',
    );

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required BikePhotoAnalysis analysis,
  required _FakeBikeRepository repo,
}) {
  return ProviderScope(
    overrides: [
      bikeRepositoryProvider.overrideWithValue(repo),
      authStateChangesProvider.overrideWith(
        (_) => Stream.value(_testUser),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Consumer(
              builder: (context, ref, _) {
                // Pre-warm authStateChangesProvider so confirm() sees
                // AsyncData rather than AsyncLoading when it reads it.
                ref.watch(authStateChangesProvider);
                return BikeReviewScreen(analysis: analysis);
              },
            ),
          ),
          GoRoute(
            path: '/garage',
            builder: (_, __) => const Scaffold(body: Text('Garage')),
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
  group('BikeReviewScreen', () {
    testWidgets('displays the affirming message', (tester) async {
      final repo = _FakeBikeRepository();
      await tester.pumpWidget(
        _buildSubject(
          analysis: testAnalysis(
            message: 'The Panigale V4 S carries racing DNA.',
          ),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The Panigale V4 S carries racing DNA.'),
        findsOneWidget,
      );
    });

    testWidgets('pre-fills make and model fields', (tester) async {
      final repo = _FakeBikeRepository();
      await tester.pumpWidget(
        _buildSubject(analysis: testAnalysis(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Ducati'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Panigale V4 S'),
        findsOneWidget,
      );
    });

    testWidgets('shows confirm button', (tester) async {
      // Expand the test surface so all content fits without scrolling.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeBikeRepository();
      await tester.pumpWidget(
        _buildSubject(analysis: testAnalysis(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Looks right \u2014 save my bike'), findsOneWidget);
    });

    testWidgets('modification chips are displayed', (tester) async {
      // Expand the test surface so all content fits without scrolling.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeBikeRepository();
      await tester.pumpWidget(
        _buildSubject(analysis: testAnalysis(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akrapovic exhaust'), findsOneWidget);
    });

    testWidgets('tapping confirm calls addBike on the repository',
        (tester) async {
      // Expand the test surface so all content fits without scrolling.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeBikeRepository();
      await tester.pumpWidget(
        _buildSubject(analysis: testAnalysis(), repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Looks right \u2014 save my bike'));
      await tester.pumpAndSettle();

      expect(repo.addBikeCalled, isTrue);
    });

    testWidgets('validation prevents confirm when make field is cleared',
        (tester) async {
      // Expand the test surface so all content fits without scrolling.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _FakeBikeRepository();
      await tester.pumpWidget(
        _buildSubject(analysis: testAnalysis(), repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ducati'),
        '',
      );
      await tester.tap(find.text('Looks right \u2014 save my bike'));
      await tester.pump();

      expect(repo.addBikeCalled, isFalse);
      expect(find.text('Required'), findsOneWidget);
    });
  });
}
