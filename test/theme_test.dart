import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
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
      expect(AppTheme.lightTheme.scaffoldBackgroundColor,
          AppColorsExt.light.background);
    });

    testWidgets('Dark theme has correct scaffold background', (tester) async {
      expect(AppTheme.darkTheme.scaffoldBackgroundColor,
          AppColorsExt.dark.background);
    });

    testWidgets('Dark theme has dark brightness', (tester) async {
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    testWidgets('Light theme has light brightness', (tester) async {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
    });

    testWidgets('Dark theme card color is correct', (tester) async {
      expect(AppTheme.darkTheme.cardColor, AppColorsExt.dark.surface);
    });

    testWidgets('Light theme card color is white', (tester) async {
      expect(AppTheme.lightTheme.cardColor, AppColorsExt.light.surface);
    });
  });

  group('the palette, not the shim', () {
    // Seven tests lived here against `AppColors`, the legacy shim. Four of them
    // could not fail: `expect(AppColors.primary, isA<Color>())` on a
    // `static const Color`, `isA<Function>()` on a static method,
    // `isA<LinearGradient>()` on a const gradient. A type assertion on a
    // statically-typed const is not a test.
    //
    // The three that meant something are kept and re-pointed at
    // `AppColorsExt`, which is what the app reads now, and joined by the
    // contrast checks that are the actual requirement.
    test('the dark background is darker than the light one', () {
      expect(AppColorsExt.dark.background.computeLuminance(),
          lessThan(AppColorsExt.light.background.computeLuminance()));
    });

    test('primary text is light on dark and dark on light', () {
      expect(AppColorsExt.dark.textPrimary.computeLuminance(),
          greaterThan(0.5));
      expect(AppColorsExt.light.textPrimary.computeLuminance(), lessThan(0.5));
    });

    test('body text clears 4.5:1 against its own surface in both themes', () {
      // The thing the luminance tests above were reaching for. A colour can be
      // "light on dark" and still be unreadable.
      for (final ext in [AppColorsExt.light, AppColorsExt.dark]) {
        expect(_contrast(ext.textPrimary, ext.surface),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(ext.textPrimary, ext.background),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(ext.textSecondary, ext.surface),
            greaterThanOrEqualTo(4.5));
      }
    });

    test('isDark actually distinguishes the two extensions', () {
      expect(AppColorsExt.light.isDark, isFalse);
      expect(AppColorsExt.dark.isDark, isTrue);
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

    testWidgets('the theme resolves the DARK extension under darkTheme',
        (tester) async {
      AppColorsExt? resolved;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(builder: (context) {
          resolved = AppColorsExt.of(context);
          return const Scaffold(body: Text('Test'));
        }),
      ));
      expect(resolved!.isDark, isTrue);
      expect(resolved!.background, AppColorsExt.dark.background);
      expect(resolved!.textPrimary, AppColorsExt.dark.textPrimary);
    });

    testWidgets('and the LIGHT extension under lightTheme', (tester) async {
      AppColorsExt? resolved;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(builder: (context) {
          resolved = AppColorsExt.of(context);
          return const Scaffold(body: Text('Test'));
        }),
      ));
      expect(resolved!.isDark, isFalse);
      expect(resolved!.background, AppColorsExt.light.background);
    });
  });
}

double _lin(int c) {
  final v = c / 255;
  return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) =>
    0.2126 * _lin((c.r * 255).round()) +
    0.7152 * _lin((c.g * 255).round()) +
    0.0722 * _lin((c.b * 255).round());

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
