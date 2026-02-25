import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/features/explore/domain/hotel.dart';

/// Full-screen detail view for a hotel.
class HotelDetailScreen extends StatelessWidget {
  /// Creates a [HotelDetailScreen].
  const HotelDetailScreen({required this.hotel, super.key});

  /// The hotel to display.
  final Hotel hotel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(hotel.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header info.
            Row(
              children: [
                Icon(
                  Icons.hotel,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotel.name,
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text(
                        hotel.priceRange,
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
            if (hotel.ridingLocationName.isNotEmpty)
              Wrap(
                children: [
                  Chip(
                    avatar: const Icon(Icons.landscape, size: 16),
                    label: Text(hotel.ridingLocationName),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Description.
            Text(
              hotel.description,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),

            // Biker amenities.
            if (hotel.bikerAmenities.isNotEmpty) ...[
              Text(
                'BIKER AMENITIES',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: hotel.bikerAmenities
                    .map(
                      (amenity) => Chip(
                        avatar: const Icon(Icons.check_circle, size: 16),
                        label: Text(amenity),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // CTA: Plan an overnighter.
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.scout, extra: {
                'overnighter_hotel': hotel,
              }),
              icon: const Icon(Icons.bedtime_outlined),
              label: const Text('Plan an overnighter'),
            ),
          ],
        ),
      ),
    );
  }
}
