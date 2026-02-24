/// Domain-level exception for route generation and retrieval errors.
///
/// Thrown by the route service and caught in the notifier to surface
/// meaningful error messages to the user.
class RouteException implements Exception {
  /// Creates a [RouteException] with the given [message].
  const RouteException(this.message);

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => 'RouteException: $message';
}
