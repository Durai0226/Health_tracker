/// The Focus accent has to cross the route boundary.
///
/// A pushed route is a child of the Navigator, not of the widget that pushed
/// it, so the `AccentScope` `FocusScreen` wraps its own body in never reached
/// any of the seven screens it opens. `AccentScope.featureOf` falls back to
/// `FeatureAccent.brand` SILENTLY — no assert, no log — so every component
/// that resolves its own swatch (`AppButton`, `StatTile`, `SegmentedToggle`,
/// `SectionHeader`, `EmptyState`, `AppListTile`, `ProgressRing`,
/// `AppBottomSheet`) rendered brand teal on a violet feature unless its call
/// site happened to pass `accent:` by hand. The Focus garden's empty state did
/// exactly that: a violet icon above a brand-coloured button, four lines apart.
///
/// `health_browse_screen.dart:39-45` already solves this for every tracker it
/// opens, by wrapping the pushed screen rather than the pusher. `_buildPageRoute`
/// now does the same.
///
/// These tests deliberately pump `FocusScreen` with NO ambient `AccentScope`.
/// The app's other Focus tests wrap it in one, which would leave this measuring
/// its own scaffolding rather than the route.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/toast/toast_overlay.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    ToastOverlay.instance.resetForTesting();
  });

  tearDown(() async {
    ToastOverlay.instance.resetForTesting();
    FocusService().resetForTesting();
    await db.close();
  });

  /// Pump the hub with no ambient scope, then open one of its destinations.
  Future<void> openFrom(WidgetTester tester, String tooltip) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        // No AccentScope here on purpose — see the library doc above.
        home: const FocusScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byTooltip(tooltip));
      // Explicit pumps rather than pumpAndSettle: the route transition is
      // AppMotion.slow and the destinations animate, so settling can time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('a screen opened from the Focus hub resolves the focus accent',
      (tester) async {
    await openFrom(tester, 'Your garden');

    final garden = find.byType(FocusGardenScreen);
    expect(garden, findsOneWidget,
        reason: 'premise: the push happened at all. Without this the accent '
            'assertion below cannot fail for the right reason.');

    expect(AccentScope.featureOf(tester.element(garden)), FeatureAccent.focus,
        reason: 'the pushed route resolved its accent from nothing, so every '
            'component on it that does not pass `accent:` by hand renders in '
            'the brand accent on a violet feature');
  });

  testWidgets('and so does a second one — it is the route builder, not a '
      'one-off on the garden', (tester) async {
    // All seven Focus destinations go through `_buildPageRoute`. Proving two
    // of them rules out the fix having been applied at a single call site,
    // which is what a one-destination test would also have accepted.
    await openFrom(tester, 'Relaxation');

    final relax = find.byType(RelaxationScreen);
    expect(relax, findsOneWidget, reason: 'premise: the push happened');
    expect(AccentScope.featureOf(tester.element(relax)), FeatureAccent.focus);
  });

  testWidgets('featureOf really does report brand without a scope',
      (tester) async {
    // The control. If `featureOf` returned `focus` for an unscoped tree, the
    // assertion above would pass whatever `_buildPageRoute` did.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          expect(AccentScope.featureOf(context), FeatureAccent.brand,
              reason: 'an unscoped subtree must fall back to brand — that is '
                  'the behaviour the test above is detecting the absence of');
          return const SizedBox.shrink();
        },
      ),
    ));
    await tester.pump();
  });

  testWidgets('an inner scope still wins over the route scope', (tester) async {
    // DetailedStatsScreen and FocusRemindersSettingsScreen declare their own.
    // Wrapping the route must not break that, or those two screens would start
    // taking the hub's accent instead of the one they chose.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AccentScope(
        feature: FeatureAccent.focus,
        child: AccentScope(
          feature: FeatureAccent.water,
          child: _AccentProbe(),
        ),
      ),
    ));
    await tester.pump();
    expect(_AccentProbe.seen, FeatureAccent.water,
        reason: 'the nearest scope must win, or a screen declaring its own '
            'accent would be overridden by whichever hub opened it');
  });
}

class _AccentProbe extends StatelessWidget {
  const _AccentProbe();
  static FeatureAccent? seen;

  @override
  Widget build(BuildContext context) {
    seen = AccentScope.featureOf(context);
    return const SizedBox.shrink();
  }
}
