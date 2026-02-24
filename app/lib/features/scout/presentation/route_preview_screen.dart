import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';

/// Displays a generated motorcycle route on a map with narrative and imagery.
///
/// Shows:
/// - A Google Map occupying the top 40% of the screen, with the route polyline
/// - Distance and estimated duration
/// - Horizontal scrollable Street View images at scenic waypoints
/// - LLM-generated route narrative
/// - A "Start riding" placeholder button (navigation deferred to Phase 4)
class RoutePreviewScreen extends StatefulWidget {
  /// Creates the route preview screen.
  const RoutePreviewScreen({required this.route, super.key});

  /// The generated route to display.
  final GeneratedRoute route;

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
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
    final accentColor = isDark ? AppColors.gold : AppColors.amber;

    final polylinePoints = _decodePolyline(widget.route.encodedPolyline);
    final bounds = _boundsFromPoints(
      polylinePoints.isNotEmpty ? polylinePoints : widget.route.waypoints,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Your route')),
      body: Column(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
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
                  polylineId: const PolylineId('route'),
                  points: polylinePoints.isNotEmpty
                      ? polylinePoints
                      : widget.route.waypoints,
                  color: accentColor,
                  width: 4,
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // ── Scrollable detail card ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stats row
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.route.distanceKm.round()} km',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('·', style: theme.textTheme.titleMedium),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(widget.route.durationMin),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  // Street View images
                  if (widget.route.streetViewUrls.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.route.streetViewUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              widget.route.streetViewUrls[i],
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

                  // Narrative
                  if (widget.route.narrative.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      widget.route.narrative,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Start riding (placeholder — navigation in Phase 4)
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Turn-by-turn navigation coming soon.'),
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Decodes a Google-encoded polyline string to a list of [LatLng] points.
  ///
  /// Implements the standard Google polyline encoding algorithm.
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
