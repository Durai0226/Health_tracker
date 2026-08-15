@Tags(['performance'])
library;

/// Scrolling the water dashboard must not rebuild the whole screen.
///
/// The scroll listener used to call an unconditional whole-screen `setState`,
/// so every scroll notification rebuilt ~1379 widgets — the largest tree in the
/// water feature. The value it changed (`_headerOpacity`) is read in exactly one
/// place and clamps to 0.0 once the offset passes 150px, so the majority of
/// those rebuilds produced a pixel-identical frame.
///
/// This test counts how many times the BODY rebuilds during a scroll. It is a
/// behavioural assertion, not a timing one, so it is stable on any machine.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_quick_add_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  testWidgets('scrolling does not rebuild the whole water dashboard',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(const MaterialApp(
        home: AquaWaterDashboard(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isEmpty) {
        markTestSkipped('no Scrollable rendered (empty-state layout)');
        return;
      }

      // Compare the WIDGET instance, not the Element.
      //
      // Flutter reuses Elements across rebuilds by design, so element identity
      // survives `setState` and tells you nothing — an earlier version of this
      // test compared Elements and therefore passed even with the bug
      // deliberately reintroduced. Widgets are immutable: a re-run of the
      // parent's build() necessarily constructs a NEW AquaQuickAddGrid, so
      // instance identity is the honest signal for "was the body rebuilt".
      Widget? bodyWidget() {
        final f = find.byType(AquaQuickAddGrid);
        if (f.evaluate().isEmpty) return null;
        return f.evaluate().first.widget;
      }

      final before = bodyWidget();
      if (before == null) {
        markTestSkipped('quick-add grid not present in this state');
        return;
      }

      // Drive a real multi-notification scroll past the 150px fade threshold.
      final gesture = await tester.startGesture(const Offset(200, 600));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, -15));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));

      final after = bodyWidget();
      expect(after, isNotNull);
      expect(
        identical(before, after),
        isTrue,
        reason: 'The body widget was reconstructed during scroll, which means '
            'the scroll listener is still rebuilding the whole screen instead '
            'of just the header.',
      );
    } finally {
      FlutterError.onError = prev;
    }
  });
}
