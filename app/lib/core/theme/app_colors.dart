import 'package:flutter/material.dart';

/// Brand color tokens derived from the MotoMuse visual identity.
///
/// Light theme uses a parchment/amber palette.
/// Dark theme uses a leather/gold palette.
/// All widgets should reference these tokens via [Theme.of(context)] rather
/// than using raw hex values directly.
abstract final class AppColors {
  // ── Shared ──────────────────────────────────────────────────────────

  /// Amber — primary action color for the light theme.
  static const Color amber = Color(0xFFC17A1A);

  /// Gold — primary action color for the dark theme.
  static const Color gold = Color(0xFFD4922A);

  /// Navy — border and secondary accent for the light theme.
  static const Color navy = Color(0xFF1B2E5A);

  /// Dark navy — border and secondary accent for the dark theme.
  static const Color navyDark = Color(0xFF1B3A7A);

  // ── Light theme ─────────────────────────────────────────────────────

  /// Parchment — scaffold background for the light theme.
  static const Color lightBackground = Color(0xFFF2E8D0);

  /// Off-white — card/surface background for the light theme.
  static const Color lightSurface = Color(0xFFFAF6EE);

  /// Amber — primary interactive color for the light theme.
  static const Color lightPrimary = amber;

  /// White — text/icon color on primary-colored surfaces in the light theme.
  static const Color lightOnPrimary = Colors.white;

  /// Dark brown — primary text color for the light theme.
  static const Color lightTextPrimary = Color(0xFF2C1810);

  /// Warm grey — muted/secondary text color for the light theme.
  static const Color lightTextMuted = Color(0xFF7A5C40);

  // ── Dark theme ──────────────────────────────────────────────────────

  /// Leather black — scaffold background for the dark theme.
  static const Color darkBackground = Color(0xFF1A1A1A);

  /// Dark card — card/surface background for the dark theme.
  static const Color darkSurface = Color(0xFF272727);

  /// Gold — primary interactive color for the dark theme.
  static const Color darkPrimary = gold;

  /// Dark background — text/icon color on primary-colored surfaces
  /// in the dark theme.
  static const Color darkOnPrimary = Color(0xFF1A1A1A);

  /// Cream — primary text color for the dark theme.
  static const Color darkTextPrimary = Color(0xFFF2E8D0);

  /// Warm grey — muted/secondary text color for the dark theme.
  static const Color darkTextMuted = Color(0xFFA89070);
}
