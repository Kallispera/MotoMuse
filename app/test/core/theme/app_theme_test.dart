import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/core/theme/app_colors.dart';
import 'package:motomuse/core/theme/app_theme.dart';

void main() {
  // AppColors tests have no dependencies — plain unit tests are fine.
  group('AppColors', () {
    test('amber and gold are distinct colors', () {
      expect(AppColors.amber, isNot(AppColors.gold));
    });

    test('light and dark backgrounds are distinct', () {
      expect(AppColors.lightBackground, isNot(AppColors.darkBackground));
    });

    test('light primary matches amber', () {
      expect(AppColors.lightPrimary, AppColors.amber);
    });

    test('dark primary matches gold', () {
      expect(AppColors.darkPrimary, AppColors.gold);
    });
  });

  // AppTheme tests call GoogleFonts internally, so use testWidgets which
  // initialises the binding and handles font-load failures gracefully.
  group('AppTheme', () {
    group('light', () {
      testWidgets('uses light brightness', (tester) async {
        expect(AppTheme.light.brightness, Brightness.light);
      });

      testWidgets('primary color is amber', (tester) async {
        expect(
          AppTheme.light.colorScheme.primary,
          AppColors.lightPrimary,
        );
      });

      testWidgets('scaffold background is parchment', (tester) async {
        expect(
          AppTheme.light.scaffoldBackgroundColor,
          AppColors.lightBackground,
        );
      });

      testWidgets('uses Material 3', (tester) async {
        expect(AppTheme.light.useMaterial3, isTrue);
      });
    });

    group('dark', () {
      testWidgets('uses dark brightness', (tester) async {
        expect(AppTheme.dark.brightness, Brightness.dark);
      });

      testWidgets('primary color is gold', (tester) async {
        expect(
          AppTheme.dark.colorScheme.primary,
          AppColors.darkPrimary,
        );
      });

      testWidgets('scaffold background is leather black', (tester) async {
        expect(
          AppTheme.dark.scaffoldBackgroundColor,
          AppColors.darkBackground,
        );
      });
    });

    testWidgets('light and dark primary colors are distinct', (tester) async {
      expect(
        AppTheme.light.colorScheme.primary,
        isNot(AppTheme.dark.colorScheme.primary),
      );
    });
  });
}
