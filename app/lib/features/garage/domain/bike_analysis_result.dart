import 'package:flutter/foundation.dart';

/// The structured result returned by the Cloud Run bike-vision endpoint.
///
/// This is a data-transfer object that carries everything the GPT-5.2 vision
/// model extracted from the photograph. It is presented to the user on the
/// review screen so they can correct any inaccuracies before the bike is
/// saved to Firestore.
@immutable
class BikeAnalysisResult {
  /// Creates a [BikeAnalysisResult].
  const BikeAnalysisResult({
    required this.make,
    required this.model,
    required this.affirmingMessage,
    this.year,
    this.displacement,
    this.color,
    this.trim,
    this.modifications = const [],
    this.category,
  });

  /// Deserialises a [BikeAnalysisResult] from the Cloud Run JSON response.
  ///
  /// The backend uses snake_case keys; this factory maps them to Dart
  /// camelCase fields.
  factory BikeAnalysisResult.fromJson(Map<String, dynamic> json) {
    return BikeAnalysisResult(
      make: json['make'] as String? ?? 'Unknown',
      model: json['model'] as String? ?? 'Unknown',
      year: (json['year'] as num?)?.toInt(),
      displacement: json['displacement'] as String?,
      color: json['color'] as String?,
      trim: json['trim'] as String?,
      modifications: (json['modifications'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      category: json['category'] as String?,
      affirmingMessage: json['affirming_message'] as String? ?? '',
    );
  }

  /// Manufacturer name (e.g. "Ducati", "Honda").
  final String make;

  /// Model name (e.g. "Panigale V4 S", "CBR600RR").
  final String model;

  /// Estimated manufacture year, or `null`.
  final int? year;

  /// Engine displacement if visible from badging (e.g. "1103cc"), or `null`.
  final String? displacement;

  /// Primary colour description, or `null`.
  final String? color;

  /// Trim level or variant name, or `null`.
  final String? trim;

  /// Visible non-stock or aftermarket modifications.
  final List<String> modifications;

  /// Motorcycle category (e.g. "sport", "cruiser"), or `null`.
  final String? category;

  /// LLM-generated message celebrating this specific motorcycle.
  final String affirmingMessage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BikeAnalysisResult &&
        other.make == make &&
        other.model == model &&
        other.year == year &&
        other.displacement == displacement &&
        other.color == color &&
        other.trim == trim &&
        listEquals(other.modifications, modifications) &&
        other.category == category &&
        other.affirmingMessage == affirmingMessage;
  }

  @override
  int get hashCode => Object.hash(
        make,
        model,
        year,
        displacement,
        color,
        trim,
        Object.hashAll(modifications),
        category,
        affirmingMessage,
      );

  @override
  String toString() =>
      'BikeAnalysisResult(make: $make, model: $model, year: $year)';
}
