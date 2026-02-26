import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:motomuse/features/scout/domain/generated_route.dart';
import 'package:motomuse/features/scout/domain/route_exception.dart';
import 'package:motomuse/features/scout/domain/route_preferences.dart';
import 'package:motomuse/features/scout/domain/saved_route.dart';
import 'package:motomuse/features/scout/domain/saved_route_repository.dart';

/// Firestore implementation of [SavedRouteRepository].
///
/// Saved routes are stored under `users/{uid}/savedRoutes/{routeId}`.
///
/// Depends on [FirebaseFirestore] being injected so it can be replaced with
/// a fake Firestore instance in tests.
class FirestoreSavedRouteRepository implements SavedRouteRepository {
  /// Creates a [FirestoreSavedRouteRepository].
  const FirestoreSavedRouteRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SavedRoute>> watchSavedRoutes(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('savedRoutes')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_fromDocument).toList(),
        );
  }

  @override
  Future<void> addSavedRoute(String uid, SavedRoute savedRoute) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('savedRoutes')
          .doc(); // Firestore auto-generates the document ID.
      await docRef.set(_toFirestoreData(savedRoute.copyWith(id: docRef.id)));
    } on FirebaseException catch (e) {
      throw RouteException(
        'Failed to save your route: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Future<void> deleteSavedRoute(String uid, String routeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('savedRoutes')
          .doc(routeId)
          .delete();
    } on FirebaseException catch (e) {
      throw RouteException(
        'Failed to delete your route: ${e.message ?? e.code}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  SavedRoute _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final routeData = data['route'] as Map<String, dynamic>? ?? {};
    final prefsData = data['preferences'] as Map<String, dynamic>? ?? {};

    return SavedRoute(
      id: doc.id,
      name: data['name'] as String? ?? '',
      route: _routeFromMap(routeData),
      preferences: _preferencesFromMap(prefsData),
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _toFirestoreData(SavedRoute savedRoute) {
    return <String, dynamic>{
      'id': savedRoute.id,
      'name': savedRoute.name,
      'route': _routeToMap(savedRoute.route),
      'preferences': _preferencesToMap(savedRoute.preferences),
      'savedAt': FieldValue.serverTimestamp(),
    };
  }

  // -- GeneratedRoute serialisation ------------------------------------------

  Map<String, dynamic> _routeToMap(GeneratedRoute route) {
    return <String, dynamic>{
      'encodedPolyline': route.encodedPolyline,
      'distanceKm': route.distanceKm,
      'durationMin': route.durationMin,
      'narrative': route.narrative,
      'streetViewUrls': route.streetViewUrls,
      'waypoints': route.waypoints
          .map((w) => {'lat': w.latitude, 'lng': w.longitude})
          .toList(),
      'routeType': route.routeType,
      if (route.destinationName != null)
        'destinationName': route.destinationName,
      if (route.returnPolyline != null)
        'returnPolyline': route.returnPolyline,
      if (route.returnDistanceKm != null)
        'returnDistanceKm': route.returnDistanceKm,
      if (route.returnDurationMin != null)
        'returnDurationMin': route.returnDurationMin,
      if (route.returnWaypoints != null)
        'returnWaypoints': route.returnWaypoints!
            .map((w) => {'lat': w.latitude, 'lng': w.longitude})
            .toList(),
      if (route.returnStreetViewUrls != null)
        'returnStreetViewUrls': route.returnStreetViewUrls,
    };
  }

  GeneratedRoute _routeFromMap(Map<String, dynamic> m) {
    return GeneratedRoute(
      encodedPolyline: m['encodedPolyline'] as String? ?? '',
      distanceKm: (m['distanceKm'] as num?)?.toDouble() ?? 0,
      durationMin: (m['durationMin'] as num?)?.toInt() ?? 0,
      narrative: m['narrative'] as String? ?? '',
      streetViewUrls:
          (m['streetViewUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
      waypoints: _parseWaypoints(m['waypoints']),
      routeType: m['routeType'] as String? ?? 'day_out',
      destinationName: m['destinationName'] as String?,
      returnPolyline: m['returnPolyline'] as String?,
      returnDistanceKm: (m['returnDistanceKm'] as num?)?.toDouble(),
      returnDurationMin: (m['returnDurationMin'] as num?)?.toInt(),
      returnWaypoints: m['returnWaypoints'] != null
          ? _parseWaypoints(m['returnWaypoints'])
          : null,
      returnStreetViewUrls:
          (m['returnStreetViewUrls'] as List<dynamic>?)?.cast<String>(),
    );
  }

  // -- RoutePreferences serialisation ----------------------------------------

  Map<String, dynamic> _preferencesToMap(RoutePreferences prefs) {
    return <String, dynamic>{
      'startLocation': prefs.startLocation,
      'distanceKm': prefs.distanceKm,
      'curviness': prefs.curviness,
      'sceneryType': prefs.sceneryType,
      'loop': prefs.loop,
      'lunchStop': prefs.lunchStop,
      'routeType': prefs.routeType,
      if (prefs.destinationLat != null) 'destinationLat': prefs.destinationLat,
      if (prefs.destinationLng != null) 'destinationLng': prefs.destinationLng,
      if (prefs.destinationName != null)
        'destinationName': prefs.destinationName,
      if (prefs.ridingAreaLat != null) 'ridingAreaLat': prefs.ridingAreaLat,
      if (prefs.ridingAreaLng != null) 'ridingAreaLng': prefs.ridingAreaLng,
      if (prefs.ridingAreaRadiusKm != null)
        'ridingAreaRadiusKm': prefs.ridingAreaRadiusKm,
      if (prefs.ridingAreaName != null) 'ridingAreaName': prefs.ridingAreaName,
    };
  }

  RoutePreferences _preferencesFromMap(Map<String, dynamic> m) {
    return RoutePreferences(
      startLocation: m['startLocation'] as String? ?? '',
      distanceKm: (m['distanceKm'] as num?)?.toInt() ?? 150,
      curviness: (m['curviness'] as num?)?.toInt() ?? 3,
      sceneryType: m['sceneryType'] as String? ?? 'mixed',
      loop: m['loop'] as bool? ?? true,
      lunchStop: m['lunchStop'] as bool? ?? false,
      routeType: m['routeType'] as String? ?? 'day_out',
      destinationLat: (m['destinationLat'] as num?)?.toDouble(),
      destinationLng: (m['destinationLng'] as num?)?.toDouble(),
      destinationName: m['destinationName'] as String?,
      ridingAreaLat: (m['ridingAreaLat'] as num?)?.toDouble(),
      ridingAreaLng: (m['ridingAreaLng'] as num?)?.toDouble(),
      ridingAreaRadiusKm: (m['ridingAreaRadiusKm'] as num?)?.toDouble(),
      ridingAreaName: m['ridingAreaName'] as String?,
    );
  }

  // -- Shared helpers --------------------------------------------------------

  List<LatLng> _parseWaypoints(dynamic waypointsJson) {
    if (waypointsJson is! List) return [];
    return waypointsJson
        .cast<Map<String, dynamic>>()
        .map(
          (w) => LatLng(
            (w['lat'] as num).toDouble(),
            (w['lng'] as num).toDouble(),
          ),
        )
        .toList();
  }
}
