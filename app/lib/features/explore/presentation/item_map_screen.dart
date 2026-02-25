import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/features/explore/domain/hotel.dart';
import 'package:motomuse/features/explore/domain/restaurant.dart';
import 'package:motomuse/features/explore/domain/riding_location.dart';

/// Displays a riding location, restaurant, or hotel on a Google Map.
///
/// Riding locations render a polygon outline of the area boundary.
/// Restaurants and hotels render a single point marker.
class ItemMapScreen extends StatefulWidget {
  /// Show a riding location with polygon boundary on the map.
  const ItemMapScreen.location({required RidingLocation location, super.key})
      : _location = location,
        _restaurant = null,
        _hotel = null;

  /// Show a restaurant as a point marker on the map.
  const ItemMapScreen.restaurant({required Restaurant restaurant, super.key})
      : _location = null,
        _restaurant = restaurant,
        _hotel = null;

  /// Show a hotel as a point marker on the map.
  const ItemMapScreen.hotel({required Hotel hotel, super.key})
      : _location = null,
        _restaurant = null,
        _hotel = hotel;

  final RidingLocation? _location;
  final Restaurant? _restaurant;
  final Hotel? _hotel;

  @override
  State<ItemMapScreen> createState() => _ItemMapScreenState();
}

class _ItemMapScreenState extends State<ItemMapScreen> {
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

    final title = widget._location?.name ??
        widget._restaurant?.name ??
        widget._hotel?.name ??
        'Map';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          // Map — takes ~60% of the screen.
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 10,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                final bounds = _cameraBounds;
                if (bounds != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 48),
                  );
                }
              },
              polygons: _buildPolygons(accentColor),
              markers: _buildMarkers(accentColor),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // Info card below the map.
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildInfoCard(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Map overlays
  // ---------------------------------------------------------------------------

  LatLng get _center {
    if (widget._location != null) return widget._location!.center;
    if (widget._restaurant != null) return widget._restaurant!.location;
    return widget._hotel!.location;
  }

  LatLngBounds? get _cameraBounds {
    if (widget._location != null) {
      final points = widget._location!.polygonPoints.isNotEmpty
          ? widget._location!.polygonPoints
          : [widget._location!.boundsNe, widget._location!.boundsSw];
      return _boundsFromPoints(points);
    }
    // For point markers, let the initial zoom handle it.
    return null;
  }

  Set<Polygon> _buildPolygons(Color accentColor) {
    if (widget._location == null) return {};

    final loc = widget._location!;
    final points = loc.polygonPoints.isNotEmpty
        ? loc.polygonPoints
        : [
            LatLng(loc.boundsNe.latitude, loc.boundsSw.longitude),
            loc.boundsNe,
            LatLng(loc.boundsSw.latitude, loc.boundsNe.longitude),
            loc.boundsSw,
          ];

    return {
      Polygon(
        polygonId: const PolygonId('region'),
        points: points,
        strokeColor: accentColor,
        strokeWidth: 3,
        fillColor: accentColor.withValues(alpha: 0.15),
      ),
    };
  }

  Set<Marker> _buildMarkers(Color accentColor) {
    if (widget._restaurant != null) {
      return {
        Marker(
          markerId: const MarkerId('restaurant'),
          position: widget._restaurant!.location,
          infoWindow: InfoWindow(title: widget._restaurant!.name),
        ),
      };
    }
    if (widget._hotel != null) {
      return {
        Marker(
          markerId: const MarkerId('hotel'),
          position: widget._hotel!.location,
          infoWindow: InfoWindow(title: widget._hotel!.name),
        ),
      };
    }
    return {};
  }

  // ---------------------------------------------------------------------------
  // Info card content
  // ---------------------------------------------------------------------------

  List<Widget> _buildInfoCard(ThemeData theme) {
    if (widget._location != null) return _locationCard(theme);
    if (widget._restaurant != null) return _restaurantCard(theme);
    return _hotelCard(theme);
  }

  List<Widget> _locationCard(ThemeData theme) {
    final loc = widget._location!;
    return [
      Text(loc.name, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      if (loc.tags.isNotEmpty) ...[
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: loc.tags
              .map((tag) => Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
      ],
      Text(
        loc.description,
        style: theme.textTheme.bodyMedium,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    ];
  }

  List<Widget> _restaurantCard(ThemeData theme) {
    final r = widget._restaurant!;
    return [
      Text(r.name, style: theme.textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        '${r.cuisineType} · ${r.priceRange}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (r.ridingLocationName.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(children: [
          Chip(
            avatar: const Icon(Icons.landscape, size: 16),
            label: Text(r.ridingLocationName),
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ],
      const SizedBox(height: 8),
      Text(
        r.description,
        style: theme.textTheme.bodyMedium,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    ];
  }

  List<Widget> _hotelCard(ThemeData theme) {
    final h = widget._hotel!;
    return [
      Text(h.name, style: theme.textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        h.priceRange,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (h.ridingLocationName.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(children: [
          Chip(
            avatar: const Icon(Icons.landscape, size: 16),
            label: Text(h.ridingLocationName),
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ],
      if (h.bikerAmenities.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: h.bikerAmenities
              .map((a) => Chip(
                    avatar: const Icon(Icons.check_circle, size: 16),
                    label: Text(a),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        h.description,
        style: theme.textTheme.bodyMedium,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
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
