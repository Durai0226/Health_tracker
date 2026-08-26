/// Every screen declares its own status-bar glyph colour.
///
/// Before this, `AppBarTheme.systemOverlayStyle` was the only declaration in
/// the app, and a theme only reaches screens that build an `AppBar` — eleven of
/// them. The ~60 screens composing `AppScaffold` + `AppHeader` inherited
/// whatever the last `AppBar` screen left behind, or the platform default on a
/// cold start.
///
/// The platform default is white glyphs: neither `values/styles.xml` nor
/// `values-night/styles.xml` sets `windowLightStatusBar`. The app targets SDK 36
/// (`FlutterExtension.kt:34`), where edge-to-edge is enforced, so the light
/// `background` is painted behind the status bar rather than a dark system
/// strip sitting above it — white clock on a white background.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<SystemUiOverlayStyle> styleUnder(
      WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const AppScaffold(body: SizedBox.shrink()),
    ));
    await tester.pump();
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
    return region.value;
  }

  testWidgets('a light scaffold asks for DARK glyphs', (tester) async {
    final s = await styleUnder(tester, AppTheme.lightTheme);
    // `SystemUiOverlayStyle.dark` is named for the glyphs, not the background.
    expect(s.statusBarIconBrightness, Brightness.dark);
    expect(s.systemNavigationBarIconBrightness, Brightness.dark);
  });

  testWidgets('a dark scaffold asks for LIGHT glyphs', (tester) async {
    final s = await styleUnder(tester, AppTheme.darkTheme);
    expect(s.statusBarIconBrightness, Brightness.light);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets('both bars are transparent, as enforced edge-to-edge requires',
      (tester) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final s = await styleUnder(tester, theme);
      // On API 35+ a bar colour is a no-op, and below it produces a strip that
      // does not match the scaffold. Transparent is the only correct value.
      expect(s.statusBarColor, Colors.transparent);
      expect(s.systemNavigationBarColor, Colors.transparent);
    }
  });

  testWidgets('the declaration follows the scaffold, not the presence of an AppBar',
      (tester) async {
    // The regression this closes: a screen with no AppBar declaring nothing.
    // AppHeader is not an AppBar and never was.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AppScaffold(
        body: Column(children: [AppHeader(title: 'Sleep')]),
      ),
    ));
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(AnnotatedRegion<SystemUiOverlayStyle>), findsOneWidget,
        reason: 'a screen with no AppBar must still declare its glyph colour');
  });
}
