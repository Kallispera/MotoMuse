/// Thrown when an authentication operation fails.
///
/// Wraps Firebase- and platform-level errors with a user-friendly [message]
/// that is safe to display directly in the UI.
class AuthException implements Exception {
  /// Creates an [AuthException] with the given user-facing [message].
  const AuthException(this.message);

  /// A human-readable description of the failure, suitable for display in a
  /// `SnackBar` or error label.
  final String message;

  @override
  String toString() => message;
}
