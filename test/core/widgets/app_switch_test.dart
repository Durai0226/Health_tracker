/// The switch, and the defect that prompted replacing it.
///
/// The Material implementation resolved `ext.surfaceVariant` as the track
/// colour for **both** the off state and the disabled state — 1.000:1 between
/// them — so an off row read as unavailable. The only difference was the thumb,
/// `outlineStrong` vs `textDisabled`, at 1.322:1 light and 1.187:1 dark.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

double _lin(int c) {
  final v = c / 255;
  return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) =>
    0.2126 * _lin((c.r * 255).round()) +
    0.7152 * _lin((c.g * 255).round()) +
    0.0722 * _lin((c.b * 255).round());

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<CupertinoSwitch> pump(WidgetTester tester,
      {required bool value, required bool enabled, ThemeData? theme}) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: AppSwitch(value: value, onChanged: enabled ? (_) {} : null),
        ),
      ),
    ));
    // NOT a bare pump. `MaterialApp` drives theme changes through
    // `AnimatedTheme`, and `AppColorsExt.lerp` returns the FROM theme's
    // `isDark` for t < 0.5 — so a single pump after switching themes reads the
    // previous palette and every dark assertion silently measures light.
    await tester.pumpAndSettle();
    return tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
  }

  group('off must not look disabled', () {
    testWidgets('a disabled switch is distinguishable from an off one',
        (tester) async {
      // The fix is structural rather than chromatic: Cupertino renders a
      // disabled switch at a flat 50% opacity, so the two states cannot drift
      // back into the same pixels the way two colour tokens did.
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        // The Opacity is always in the tree; what differs is its value.
        await pump(tester, value: false, enabled: true, theme: theme);
        final on = tester
            .widgetList<Opacity>(find.descendant(
                of: find.byType(CupertinoSwitch), matching: find.byType(Opacity)))
            .map((w) => w.opacity);
        expect(on, everyElement(1.0),
            reason: 'an enabled switch must render at full opacity');

        await pump(tester, value: false, enabled: false, theme: theme);
        final off = tester
            .widgetList<Opacity>(find.descendant(
                of: find.byType(CupertinoSwitch), matching: find.byType(Opacity)))
            .map((w) => w.opacity);
        expect(off, contains(0.5),
            reason: 'a disabled switch must be visibly ghosted; the old '
                'implementation gave off and disabled the same track colour');
      }
    });

    testWidgets('the off track carries a boundary that meets 1.4.11',
        (tester) async {
      // A pale track cannot itself reach 3:1 against a pale card and still read
      // as "off" — iOS's own is about 1.1:1. The outline carries it.
      for (final (theme, ext) in [
        (AppTheme.lightTheme, AppColorsExt.light),
        (AppTheme.darkTheme, AppColorsExt.dark),
      ]) {
        final sw = await pump(tester, value: false, enabled: true, theme: theme);
        final outline = sw.trackOutlineColor!.resolve({})!;
        expect(contrast(outline, ext.surface), greaterThanOrEqualTo(3.0),
            reason: 'the off switch has no discernible boundary on the card');
        expect(contrast(outline, ext.background), greaterThanOrEqualTo(3.0),
            reason: 'nor on the page');
      }
    });

    testWidgets('an ON track is not outlined', (tester) async {
      final sw = await pump(tester, value: true, enabled: true);
      expect(sw.trackOutlineColor!.resolve({WidgetState.selected})!.a, 0.0,
          reason: 'an outline around a filled track reads as a seam');
    });
  });

  group('the on state uses the validated filled-control pair', () {
    testWidgets('every accent clears 3:1 on both axes, in both themes',
        (tester) async {
      // Measured rather than trusted. The naive choice fails: a white thumb on
      // `s.base` is 2.44:1 for brand in dark and 2.15:1 for reminders in light,
      // and no single accent field passes in both themes.
      for (final (theme, ext) in [
        (AppTheme.lightTheme, AppColorsExt.light),
        (AppTheme.darkTheme, AppColorsExt.dark),
      ]) {
        for (final (label, s) in <(String, AccentSwatch)>[
          ('brand', ext.brand),
          ('medicine', ext.medicine),
          ('water', ext.water),
          ('focus', ext.focus),
          ('reminders', ext.reminders),
          ('period', ext.period),
          ('steps', ext.steps),
          ('sleep', ext.sleep),
        ]) {
          await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: AppSwitch(value: true, onChanged: (_) {}, accent: s),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          final sw = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
          final track = sw.activeTrackColor!;
          final thumb = sw.thumbColor!;
          expect(contrast(thumb, track), greaterThanOrEqualTo(3.0),
              reason: '$label thumb on track');
          expect(contrast(track, ext.surface), greaterThanOrEqualTo(3.0),
              reason: '$label track on card');
        }
      }
    });
  });

  testWidgets('the swap is layout-neutral', (tester) async {
    // Cupertino lays out at 59x39 against Material's 60x48. 47 switches render
    // across the app and none of them may move.
    await pump(tester, value: false, enabled: true);
    expect(tester.getSize(find.byType(AppSwitch)), const Size(60, 48));
    expect(AppSwitch.size, const Size(60, 48));
  });

  testWidgets('the app theme no longer carries a decoy switch style',
      (tester) async {
    // `switchTheme` set exactly the three properties AppSwitch overrode, so it
    // styled nothing — while encoding a different, failing design that would
    // have silently applied to the next raw `Switch` anyone added.
    expect(AppTheme.lightTheme.switchTheme.thumbColor, isNull);
    expect(AppTheme.lightTheme.switchTheme.trackColor, isNull);
    expect(AppTheme.darkTheme.switchTheme.thumbColor, isNull);
  });
}
