import 'package:flutter/foundation.dart';
import 'package:motomuse/features/garage/domain/bike_analysis_result.dart';

/// Combines the Cloud Run analysis result with the Firebase Storage URL of
/// the uploaded photograph.
///
/// This object is created after both the upload and the analysis have
/// succeeded, and is passed to the bike review screen via GoRouter `extra`.
@immutable
class BikePhotoAnalysis {
  /// Creates a [BikePhotoAnalysis].
  const BikePhotoAnalysis({
    required this.result,
    required this.imageUrl,
  });

  /// The structured details extracted from the motorcycle photograph.
  final BikeAnalysisResult result;

  /// The Firebase Storage download URL of the uploaded photograph.
  final String imageUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BikePhotoAnalysis &&
        other.result == result &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode => Object.hash(result, imageUrl);

  @override
  String toString() =>
      'BikePhotoAnalysis(result: $result, imageUrl: $imageUrl)';
}
