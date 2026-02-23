import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';

/// Persistent shell widget that wraps all tab screens.
///
/// Renders the bottom navigation bar and delegates tab switching via
/// [GoRouter]. Each tab maintains its own navigation stack.
class AppShell extends StatelessWidget {
  /// Creates the app shell with the given [child] tab content.
  const AppShell({required this.child, super.key});

  /// The currently active tab's widget tree.
  final Widget child;

  static const _tabs = [
    _TabItem(
      label: 'Garage',
      icon: Icons.garage_outlined,
      activeIcon: Icons.garage,
      route: AppRoutes.garage,
    ),
    _TabItem(
      label: 'Scout',
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      route: AppRoutes.scout,
    ),
    _TabItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      route: AppRoutes.profile,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.scout)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;
    return 0; // garage is default
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index].route),
        items: _tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                activeIcon: Icon(tab.activeIcon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
