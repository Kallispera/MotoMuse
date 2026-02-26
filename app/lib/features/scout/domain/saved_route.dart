import 'package:flutter/foundation.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';

/// A generated route that the user has saved for later reference.
///
/// Wraps a [GeneratedRoute] and the [RoutePreferences] that produced it,
/// together with user-provided metadata (name, timestamp).
@immutable
class SavedRoute {
  /// Creates a [SavedRoute].
  const SavedRoute({
    required this.id,
    required this.name,
    required this.route,
    required this.preferences,
    required this.savedAt,
  });

  /// Firestore document ID. Empty string before the route is persisted.
  final String id;

  /// User-provided name for this saved route.
  final String name;

  /// The generated route data (polylines, narrative, street view, etc.).
  final GeneratedRoute route;

  /// The preferences that were used to generate this route.
  final RoutePreferences preferences;

  /// When this route was saved.
  final DateTime savedAt;

  /// Returns a copy of this [SavedRoute] with the specified fields replaced.
  SavedRoute copyWith({
    String? id,
    String? name,
    GeneratedRoute? route,
    RoutePreferences? preferences,
    DateTime? savedAt,
  }) {
    return SavedRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      route: route ?? this.route,
      preferences: preferences ?? this.preferences,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedRoute &&
        other.id == id &&
        other.name == name &&
        other.route == route &&
        other.preferences == preferences &&
        other.savedAt == savedAt;
  }

  @override
  int get hashCode => Object.hash(id, name, route, preferences, savedAt);

  @override
  String toString() => 'SavedRoute(id: $id, name: $name)';
}
