import 'package:flutter/foundation.dart';

/// Immutable representation of the currently authenticated user.
///
/// This is a domain-layer value object. It is independent of any Firebase
/// types so that the rest of the app does not need to import firebase_auth.
@immutable
class AppUser {
  /// Creates an [AppUser] with the given fields.
  const AppUser({
    required this.uid,
    required this.email,
    required this.isEmailVerified,
    this.displayName,
    this.photoUrl,
  });

  /// The unique identifier assigned by Firebase Auth.
  final String uid;

  /// The user's primary email address.
  final String email;

  /// Whether the user has verified their email address.
  final bool isEmailVerified;

  /// The user's display name, if available.
  final String? displayName;

  /// The URL of the user's profile photo, if available.
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          isEmailVerified == other.isEmailVerified &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode => Object.hash(
        uid,
        email,
        isEmailVerified,
        displayName,
        photoUrl,
      );

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, '
      'isEmailVerified: $isEmailVerified, '
      'displayName: $displayName)';
}
