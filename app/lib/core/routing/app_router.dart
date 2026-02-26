import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/presentation/sign_in_screen.dart';
import 'package:motomuse/features/explore/domain/hotel.dart';
import 'package:motomuse/features/explore/domain/restaurant.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';
import 'package:motomuse/features/explore/presentation/explore_screen.dart';
import 'package:motomuse/features/explore/presentation/hotel_detail_screen.dart';
import 'package:motomuse/features/explore/presentation/item_map_screen.dart';
import 'package:motomuse/features/explore/presentation/location_detail_screen.dart';
import 'package:motomuse/features/explore/presentation/restaurant_detail_screen.dart';
import 'package:motomuse/features/garage/domain/bike_photo_analysis.dart';
import 'package:motomuse/features/garage/presentation/add_bike_screen.dart';
import 'package:motomuse/features/garage/presentation/bike_review_screen.dart';
import 'package:motomuse/features/garage/presentation/garage_screen.dart';
import 'package:motomuse/features/onboarding/presentation/home_address_screen.dart';
import 'package:motomuse/features/profile/presentation/profile_screen.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';
import 'package:motomuse/features/scout/presentation/route_preview_screen.dart';
import 'package:motomuse/features/scout/presentation/saved_routes_screen.dart';
import 'package:motomuse/features/scout/presentation/scout_screen.dart';
import 'package:motomuse/shared/widgets/app_shell.dart';

/// Named route paths used throughout the app.
abstract final class AppRoutes {
  /// Sign-in screen path.
  static const String signIn = '/sign-in';

  /// Garage tab path.
  static const String garage = '/garage';

  /// Add-bike flow path (full screen, no bottom nav).
  static const String addBike = '/garage/add';

  /// Bike review path — pass a [BikePhotoAnalysis] via GoRouter `extra`.
  static const String bikeReview = '/garage/review';

  /// Scout (route builder) tab path.
  static const String scout = '/scout';

  /// Explore tab path — browse curated riding content.
  static const String explore = '/explore';

  /// Location detail — pass a [RidingLocation] via GoRouter `extra`.
  static const String locationDetail = '/explore/location';

  /// Restaurant detail — pass a [Restaurant] via GoRouter `extra`.
  static const String restaurantDetail = '/explore/restaurant';

  /// Hotel detail — pass a [Hotel] via GoRouter `extra`.
  static const String hotelDetail = '/explore/hotel';

  /// Map view for any explore item — pass a RidingLocation, Restaurant,
  /// or Hotel via GoRouter `extra`.
  static const String itemMap = '/explore/map';

  /// Home address onboarding screen.
  static const String homeAddress = '/onboarding/home-address';

  /// Profile tab path.
  static const String profile = '/profile';

  /// Route preview path — pass a [GeneratedRoute] via GoRouter `extra`.
  static const String routePreview = '/scout/preview';

  /// Saved routes list path.
  static const String savedRoutes = '/scout/saved';
}

// ---------------------------------------------------------------------------
// Router notifier — bridges Riverpod auth state to GoRouter's refresh
// ---------------------------------------------------------------------------

/// A [ChangeNotifier] that fires whenever the auth state changes.
///
/// Used as `refreshListenable` so the router re-evaluates its
/// `redirect` callback without the [GoRouter] instance being recreated.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
  }
}

final _routerNotifierProvider = ChangeNotifierProvider(_RouterNotifier.new);

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// Provides the app's [GoRouter].
///
/// The router instance is created once and lives for the app's lifetime.
/// Auth-state changes are handled via [_RouterNotifier] and the `redirect`
/// callback — the instance itself is never recreated.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(_routerNotifierProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authValue = ref.read(authStateChangesProvider);

      // Don't redirect while the initial auth check is still in flight.
      if (authValue.isLoading) return null;

      final isLoggedIn = authValue.valueOrNull != null;
      final isOnSignIn = state.matchedLocation == AppRoutes.signIn;

      if (!isLoggedIn && !isOnSignIn) return AppRoutes.signIn;
      if (isLoggedIn && isOnSignIn) return AppRoutes.garage;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      // Full-screen routes — no bottom navigation shell.
      GoRoute(
        path: AppRoutes.addBike,
        builder: (context, state) => const AddBikeScreen(),
      ),
      GoRoute(
        path: AppRoutes.bikeReview,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! BikePhotoAnalysis) return const AddBikeScreen();
          return BikeReviewScreen(analysis: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.routePreview,
        builder: (context, state) {
          final extra = state.extra;
          // Support both a plain GeneratedRoute (legacy) and a map with
          // route + preferences + optional savedRouteId.
          if (extra is GeneratedRoute) {
            return RoutePreviewScreen(route: extra);
          }
          if (extra is Map<String, dynamic>) {
            final route = extra['route'] as GeneratedRoute?;
            if (route != null) {
              return RoutePreviewScreen(
                route: route,
                preferences: extra['preferences'] as RoutePreferences?,
                savedRouteId: extra['savedRouteId'] as String?,
              );
            }
          }
          return const ScoutScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.savedRoutes,
        builder: (context, state) => const SavedRoutesScreen(),
      ),
      // Explore detail routes (full screen, no bottom nav).
      GoRoute(
        path: AppRoutes.locationDetail,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! RidingLocation) return const ExploreScreen();
          return LocationDetailScreen(location: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.restaurantDetail,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Restaurant) return const ExploreScreen();
          return RestaurantDetailScreen(restaurant: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.hotelDetail,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Hotel) return const ExploreScreen();
          return HotelDetailScreen(hotel: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.itemMap,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is RidingLocation) {
            return ItemMapScreen.location(location: extra);
          }
          if (extra is Restaurant) {
            return ItemMapScreen.restaurant(restaurant: extra);
          }
          if (extra is Hotel) {
            return ItemMapScreen.hotel(hotel: extra);
          }
          return const ExploreScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.homeAddress,
        builder: (context, state) => const HomeAddressScreen(),
      ),
      // Shell route — wraps tab screens with the bottom navigation bar.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.garage,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GarageScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.scout,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ScoutScreen(prefill: state.extra as Map<String, dynamic>?),
            ),
          ),
          GoRoute(
            path: AppRoutes.explore,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExploreScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
