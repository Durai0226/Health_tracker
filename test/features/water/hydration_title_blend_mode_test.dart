/// The "Hydration" title is painted through a [ShaderMask], and the blend mode
/// is the whole thing.
///
/// `ShaderMask` defaults to [BlendMode.modulate], which MULTIPLIES the shader
/// by its child rather than replacing it — so the child's text colour is still
/// a factor. That colour is `fillFg(water)`, which is
/// `isDark ? swatch.on : Colors.white`:
///
///  * in light mode it is white, and `white * gradient == gradient`, so the
///    title looked exactly as intended and shipped;
///  * in dark mode it is the swatch's dark `on` colour, and
///    `dark * gradient` collapsed the title to rgb(0,27,38) on a rgb(12,67,80)
///    header.
///
/// Measured off a device screenshot, the BEST contrast any pixel of the word
/// achieved was 1.71:1 — the whole title was below that. With
/// [BlendMode.srcIn] the shader really does supply the colour and the same
/// measurement gives 3.89:1, clearing the 3:1 that WCAG asks of large text.
///
/// Nothing headless could have caught this: every previous harness ran in
/// light mode, where the bug is invisible by construction.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Before anything touches AppTheme: building a theme resolves GoogleFonts,
  // and at collection time that happens outside a test zone and tries to hit
  // the network. `setUpAll` runs too late for a theme built in a list literal.
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(theme: theme, home: const AquaWaterDashboard()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// Every ShaderMask wrapping the title.
  Iterable<ShaderMask> titleMasks(WidgetTester tester) =>
      tester.widgetList<ShaderMask>(find.ancestor(
        of: find.text('Hydration'),
        matching: find.byType(ShaderMask),
      ));

  for (final name in const ['dark', 'light']) {
    testWidgets('the title shader replaces rather than multiplies ($name)',
        (tester) async {
      // Built inside the test, for the reason at the top of main().
      await pump(tester,
          name == 'dark' ? AppTheme.darkTheme : AppTheme.lightTheme);

      final masks = titleMasks(tester);
      expect(masks, isNotEmpty,
          reason: 'premise: the title is painted through a ShaderMask. If that '
              'changed, this test is measuring nothing and must be rewritten.');

      for (final m in masks) {
        expect(m.blendMode, BlendMode.srcIn,
            reason: 'BlendMode.modulate (the default) multiplies the gradient '
                'by the text colour underneath. That colour is '
                'fillFg(water) = isDark ? swatch.on : white, so in dark mode '
                'it multiplied the title down to 1.71:1 against its own '
                'header. srcIn makes the shader the colour and the glyph only '
                'its coverage.');
        expect(m.blendMode, isNot(BlendMode.modulate));
      }
    });
  }
}
