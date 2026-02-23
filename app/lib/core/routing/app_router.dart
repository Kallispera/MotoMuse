import 'package:go_router/go_router.dart';
import 'package:motomuse/features/auth/presentation/sign_in_screen.dart';
import 'package:motomuse/features/garage/presentation/garage_screen.dart';
import 'package:motomuse/features/profile/presentation/profile_screen.dart';
import 'package:motomuse/features/scout/presentation/scout_screen.dart';
import 'package:motomuse/shared/widgets/app_shell.dart';

/// Named route paths used throughout the app.
abstract final class AppRoutes {
  /// Sign-in screen path.
  static const String signIn = '/sign-in';

  /// Garage tab path.
  static const String garage = '/garage';

  /// Scout (route builder) tab path.
  static const String scout = '/scout';

  /// Profile tab path.
  static const String profile = '/profile';
}

/// The root [GoRouter] configuration for the app.
final appRouter = GoRouter(
  initialLocation: AppRoutes.signIn,
  routes: [
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => const SignInScreen(),
    ),
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
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ScoutScreen(),
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
