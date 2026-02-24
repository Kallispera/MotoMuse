import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/garage/domain/bike.dart';
import 'package:motomuse/features/garage/presentation/garage_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Bike testBike({String make = 'Ducati', String model = 'Panigale V4 S'}) =>
    Bike(
      id: 'b1',
      make: make,
      model: model,
      affirmingMessage: 'A masterpiece.',
      imageUrl: 'https://example.com/bike.jpg',
      addedAt: DateTime(2025),
      year: 2023,
      category: 'sport',
    );

Widget buildSubject(AsyncValue<List<Bike>> bikesValue) {
  return ProviderScope(
    overrides: [
      userBikesProvider.overrideWith(
        (_) => Stream.value(bikesValue.valueOrNull ?? const []),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const GarageScreen(),
          ),
          GoRoute(
            path: '/garage/add',
            builder: (_, __) => const Scaffold(body: Text('Add')),
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
  group('GarageScreen', () {
    testWidgets('shows empty state when user has no bikes', (tester) async {
      await tester.pumpWidget(buildSubject(const AsyncData([])));
      await tester.pumpAndSettle();

      expect(find.text('Your garage is empty.'), findsOneWidget);
      expect(
        find.text('Every ride starts with knowing your machine.'),
        findsOneWidget,
      );
    });

    testWidgets('FAB is visible at all times', (tester) async {
      await tester.pumpWidget(buildSubject(const AsyncData([])));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add bike'), findsOneWidget);
    });

    testWidgets('shows bike cards when bikes exist', (tester) async {
      final bikes = [
        testBike(),
        testBike(make: 'Honda', model: 'CB500F'),
      ];

      await tester.pumpWidget(buildSubject(AsyncData(bikes)));
      await tester.pumpAndSettle();

      expect(find.text('Panigale V4 S'), findsOneWidget);
      expect(find.text('CB500F'), findsOneWidget);
    });

    testWidgets('shows year and make in card label', (tester) async {
      await tester.pumpWidget(buildSubject(AsyncData([testBike()])));
      await tester.pumpAndSettle();

      expect(find.text('2023 Ducati'), findsOneWidget);
    });

    testWidgets('shows loading indicator while stream has not emitted',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userBikesProvider.overrideWith(
              (_) => const Stream<List<Bike>>.empty(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const GarageScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      // Don't pumpAndSettle — the stream never emits, so it stays loading.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
