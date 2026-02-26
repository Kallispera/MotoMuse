import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/explore/application/explore_providers.dart';
import 'package:motomuse/features/explore/domain/hotel.dart';
import 'package:motomuse/features/explore/domain/restaurant.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';
import 'package:motomuse/features/scout/application/scout_providers.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

/// Scout screen — ride type selector and vibe controls for route generation.
///
/// Supports three ride types:
/// - **Breakfast Run**: Select a restaurant, scenic ride there and back.
/// - **Day Out**: Select a riding area (optional) or freeform circular route.
/// - **Overnighter**: Select a hotel, scenic ride there and back.
class ScoutScreen extends ConsumerStatefulWidget {
  /// Creates the scout screen.
  const ScoutScreen({this.prefill, super.key});

  /// Optional pre-fill data from Explore deep links.
  ///
  /// Keys: `breakfast_restaurant` (Restaurant), `riding_area` (RidingLocation),
  /// `overnighter_hotel` (Hotel).
  final Map<String, dynamic>? prefill;

  @override
  ConsumerState<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends ConsumerState<ScoutScreen> {
  final _startCtrl = TextEditingController();
  bool _locating = false;
  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    _prefillLocation();
  }

  @override
  void didUpdateWidget(ScoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Apply prefill when navigating from Explore with data.
    if (widget.prefill != null && !_prefillApplied) {
      _applyPrefill(widget.prefill!);
      _prefillApplied = true;
    }
  }

