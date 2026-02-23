import 'package:flutter/material.dart';

/// Garage screen — shows the user's bikes.
/// Placeholder: empty state only. Populated in Phase 2.
class GarageScreen extends StatelessWidget {
  /// Creates the garage screen.
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      body: Center(
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
              const SizedBox(height: 32),
              ElevatedButton.icon(
                // TODO(garage): navigate to add bike flow
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add your first bike'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
