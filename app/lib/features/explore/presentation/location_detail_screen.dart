import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/features/explore/application/explore_providers.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';

/// Full-screen detail view for a riding location.
///
/// Shows photos, description, tags, and lists of restaurants/hotels in the area.
/// CTA button navigates to Scout with the area pre-selected.
class LocationDetailScreen extends ConsumerWidget {
  /// Creates a [LocationDetailScreen].
  const LocationDetailScreen({required this.location, super.key});

  /// The riding location to display.
  final RidingLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final restaurants =
        ref.watch(restaurantsForLocationProvider(location.id));
    final hotels = ref.watch(hotelsForLocationProvider(location.id));

    return Scaffold(
      appBar: AppBar(title: Text(location.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo carousel.
            if (location.photoUrls.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: location.photoUrls.length,
                  itemBuilder: (context, index) => Image.network(
                    location.photoUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.landscape, size: 64),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags.
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: location.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),

                  // Description.
                  Text(
                    location.description,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),

                  // CTA: Plan a ride here.
                  FilledButton.icon(
                    onPressed: () => _planRideHere(context),
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Plan a ride here'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      AppRoutes.itemMap,
                      extra: location,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on map'),
                  ),
                  const SizedBox(height: 24),

                  // Restaurants in this area.
                  Text(
                    'RESTAURANTS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  restaurants.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return const Text('No restaurants listed yet.');
                      }
                      return Column(
                        children: list
                            .map(
                              (r) => ListTile(
                                leading: const Icon(Icons.restaurant),
                                title: Text(r.name),
                                subtitle: Text(r.description, maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: Text(r.priceRange),
                                onTap: () => context.push(
                                  AppRoutes.restaurantDetail,
                                  extra: r,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),

                  // Hotels in this area.
                  Text(
                    'HOTELS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  hotels.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return const Text('No hotels listed yet.');
                      }
                      return Column(
                        children: list
                            .map(
                              (h) => ListTile(
                                leading: const Icon(Icons.hotel),
                                title: Text(h.name),
                                subtitle: Text(h.description, maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: Text(h.priceRange),
                                onTap: () => context.push(
                                  AppRoutes.hotelDetail,
                                  extra: h,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _planRideHere(BuildContext context) {
    context.go(AppRoutes.scout, extra: {
      'riding_area': location,
    });
  }
}
