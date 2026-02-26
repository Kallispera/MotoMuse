import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/scout/application/scout_providers.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';
import 'package:motomuse/features/scout/domain/saved_route.dart';

/// Displays a generated motorcycle route on a map with narrative and imagery.
///
/// Supports both single-leg (day out) and two-leg (breakfast run /
/// overnighter) routes. Two-leg routes show outbound and return polylines
/// in different colors.
class RoutePreviewScreen extends ConsumerStatefulWidget {
  /// Creates the route preview screen.
  const RoutePreviewScreen({
    required this.route,
    this.preferences,
    this.savedRouteId,
    super.key,
  });

  /// The generated route to display.
  final GeneratedRoute route;

  /// The preferences used to generate this route. Required for saving.
  final RoutePreferences? preferences;

  /// Non-null when viewing an already-saved route (hides the save button).
  final String? savedRouteId;

  @override
  ConsumerState<RoutePreviewScreen> createState() =>
      _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends ConsumerState<RoutePreviewScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final outboundColor = isDark ? AppColors.gold : AppColors.amber;
    const returnColor = Colors.blueGrey;

    final outboundPoints = _decodePolyline(widget.route.encodedPolyline);
    final returnPoints = widget.route.returnPolyline != null
        ? _decodePolyline(widget.route.returnPolyline!)
        : <LatLng>[];

    final allPoints = [...outboundPoints, ...returnPoints];
    final bounds = _boundsFromPoints(
      allPoints.isNotEmpty ? allPoints : widget.route.waypoints,
    );

    // Combine Street View URLs from both legs.
    final allStreetViewUrls = [
      ...widget.route.streetViewUrls,
      ...?widget.route.returnStreetViewUrls,
    ];

    final title = _routeTitle;

    final canSave =
        widget.preferences != null && widget.savedRouteId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (canSave)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Save route',
              onPressed: () => _showSaveDialog(context),
            ),
          if (widget.savedRouteId != null)
            const IconButton(
              icon: Icon(Icons.bookmark),
              tooltip: 'Already saved',
              onPressed: null,
            ),
        ],
      ),
      body: Column(
        children: [
          // -- Map ----------------------------------------------------------
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: bounds.center,
                zoom: 10,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (bounds.isValid) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 48),
                  );
                }
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId('outbound'),
                  points: outboundPoints.isNotEmpty
                      ? outboundPoints
                      : widget.route.waypoints,
                  color: outboundColor,
                  width: 4,
                ),
                if (returnPoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('return'),
                    points: returnPoints,
                    color: returnColor,
                    width: 4,
                    patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                  ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // -- Scrollable detail card ---------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Destination name for there-and-back routes.
                  if (widget.route.destinationName != null) ...[
                    Text(
                      _destinationLabel,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Stats — outbound leg.
                  _StatsRow(
                    label: widget.route.isThereAndBack ? 'Outbound' : null,
                    distanceKm: widget.route.distanceKm,
                    durationMin: widget.route.durationMin,
                    color: outboundColor,
                  ),

                  // Stats — return leg (there-and-back only).
                  if (widget.route.isThereAndBack &&
                      widget.route.returnDistanceKm != null) ...[
                    const SizedBox(height: 6),
                    _StatsRow(
                      label: 'Return',
                      distanceKm: widget.route.returnDistanceKm!,
                      durationMin: widget.route.returnDurationMin ?? 0,
                      color: returnColor,
                    ),
                  ],

                  // Street View images (combined from both legs).
                  if (allStreetViewUrls.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: allStreetViewUrls.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              allStreetViewUrls[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.landscape_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Narrative.
                  if (widget.route.narrative.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      widget.route.narrative,
                      style:
                          theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],

                  // Legend for two-leg routes.
                  if (widget.route.isThereAndBack) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 3,
                          color: outboundColor,
                        ),
                        const SizedBox(width: 6),
                        Text('Outbound',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(width: 16),
                        Container(
                          width: 24,
                          height: 3,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: returnColor,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Return',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Start riding (placeholder — navigation in Phase 4).
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Turn-by-turn navigation coming soon.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Start riding'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _routeTitle {
    switch (widget.route.routeType) {
      case 'breakfast_run':
        return 'Breakfast run';
      case 'overnighter':
        return 'Overnighter';
      default:
        return 'Your route';
    }
  }

  String get _destinationLabel {
    final name = widget.route.destinationName ?? '';
    switch (widget.route.routeType) {
      case 'breakfast_run':
        return 'Breakfast at $name';
      case 'overnighter':
        return 'Staying at $name';
      default:
        return name;
    }
  }

  Future<void> _showSaveDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save route'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Give this route a name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.isEmpty) return;

    final savedRoute = SavedRoute(
      id: '',
      name: name,
      route: widget.route,
      preferences: widget.preferences!,
      savedAt: DateTime.now(),
    );
    await ref.read(saveRouteNotifierProvider.notifier).save(savedRoute);
    messenger.showSnackBar(
      const SnackBar(content: Text('Route saved!')),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var b = 0;
      var shift = 0;
      var result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);
      lat += dlat;

      shift = 0;
      result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);
      lng += dlng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(-0.1, -0.1),
        northeast: const LatLng(0.1, 0.1),
      );
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.distanceKm,
    required this.durationMin,
    required this.color,
    this.label,
  });

  final String? label;
  final double distanceKm;
  final int durationMin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
          const SizedBox(width: 8),
        ],
        Icon(Icons.two_wheeler, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          '${distanceKm.round()} km',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text('·', style: theme.textTheme.titleMedium),
        const SizedBox(width: 4),
        Text(
          _formatDuration(durationMin),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}

extension _LatLngBoundsCenter on LatLngBounds {
  bool get isValid =>
      northeast.latitude != southwest.latitude ||
      northeast.longitude != southwest.longitude;

  LatLng get center => LatLng(
        (northeast.latitude + southwest.latitude) / 2,
        (northeast.longitude + southwest.longitude) / 2,
      );
}
