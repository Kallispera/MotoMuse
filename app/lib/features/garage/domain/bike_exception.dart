/// Thrown when a garage operation fails.
///
/// Wraps network-, API-, and Firestore-level errors with a user-friendly
/// [message] that is safe to display directly in a `SnackBar` or error label.
class BikeException implements Exception {
  /// Creates a [BikeException] with the given user-facing [message].
  const BikeException(this.message);

  /// A human-readable description of the failure, suitable for display in
  /// a `SnackBar` or error label.
  final String message;

  @override
  String toString() => message;
}
