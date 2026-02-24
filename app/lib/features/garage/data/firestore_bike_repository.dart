import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:motomuse/features/garage/domain/bike.dart';
import 'package:motomuse/features/garage/domain/bike_exception.dart';
import 'package:motomuse/features/garage/domain/bike_repository.dart';

/// Firestore implementation of [BikeRepository].
///
/// Bikes are stored under `users/{uid}/bikes/{bikeId}`.
///
/// Depends on [FirebaseFirestore] being injected so it can be replaced with
/// a fake Firestore instance in tests.
class FirestoreBikeRepository implements BikeRepository {
  /// Creates a [FirestoreBikeRepository].
  const FirestoreBikeRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Bike>> watchBikes(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('bikes')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(_fromDocument)
              .toList(),
        );
  }

  @override
  Future<void> addBike(String uid, Bike bike) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('bikes')
          .doc(); // Firestore auto-generates the document ID.
      await docRef.set(_toFirestoreData(bike.copyWith(id: docRef.id)));
    } on FirebaseException catch (e) {
      throw BikeException(
        'Failed to save your bike: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Future<void> deleteBike(String uid, String bikeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bikes')
          .doc(bikeId)
          .delete();
    } on FirebaseException catch (e) {
      throw BikeException(
        'Failed to remove your bike: ${e.message ?? e.code}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Bike _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Bike(
      id: doc.id,
      make: data['make'] as String? ?? '',
      model: data['model'] as String? ?? '',
      year: (data['year'] as num?)?.toInt(),
      displacement: data['displacement'] as String?,
      color: data['color'] as String?,
      trim: data['trim'] as String?,
      modifications: (data['modifications'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      category: data['category'] as String?,
      affirmingMessage: data['affirmingMessage'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _toFirestoreData(Bike bike) {
    return <String, dynamic>{
      'id': bike.id,
      'make': bike.make,
      'model': bike.model,
      if (bike.year != null) 'year': bike.year,
      if (bike.displacement != null) 'displacement': bike.displacement,
      if (bike.color != null) 'color': bike.color,
      if (bike.trim != null) 'trim': bike.trim,
      'modifications': bike.modifications,
      if (bike.category != null) 'category': bike.category,
      'affirmingMessage': bike.affirmingMessage,
      'imageUrl': bike.imageUrl,
      'addedAt': FieldValue.serverTimestamp(),
    };
  }
}
