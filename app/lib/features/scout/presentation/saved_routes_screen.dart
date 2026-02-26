import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/features/scout/application/scout_providers.dart';
import 'package:motomuse/features/scout/domain/saved_route.dart';

/// Lists all saved routes for the signed-in user.
///
/// Tapping a card opens the route in the route preview screen. Swiping a card
/// shows a delete confirmation.
class SavedRoutesScreen extends ConsumerWidget {
  /// Creates the saved routes screen.
  const SavedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedRoutesValue = ref.watch(userSavedRoutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved routes')),
      body: savedRoutesValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load your saved routes.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (routes) {
          if (routes.isEmpty) return _EmptyState(theme: theme);
          return _SavedRouteList(routes: routes);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_outline,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No saved routes yet.',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Generate a route and tap the bookmark\nto save it for later.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route list
// ---------------------------------------------------------------------------

class _SavedRouteList extends StatelessWidget {
  const _SavedRouteList({required this.routes});

  final List<SavedRoute> routes;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: routes.length,
      itemBuilder: (context, index) => _SavedRouteCard(route: routes[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// Route card
// ---------------------------------------------------------------------------

class _SavedRouteCard extends ConsumerWidget {
  const _SavedRouteCard({required this.route});

  final SavedRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(route.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        ref.read(deleteSavedRouteNotifierProvider.notifier).delete(route.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            AppRoutes.routePreview,
            extra: <String, dynamic>{
              'route': route.route,
              'preferences': route.preferences,
              'savedRouteId': route.id,
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_iconForRouteType(route.route.routeType), size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    final km = route.route.distanceKm.round();
    final min = route.route.durationMin;
    final duration = min < 60 ? '${min}min' : '${min ~/ 60}h ${min % 60}min';
    final type = _labelForRouteType(route.route.routeType);
    return '$type · $km km · $duration';
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete route?'),
        content: Text('Remove "${route.name}" from your saved routes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static IconData _iconForRouteType(String routeType) {
    switch (routeType) {
      case 'breakfast_run':
        return Icons.coffee_outlined;
      case 'overnighter':
        return Icons.bedtime_outlined;
      default:
        return Icons.two_wheeler_outlined;
    }
  }

  static String _labelForRouteType(String routeType) {
    switch (routeType) {
      case 'breakfast_run':
        return 'Breakfast run';
      case 'overnighter':
        return 'Overnighter';
      default:
        return 'Day out';
    }
  }
}
