import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/garage/domain/bike_photo_analysis.dart';
import 'package:motomuse/features/garage/presentation/add_bike_screen.dart';

// ---------------------------------------------------------------------------
// Fake notifier — extends AddBikeNotifier so overrideWith type-checks
// ---------------------------------------------------------------------------

class _FakeAddBikeNotifier extends AddBikeNotifier {
  @override
  Future<BikePhotoAnalysis?> build() async => null;

  /// Simulates a successful analysis result without touching ImagePicker.
  void simulateSuccess(BikePhotoAnalysis analysis) =>
      state = AsyncData(analysis);

  /// Simulates an error state.
  void simulateError(Exception e) =>
      state = AsyncError(e, StackTrace.empty);

  /// Simulates the loading state.
  void simulateLoading() => state = const AsyncLoading();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject(_FakeAddBikeNotifier notifier) {
  return ProviderScope(
    overrides: [
      addBikeNotifierProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const AddBikeScreen(),
          ),
          GoRoute(
            path: '/garage/review',
            builder: (_, __) => const Scaffold(body: Text('Review')),
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
  group('AddBikeScreen', () {
    testWidgets('shows camera and gallery buttons in idle state',
        (tester) async {
      final notifier = _FakeAddBikeNotifier();
      await tester.pumpWidget(_buildSubject(notifier));
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });

    testWidgets('shows loading indicator and copy when analysing',
        (tester) async {
      final notifier = _FakeAddBikeNotifier();
      await tester.pumpWidget(_buildSubject(notifier));
      await tester.pumpAndSettle();

      notifier.simulateLoading();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Identifying your machine…'), findsOneWidget);
      // Picker buttons should be hidden.
      expect(find.text('Take a photo'), findsNothing);
    });

    testWidgets('shows SnackBar on error', (tester) async {
      final notifier = _FakeAddBikeNotifier();
      await tester.pumpWidget(_buildSubject(notifier));
      await tester.pumpAndSettle();

      notifier.simulateError(Exception('Network issue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('screen title is "Add a bike"', (tester) async {
      final notifier = _FakeAddBikeNotifier();
      await tester.pumpWidget(_buildSubject(notifier));
      await tester.pumpAndSettle();

      expect(find.text('Add a bike'), findsOneWidget);
    });
  });
}
