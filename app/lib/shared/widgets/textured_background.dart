import 'package:flutter/material.dart';
import 'package:motomuse/core/theme/app_colors.dart';

/// Wraps [child] in a full-screen brand texture.
///
/// Automatically selects the leather texture in dark mode and the parchment
/// texture in light mode. The texture is composited over the theme's
/// scaffold background colour using [BlendMode.multiply] so the brand palette
/// tints are preserved.
///
/// Apply at the shell level so all screens inherit the effect without
/// each screen needing to opt in.
class TexturedBackground extends StatelessWidget {
  /// Creates a textured background around [child].
  const TexturedBackground({required this.child, super.key});

  /// The widget to display on top of the texture.
  final Widget child;

  static const _darkAsset = 'assets/textures/texture_dark.jpg';
  static const _lightAsset = 'assets/textures/texture_light.jpg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Base brand colour sits beneath the texture.
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        image: DecorationImage(
          image: AssetImage(isDark ? _darkAsset : _lightAsset),
          fit: BoxFit.cover,
          // Keep texture subtle — depth, not distraction.
          opacity: isDark ? 0.18 : 0.22,
          colorFilter: ColorFilter.mode(
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
            BlendMode.multiply,
          ),
        ),
      ),
      child: child,
    );
  }
}
