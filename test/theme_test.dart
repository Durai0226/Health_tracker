import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/constants/app_colors.dart';
import 'package:tablet_remainder/core/design/app_palette.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';

void main() {
  setUpAll(() {
    // Prevent google_fonts from making network requests in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  group('AppTheme Tests', () {
    // Color ROLES are asserted against the Calm Clarity design tokens directly
    // — building the full ThemeData pulls GoogleFonts, which can't runtime-fetch
    // in headless tests. Properties that must read ThemeData run as testWidgets
    // (the widget-test zone handles the font load gracefully).
    test('Light theme uses the base brand teal as primary', () {
      expect(AppColorsExt.light.brand.base, AppPalette.brand);
      expect(AppColors.primary, AppPalette.brand);
    });

    test('Dark theme uses the lighter brand teal as primary', () {
      // Dark mode uses a lighter teal for contrast (proper M3 dark adaptation).
      expect(AppColorsExt.dark.brand.base, AppPalette.brandDark);
    });

    testWidgets('Light theme has correct primary color', (tester) async {
      expect(AppTheme.lightTheme.colorScheme.primary, AppPalette.brand);
    });

    testWidgets('Dark theme has correct primary color', (tester) async {
      expect(AppTheme.darkTheme.colorScheme.primary, AppPalette.brandDark);
    });

    testWidgets('Light theme has correct scaffold background', (tester) async {
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.background);
    });

    testWidgets('Dark theme has correct scaffold background', (tester) async {
      expect(
          AppTheme.darkTheme.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    testWidgets('Dark theme has dark brightness', (tester) async {
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    testWidgets('Light theme has light brightness', (tester) async {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
    });

    testWidgets('Dark theme card color is correct', (tester) async {
      expect(AppTheme.darkTheme.cardColor, AppColors.darkCard);
    });

    testWidgets('Light theme card color is white', (tester) async {
      expect(AppTheme.lightTheme.cardColor, AppColors.cardBg);
    });
  });

  group('AppColors Tests', () {
    test('Primary color is defined', () {
      expect(AppColors.primary, isA<Color>());
    });

    test('Dark background is darker than light background', () {
      final darkLuminance = AppColors.darkBackground.computeLuminance();
      final lightLuminance = AppColors.background.computeLuminance();
      expect(darkLuminance, lessThan(lightLuminance));
    });

    test('Dark text primary is light colored', () {
      final luminance = AppColors.darkTextPrimary.computeLuminance();
      expect(luminance, greaterThan(0.5));
    });

    test('Light text primary is dark colored', () {
      final luminance = AppColors.textPrimary.computeLuminance();
      expect(luminance, lessThan(0.5));
    });

    test('Theme-aware color helpers exist', () {
      expect(AppColors.getBackground, isA<Function>());
      expect(AppColors.getSurface, isA<Function>());
      expect(AppColors.getCardBg, isA<Function>());
      expect(AppColors.getTextPrimary, isA<Function>());
      expect(AppColors.getTextSecondary, isA<Function>());
      expect(AppColors.getDivider, isA<Function>());
      expect(AppColors.getBorder, isA<Function>());
      expect(AppColors.isDark, isA<Function>());
    });

    test('Luxury dark theme colors exist', () {
      expect(AppColors.darkAccentGold, isA<Color>());
      expect(AppColors.darkAccentPurple, isA<Color>());
      expect(AppColors.darkAccentTeal, isA<Color>());
      expect(AppColors.darkAccentRose, isA<Color>());
      expect(AppColors.darkElevatedCard, isA<Color>());
      expect(AppColors.darkShimmer, isA<Color>());
    });

    test('Dark gradients are defined', () {
      expect(AppColors.darkPrimaryGradient, isA<LinearGradient>());
      expect(AppColors.darkLuxuryGradient, isA<LinearGradient>());
      expect(AppColors.darkGoldGradient, isA<LinearGradient>());
      expect(AppColors.darkSurfaceGradient, isA<LinearGradient>());
      expect(AppColors.darkCardGradient, isA<LinearGradient>());
    });
  });

  group('Theme Integration Tests', () {
    testWidgets('Light theme renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('Light Theme Test')),
          ),
        ),
      );

      expect(find.text('Light Theme Test'), findsOneWidget);
    });

    testWidgets('Dark theme renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: Center(child: Text('Dark Theme Test')),
          ),
        ),
      );

      expect(find.text('Dark Theme Test'), findsOneWidget);
    });

    testWidgets('Theme switching works', (tester) async {
      ThemeMode currentTheme = ThemeMode.light;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentTheme,
              home: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        currentTheme = currentTheme == ThemeMode.light
                            ? ThemeMode.dark
                            : ThemeMode.light;
                      });
                    },
                    child: const Text('Toggle Theme'),
                  ),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Toggle Theme'), findsOneWidget);
      
      // Tap to toggle theme
      await tester.tap(find.text('Toggle Theme'));
      await tester.pumpAndSettle();
      
      expect(find.text('Toggle Theme'), findsOneWidget);
    });

    testWidgets('AppColors.isDark returns correct value for dark theme', (tester) async {
      bool? isDarkResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              isDarkResult = AppColors.isDark(context);
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(isDarkResult, isTrue);
    });

    testWidgets('AppColors.isDark returns correct value for light theme', (tester) async {
      bool? isDarkResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              isDarkResult = AppColors.isDark(context);
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(isDarkResult, isFalse);
    });

    testWidgets('Theme-aware colors return correct values in dark mode', (tester) async {
      Color? bgColor;
      Color? textColor;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              bgColor = AppColors.getBackground(context);
              textColor = AppColors.getTextPrimary(context);
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(bgColor, AppColors.darkBackground);
      expect(textColor, AppColors.darkTextPrimary);
    });

    testWidgets('Theme-aware colors return correct values in light mode', (tester) async {
      Color? bgColor;
      Color? textColor;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              bgColor = AppColors.getBackground(context);
              textColor = AppColors.getTextPrimary(context);
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(bgColor, AppColors.background);
      expect(textColor, AppColors.textPrimary);
    });
  });
}
