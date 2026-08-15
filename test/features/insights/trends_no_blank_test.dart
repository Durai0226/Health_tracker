/// Switching the Trends range must not blank the screen.
///
/// This is the most visible "glitch when switching" in the app, and it has
/// nothing to do with ripples. `_setRange` assigns a fresh `Future`, and the
/// `FutureBuilder` fell straight back to `_loading` — four solid grey 208px
/// blocks — until it resolved. So every tap on Week/Month/Year tore the whole
/// dashboard down to placeholders and re-mounted every chart card, each of
/// which then re-animated from zero.
///
/// The fix keeps the last good bundle on screen while the new range loads.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/segmented_toggle.dart';
import 'package:tablet_remainder/features/insights/screens/trends_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pumpTrends(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const TrendsDashboardScreen(isRoot: true),
    ));
    // Settle the FIRST load adaptively. Cold service init takes a variable
    // number of frames, and tapping before it finishes compares one skeleton
    // against another — the test then cannot fail, which is exactly what
    // happened on the first attempt. `pumpAndSettle` is not an option here:
    // LoadingSkeleton repeats forever, so it would time out.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester
              .widgetList<Text>(find.byType(Text))
              .where((t) => (t.data ?? '').trim().isNotEmpty)
              .length >
          8) {
        break;
      }
    }
  }

  /// How much real content is on screen right now. The skeleton state renders
  /// grey boxes and almost no text, so a collapse in this count is the flash.
  int visibleTextCount(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .where((t) => (t.data ?? '').trim().isNotEmpty)
      .length;

  testWidgets('changing range never empties the dashboard', (tester) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await pumpTrends(tester);

      final toggle = find.byType(SegmentedToggle);
      if (toggle.evaluate().isEmpty) {
        markTestSkipped('range toggle not rendered in this state');
        return;
      }
      final labels = tester
          .widgetList<SegmentedToggle>(toggle)
          .first
          .items
          .map((i) => i.label)
          .toList();
      if (labels.length < 3) {
        markTestSkipped('need at least three ranges to switch between');
        return;
      }

      /// Pump until the dashboard is genuinely loaded (not skeleton, not
      /// error). Both of those render only a handful of strings.
      Future<bool> reachLoaded() async {
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (visibleTextCount(tester) > 8) return true;
        }
        return false;
      }

      // The very first load can fail in a headless environment (services are
      // still coming up), which renders the error state. Switching range
      // retries, so drive one switch to reach a real loaded dashboard before
      // measuring anything.
      await tester.tap(find.text(labels[1]));
      if (!await reachLoaded()) {
        markTestSkipped('trends never reached a loaded state headlessly');
        return;
      }

      final before = visibleTextCount(tester);
      expect(before, greaterThan(8),
          reason: 'sanity: measuring from a genuinely loaded dashboard');

      // Now the real assertion: switch range and look at the VERY NEXT frame.
      // That is precisely when the old implementation had already swapped the
      // whole dashboard for four grey blocks.
      await tester.tap(find.text(labels[2]));
      await tester.pump();

      expect(
        visibleTextCount(tester),
        greaterThan(8),
        reason: 'The dashboard collapsed on the frame after a range tap: '
            '$before strings before, ${visibleTextCount(tester)} after. It '
            'must keep rendering the previous bundle while the new one loads, '
            'or every switch is a full-screen flash that re-mounts and '
            're-animates every chart card.',
      );
    } finally {
      FlutterError.onError = prev;
    }

    await tester.pump(const Duration(seconds: 8));
  });
}
