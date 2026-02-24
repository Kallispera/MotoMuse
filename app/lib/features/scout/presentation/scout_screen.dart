import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/scout/application/scout_providers.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

/// Scout screen — vibe controls for motorcycle route generation.
///
/// The user sets distance, curviness, scenery type, loop preference, and
/// optionally a lunch stop, then taps "Generate my route." While the backend
/// is working, a full-screen loading state is shown. On success the app
/// navigates to the route preview screen.
class ScoutScreen extends ConsumerStatefulWidget {
  /// Creates the scout screen.
  const ScoutScreen({super.key});

  @override
  ConsumerState<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends ConsumerState<ScoutScreen> {
  final _startCtrl = TextEditingController();
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _prefillLocation();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    super.dispose();
  }

  /// Attempts to resolve the device location and populate the start field with
  /// a `lat,lng` string. Silently falls back to an empty field so the user can
  /// type an address manually.
  Future<void> _prefillLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final lat = pos.latitude.toStringAsFixed(5);
      final lng = pos.longitude.toStringAsFixed(5);
      final latLng = '$lat,$lng';
      if (mounted) {
        _startCtrl.text = latLng;
        ref
            .read(routePreferencesProvider.notifier)
            .update((p) => p.copyWith(startLocation: latLng));
      }
    } on Exception catch (_) {
      // Ignore — user can type address manually.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(routePreferencesProvider);
    final genState = ref.watch(routeGenerationNotifierProvider);
    final isGenerating = genState.isLoading;

    // Navigate to preview on success; show error snackbar on failure.
    ref.listen<AsyncValue<GeneratedRoute?>>(
      routeGenerationNotifierProvider,
      (previous, next) {
        if (previous is! AsyncLoading) return;
        next.whenOrNull(
          data: (route) {
            if (route == null) return;
            ref.read(routeGenerationNotifierProvider.notifier).reset();
            context.push(AppRoutes.routePreview, extra: route);
          },
          error: (e, _) {
            final msg = e is RouteException
                ? e.message
                : 'Could not generate a route. Please try again.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          },
        );
      },
    );

    if (isGenerating) return const _GeneratingState();

    return Scaffold(
      appBar: AppBar(title: const Text('Scout')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(label: 'Starting from', theme: theme),
              const SizedBox(height: 8),
              TextField(
                controller: _startCtrl,
                decoration: InputDecoration(
                  hintText: _locating
                      ? 'Getting your location…'
                      : 'Address or leave blank for current location',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(startLocation: v)),
              ),
              const SizedBox(height: 28),
              _SectionLabel(label: 'Distance', theme: theme),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('30 km', style: theme.textTheme.bodySmall),
                  Text(
                    '${prefs.distanceKm} km',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text('300 km', style: theme.textTheme.bodySmall),
                ],
              ),
              Slider(
                value: prefs.distanceKm.toDouble(),
                min: 30,
                max: 300,
                divisions: 54, // 5 km steps
                onChanged: (v) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(distanceKm: v.round())),
              ),
              const SizedBox(height: 24),
              _SectionLabel(label: 'Curviness', theme: theme),
              const SizedBox(height: 8),
              _CurvinessSelector(
                value: prefs.curviness,
                onChanged: (v) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(curviness: v)),
              ),
              const SizedBox(height: 24),
              _SectionLabel(label: 'Scenery', theme: theme),
              const SizedBox(height: 8),
              _ScenerySelector(
                value: prefs.sceneryType,
                onChanged: (v) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(sceneryType: v)),
              ),
              const SizedBox(height: 24),
              _SectionLabel(label: 'Route type', theme: theme),
              const SizedBox(height: 8),
              _RouteTypeToggle(
                loop: prefs.loop,
                onLoopChanged: ({required bool loop}) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(loop: loop)),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: prefs.lunchStop,
                onChanged: (v) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(lunchStop: v)),
                title: const Text('Add a lunch stop'),
                subtitle:
                    const Text('Include a restaurant at the halfway point'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _generate(prefs),
                icon: const Icon(Icons.route_outlined),
                label: const Text('Generate my route'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generate(RoutePreferences prefs) {
    final location = _startCtrl.text.trim().isNotEmpty
        ? _startCtrl.text.trim()
        : prefs.startLocation.trim();

    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a starting location.'),
        ),
      );
      return;
    }

    final effective = prefs.copyWith(startLocation: location);
    ref.read(routeGenerationNotifierProvider.notifier).generate(effective);
  }
}

// ---------------------------------------------------------------------------
// Generating state (full-screen loading)
// ---------------------------------------------------------------------------

class _GeneratingState extends StatelessWidget {
  const _GeneratingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? AppColors.gold : AppColors.amber;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.route_outlined, size: 64, color: color),
              const SizedBox(height: 24),
              Text(
                'Planning your ride…',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Scouting roads, scoring curves, and\n'
                'handpicking scenic waypoints.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CircularProgressIndicator(color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CurvinessSelector extends StatelessWidget {
  const _CurvinessSelector({required this.value, required this.onChanged});

  final int value;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.gold : AppColors.amber;

    return Row(
      children: List.generate(5, (i) {
        final star = i + 1;
        return GestureDetector(
          onTap: () => onChanged(star),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 32,
              color:
                  star <= value ? activeColor : theme.colorScheme.outline,
            ),
          ),
        );
      }),
    );
  }
}

class _ScenerySelector extends StatelessWidget {
  const _ScenerySelector({required this.value, required this.onChanged});

  final String value;
  final void Function(String) onChanged;

  static const _options = [
    ('forests', Icons.forest_outlined, 'Forests'),
    ('coastline', Icons.water_outlined, 'Coast'),
    ('mountains', Icons.terrain_outlined, 'Mountains'),
    ('mixed', Icons.landscape_outlined, 'Mixed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((opt) {
        final (key, icon, label) = opt;
        final selected = value == key;
        return FilterChip(
          avatar: Icon(icon, size: 16),
          label: Text(label),
          selected: selected,
          onSelected: (_) => onChanged(key),
        );
      }).toList(),
    );
  }
}

class _RouteTypeToggle extends StatelessWidget {
  const _RouteTypeToggle({required this.loop, required this.onLoopChanged});

  final bool loop;
  final void Function({required bool loop}) onLoopChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: true,
          label: Text('Loop'),
          icon: Icon(Icons.loop_outlined, size: 18),
        ),
        ButtonSegment(
          value: false,
          label: Text('One-way'),
          icon: Icon(Icons.arrow_forward_outlined, size: 18),
        ),
      ],
      selected: {loop},
      onSelectionChanged: (s) => onLoopChanged(loop: s.first),
    );
  }
}
