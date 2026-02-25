import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/features/explore/domain/restaurant.dart';

/// Full-screen detail view for a restaurant.
class RestaurantDetailScreen extends StatelessWidget {
  /// Creates a [RestaurantDetailScreen].
  const RestaurantDetailScreen({required this.restaurant, super.key});

  /// The restaurant to display.
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header info.
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text(
                        '${restaurant.cuisineType} · ${restaurant.priceRange}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Riding area chip.
            if (restaurant.ridingLocationName.isNotEmpty)
              Wrap(
                children: [
                  Chip(
                    avatar: const Icon(Icons.landscape, size: 16),
                    label: Text(restaurant.ridingLocationName),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Description.
            Text(
              restaurant.description,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // CTA: Plan a breakfast run.
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.scout, extra: {
                'breakfast_restaurant': restaurant,
              }),
              icon: const Icon(Icons.coffee_outlined),
              label: const Text('Plan a breakfast run'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push(
                AppRoutes.itemMap,
                extra: restaurant,
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('View on map'),
            ),
          ],
        ),
      ),
    );
  }
}
