import 'package:flutter/foundation.dart';

/// Represents a motorcycle stored in the user's garage.
///
/// This is an immutable domain-layer value object. All Firebase and HTTP
/// types are kept out of this class; serialisation lives in the data layer.
@immutable
class Bike {
  /// Creates a [Bike] with the given fields.
  const Bike({
    required this.id,
    required this.make,
    required this.model,
    required this.affirmingMessage,
    required this.imageUrl,
    required this.addedAt,
    this.personalityLine = '',
    this.year,
    this.displacement,
    this.color,
    this.trim,
    this.modifications = const [],
    this.category,
  });

  /// The unique Firestore document ID. Empty string before the bike is saved.
  final String id;

  /// Manufacturer name (e.g. "Ducati", "Honda", "BMW").
  final String make;

  /// Model name (e.g. "Panigale V4 S", "CBR600RR").
  final String model;

  /// Estimated manufacture year, or `null` if not identifiable.
  final int? year;

  /// Engine displacement if visible from badging (e.g. "1103cc"), or `null`.
  final String? displacement;

  /// Primary colour description (e.g. "Ducati Red", "Matte Black").
  final String? color;

  /// Trim level or variant name (e.g. "S", "Adventure"), or `null`.
  final String? trim;

  /// Visible non-stock or aftermarket modifications.
  final List<String> modifications;

  /// Motorcycle category (e.g. "sport", "cruiser", "adventure").
  final String? category;

  /// One-liner about what this bike says about its rider.
  final String personalityLine;

  /// Interesting facts about this specific make/model.
  final String affirmingMessage;

  /// Firebase Storage download URL of the bike's photograph.
  final String imageUrl;

  /// When this bike was added to the garage.
  final DateTime addedAt;

  /// Returns a copy of this [Bike] with the specified fields replaced.
  Bike copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    String? displacement,
    String? color,
    String? trim,
    List<String>? modifications,
    String? category,
    String? personalityLine,
    String? affirmingMessage,
    String? imageUrl,
    DateTime? addedAt,
  }) {
    return Bike(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      displacement: displacement ?? this.displacement,
      color: color ?? this.color,
      trim: trim ?? this.trim,
      modifications: modifications ?? this.modifications,
      category: category ?? this.category,
      personalityLine: personalityLine ?? this.personalityLine,
      affirmingMessage: affirmingMessage ?? this.affirmingMessage,
      imageUrl: imageUrl ?? this.imageUrl,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bike &&
        other.id == id &&
        other.make == make &&
        other.model == model &&
        other.year == year &&
        other.displacement == displacement &&
        other.color == color &&
        other.trim == trim &&
        listEquals(other.modifications, modifications) &&
        other.category == category &&
        other.personalityLine == personalityLine &&
        other.affirmingMessage == affirmingMessage &&
        other.imageUrl == imageUrl &&
        other.addedAt == addedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        make,
        model,
        year,
        displacement,
        color,
        trim,
        Object.hashAll(modifications),
        category,
        personalityLine,
        affirmingMessage,
        imageUrl,
        addedAt,
      );

  @override
  String toString() =>
      'Bike(id: $id, make: $make, model: $model, year: $year)';
}
