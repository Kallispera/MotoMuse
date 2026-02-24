import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/features/garage/application/garage_providers.dart';
import 'package:motomuse/features/garage/domain/bike.dart';

/// Garage screen — lists the user's bikes and provides an entry point to add
/// new ones.
///
/// Empty state is shown when the user has no bikes. Each bike is displayed as
/// a card showing the photo, make, model, and year.
class GarageScreen extends ConsumerWidget {
  /// Creates the garage screen.
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bikesValue = ref.watch(userBikesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO(garage): open settings
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addBike),
        icon: const Icon(Icons.add),
        label: const Text('Add bike'),
      ),
      body: bikesValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load your bikes.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (bikes) => bikes.isEmpty
            ? _EmptyState(theme: theme)
            : _BikeList(bikes: bikes),
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
              Icons.garage_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Your garage is empty.',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Every ride starts with knowing your machine.',
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
// Bike list
// ---------------------------------------------------------------------------

class _BikeList extends StatelessWidget {
  const _BikeList({required this.bikes});

  final List<Bike> bikes;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: bikes.length,
      itemBuilder: (context, index) => _BikeCard(bike: bikes[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// Bike card
// ---------------------------------------------------------------------------

class _BikeCard extends StatelessWidget {
  const _BikeCard({required this.bike});

  final Bike bike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // TODO(garage): navigate to bike detail / edit screen
        },
        child: Row(
          children: [
            _BikeThumb(imageUrl: bike.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bike.year != null
                          ? '${bike.year} ${bike.make}'
                          : bike.make,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bike.model,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bike.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        bike.category!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _BikeThumb extends StatelessWidget {
  const _BikeThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 80,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: Colors.grey.shade200,
          child: const Icon(Icons.two_wheeler, color: Colors.grey),
        ),
      ),
    );
  }
}