  void _applyPrefill(Map<String, dynamic> data) {
    final notifier = ref.read(routePreferencesProvider.notifier);

    if (data.containsKey('breakfast_restaurant')) {
      final r = data['breakfast_restaurant'] as Restaurant;
      notifier.update(
        (p) => p.copyWith(
          routeType: 'breakfast_run',
          destinationLat: () => r.location.latitude,
          destinationLng: () => r.location.longitude,
          destinationName: () => r.name,
        ),
      );
    } else if (data.containsKey('riding_area')) {
      final loc = data['riding_area'] as RidingLocation;
      notifier.update(
        (p) => p.copyWith(
          routeType: 'day_out',
          ridingAreaLat: () => loc.center.latitude,
          ridingAreaLng: () => loc.center.longitude,
          ridingAreaRadiusKm: () => loc.radiusKm,
          ridingAreaName: () => loc.name,
        ),
      );
    } else if (data.containsKey('overnighter_hotel')) {
      final h = data['overnighter_hotel'] as Hotel;
      notifier.update(
        (p) => p.copyWith(
          routeType: 'overnighter',
          destinationLat: () => h.location.latitude,
          destinationLng: () => h.location.longitude,
          destinationName: () => h.name,
        ),
      );
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    super.dispose();
  }

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

    // Apply prefill on first build if not yet applied.
    if (widget.prefill != null && !_prefillApplied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyPrefill(widget.prefill!);
        _prefillApplied = true;
      });
    }

    ref.listen<AsyncValue<GeneratedRoute?>>(
      routeGenerationNotifierProvider,
      (previous, next) {
        if (previous is! AsyncLoading) return;
        next.whenOrNull(
          data: (route) {
            if (route == null) return;
            ref.read(routeGenerationNotifierProvider.notifier).reset();
            context.push(
              AppRoutes.routePreview,
              extra: <String, dynamic>{
                'route': route,
                'preferences': ref.read(routePreferencesProvider),
              },
            );
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
      appBar: AppBar(
        title: const Text('Scout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Saved routes',
            onPressed: () => context.push(AppRoutes.savedRoutes),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ride type selector.
              _SectionLabel(label: 'Ride type', theme: theme),
              const SizedBox(height: 8),
              _RideTypeSelector(
                value: prefs.routeType,
                onChanged: _onRideTypeChanged,
              ),
              const SizedBox(height: 20),

              // Type-specific content.
              if (prefs.routeType == 'breakfast_run')
                _BreakfastRunControls(prefs: prefs)
              else if (prefs.routeType == 'overnighter')
                _OvernighterControls(prefs: prefs)
              else
                _DayOutControls(prefs: prefs),

              const SizedBox(height: 20),

              // Starting location (always shown).
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
              const SizedBox(height: 20),

              // Curviness (always shown).
              _SectionLabel(label: 'Curviness', theme: theme),
              const SizedBox(height: 8),
              _CurvinessSelector(
                value: prefs.curviness,
                onChanged: (v) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(curviness: v)),
              ),
              const SizedBox(height: 20),

              // Scenery (always shown).
              _SectionLabel(label: 'Scenery', theme: theme),
              const SizedBox(height: 8),
              _ScenerySelector(
                value: prefs.sceneryType,
                onChanged: (v) => ref
                    .read(routePreferencesProvider.notifier)
                    .update((p) => p.copyWith(sceneryType: v)),
              ),

              // Distance slider (day_out only).
              if (prefs.routeType == 'day_out') ...[
                const SizedBox(height: 20),
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
                  divisions: 54,
                  onChanged: (v) => ref
                      .read(routePreferencesProvider.notifier)
                      .update((p) => p.copyWith(distanceKm: v.round())),
                ),
              ],

              // Loop toggle (day_out without area only).
              if (prefs.routeType == 'day_out' &&
                  prefs.ridingAreaName == null) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'Route shape', theme: theme),
                const SizedBox(height: 8),
                _RouteTypeToggle(
                  loop: prefs.loop,
                  onLoopChanged: ({required bool loop}) => ref
                      .read(routePreferencesProvider.notifier)
                      .update((p) => p.copyWith(loop: loop)),
                ),
              ],

              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _generate(prefs),
                icon: const Icon(Icons.route_outlined),
                label: Text(_generateButtonLabel(prefs.routeType)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onRideTypeChanged(String type) {
    ref.read(routePreferencesProvider.notifier).update(
          (p) => p.copyWith(
            routeType: type,
            // Clear destination/area when switching types.
            destinationLat: () => null,
            destinationLng: () => null,
            destinationName: () => null,
            ridingAreaLat: () => null,
            ridingAreaLng: () => null,
            ridingAreaRadiusKm: () => null,
            ridingAreaName: () => null,
            loop: type == 'day_out',
          ),
        );
  }

  String _generateButtonLabel(String routeType) {
    switch (routeType) {
      case 'breakfast_run':
        return 'Plan my breakfast run';
      case 'overnighter':
        return 'Plan my overnighter';
      default:
        return 'Generate my route';
    }
  }

  void _generate(RoutePreferences prefs) {
    final location = _startCtrl.text.trim().isNotEmpty
        ? _startCtrl.text.trim()
        : prefs.startLocation.trim();

    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a starting location.')),
      );
      return;
    }

    if (prefs.isThereAndBack && prefs.destinationLat == null) {
      final item =
          prefs.routeType == 'breakfast_run' ? 'restaurant' : 'hotel';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a $item.')),
      );
      return;
    }

    final effective = prefs.copyWith(startLocation: location);
    ref.read(routeGenerationNotifierProvider.notifier).generate(effective);
  }
}

// ---------------------------------------------------------------------------
// Ride type selector
// ---------------------------------------------------------------------------

