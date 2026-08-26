/// Screen chrome that every screen gets from `AppScaffold`: the status-bar
/// glyph colour, and the display-cutout inset.
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

  // -------------------------------------------------------- cutout insets

  group('the body is inset from a display cutout', () {
    /// `safeTop` is a misnomer — `AppHeader` applies its own `SafeArea` and
    /// `SafeArea` removes what it consumes from the `MediaQuery` beneath it, so
    /// the top is a no-op. What the flag actually buys is the LEFT and RIGHT
    /// insets, which the body below the header does not otherwise get.
    ///
    /// It used to default to false with 20 of 66 screens opting in, so 46 had a
    /// body running under the cutout in landscape while their neighbours did
    /// not. These two tests are why that asymmetry cannot come back.
    Future<Rect> bodyRectWith(WidgetTester tester, EdgeInsets padding,
        {bool safeTop = true}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
              size: const Size(800, 400), padding: padding, viewPadding: padding),
          child: AppScaffold(
            safeTop: safeTop,
            body: Container(key: const Key('body'), color: const Color(0xFF000000)),
          ),
        ),
      ));
      await tester.pump();
      return tester.getRect(find.byKey(const Key('body')));
    }

    testWidgets('a landscape notch does not run under the body', (tester) async {
      // A phone held landscape: the cutout is on one side, not the top.
      const notch = EdgeInsets.only(left: 44, right: 12);
      final inset = await bodyRectWith(tester, notch);
      expect(inset.left, 44.0);
      expect(inset.right, 800.0 - 12.0);
    });

    testWidgets('and opting out is still possible for a full-bleed body',
        (tester) async {
      // The parameter stays because a deliberately edge-to-edge body is a real
      // case. What changed is which way round the default points.
      const notch = EdgeInsets.only(left: 44, right: 12);
      final bleed = await bodyRectWith(tester, notch, safeTop: false);
      expect(bleed.left, 0.0);
      expect(bleed.right, 800.0);
    });
  });
}