class _RideTypeSelector extends StatelessWidget {
  const _RideTypeSelector({required this.value, required this.onChanged});

  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'breakfast_run',
          label: Text('Breakfast'),
          icon: Icon(Icons.coffee_outlined, size: 18),
        ),
        ButtonSegment(
          value: 'day_out',
          label: Text('Day Out'),
          icon: Icon(Icons.two_wheeler_outlined, size: 18),
        ),
        ButtonSegment(
          value: 'overnighter',
          label: Text('Overnighter'),
          icon: Icon(Icons.bedtime_outlined, size: 18),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ---------------------------------------------------------------------------
// Breakfast Run controls
// ---------------------------------------------------------------------------

class _BreakfastRunControls extends ConsumerWidget {
  const _BreakfastRunControls({required this.prefs});

  final RoutePreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final restaurantsAsync = ref.watch(restaurantsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Destination restaurant', theme: theme),
        const SizedBox(height: 8),
        if (prefs.destinationName != null)
          _SelectedChip(
            icon: Icons.restaurant,
            label: prefs.destinationName!,
            onClear: () => ref
                .read(routePreferencesProvider.notifier)
                .update(
                  (p) => p.copyWith(
                    destinationLat: () => null,
                    destinationLng: () => null,
                    destinationName: () => null,
                  ),
                ),
          )
        else
          restaurantsAsync.when(
            data: (restaurants) => _DropdownPicker<Restaurant>(
              hint: 'Select a restaurant',
              items: restaurants,
              labelBuilder: (r) => '${r.name} (${r.ridingLocationName})',
              onSelected: (r) => ref
                  .read(routePreferencesProvider.notifier)
                  .update(
                    (p) => p.copyWith(
                      destinationLat: () => r.location.latitude,
                      destinationLng: () => r.location.longitude,
                      destinationName: () => r.name,
                    ),
                  ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load restaurants: $e'),
          ),
        const SizedBox(height: 8),
        Text(
          '1-2 hour scenic ride each way, different roads out and back.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day Out controls
// ---------------------------------------------------------------------------

class _DayOutControls extends ConsumerWidget {
  const _DayOutControls({required this.prefs});

  final RoutePreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locationsAsync = ref.watch(ridingLocationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Riding area (optional)', theme: theme),
        const SizedBox(height: 8),
        if (prefs.ridingAreaName != null)
          _SelectedChip(
            icon: Icons.landscape,
            label: prefs.ridingAreaName!,
            onClear: () => ref
                .read(routePreferencesProvider.notifier)
                .update(
                  (p) => p.copyWith(
                    ridingAreaLat: () => null,
                    ridingAreaLng: () => null,
                    ridingAreaRadiusKm: () => null,
                    ridingAreaName: () => null,
                  ),
                ),
          )
        else
          locationsAsync.when(
            data: (locations) => _DropdownPicker<RidingLocation>(
              hint: 'Any area (freeform route)',
              items: locations,
              labelBuilder: (loc) => loc.name,
              onSelected: (loc) => ref
                  .read(routePreferencesProvider.notifier)
                  .update(
                    (p) => p.copyWith(
                      ridingAreaLat: () => loc.center.latitude,
                      ridingAreaLng: () => loc.center.longitude,
                      ridingAreaRadiusKm: () => loc.radiusKm,
                      ridingAreaName: () => loc.name,
                      loop: true,
                    ),
                  ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load locations: $e'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Overnighter controls
// ---------------------------------------------------------------------------

class _OvernighterControls extends ConsumerWidget {
  const _OvernighterControls({required this.prefs});

  final RoutePreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hotelsAsync = ref.watch(hotelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Destination hotel', theme: theme),
        const SizedBox(height: 8),
        if (prefs.destinationName != null)
          _SelectedChip(
            icon: Icons.hotel,
            label: prefs.destinationName!,
            onClear: () => ref
                .read(routePreferencesProvider.notifier)
                .update(
                  (p) => p.copyWith(
                    destinationLat: () => null,
                    destinationLng: () => null,
                    destinationName: () => null,
                  ),
                ),
          )
        else
          hotelsAsync.when(
            data: (hotels) => _DropdownPicker<Hotel>(
              hint: 'Select a hotel',
              items: hotels,
              labelBuilder: (h) => '${h.name} (${h.ridingLocationName})',
              onSelected: (h) => ref
                  .read(routePreferencesProvider.notifier)
                  .update(
                    (p) => p.copyWith(
                      destinationLat: () => h.location.latitude,
                      destinationLng: () => h.location.longitude,
                      destinationName: () => h.name,
                    ),
                  ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load hotels: $e'),
          ),
        const SizedBox(height: 8),
        Text(
          '4-6 hour scenic ride each way, different roads out and back.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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
// Shared sub-widgets
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

/// A chip showing the currently selected destination/area with a clear button.
class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.icon,
    required this.label,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onDeleted: onClear,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }
}

/// Generic dropdown picker that shows a list of items.
class _DropdownPicker<T> extends StatelessWidget {
  const _DropdownPicker({
    required this.hint,
    required this.items,
    required this.labelBuilder,
    required this.onSelected,
    super.key,
  });

  final String hint;
  final List<T> items;
  final String Function(T) labelBuilder;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelBuilder(item),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}
