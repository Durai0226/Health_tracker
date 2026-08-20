import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// Achievements have to be visible somewhere.
///
/// `FocusService` computes twenty achievement types, persists them and fires a
/// toast on unlock — and `FocusService.achievements` had **no reader anywhere in
/// the app**. The whole system was invisible: the user could not see what they had
/// earned, what was close, or that it existed. A one-off toast is not a record.
///
/// Note the responsive sweep could not have caught this. It builds
/// `DetailedStatsScreen` against an un-initialised service, so the achievements
/// map is empty and the section correctly renders nothing — a screen that shows
/// no achievements because there are none looks identical to one that cannot show
/// them at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    StatsService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  Future<void> pumpStats(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(const MaterialApp(
        home: DetailedStatsScreen(),
      ));
      // Never pumpAndSettle a Focus screen: several run looping animations.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('the Statistics screen shows the achievement record',
      (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
      // init() populates all twenty as locked.
      await FocusService().init();
      expect(FocusService().achievements, isNotEmpty,
          reason: 'sanity: the service really is tracking achievements');

      await pumpStats(tester);
    });

    expect(find.text('Achievements'), findsOneWidget,
        reason: 'twenty tracked achievements had no reader in the entire app');

    final total = FocusService().achievements.length;
    expect(find.text('0 of $total earned'), findsOneWidget,
        reason: 'the record must state where the user actually stands');
    expect(find.text('Up next'), findsOneWidget,
        reason: 'showing what is close is the half that motivates');
  });

  testWidgets('an unlocked achievement is distinguishable from a locked one',
      (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
      final focus = FocusService();
      await focus.init();
      // Run one session to completion so at least one achievement unlocks.
      //
      // NOT `pumpEventQueue()`: `startSession` installs a `Timer.periodic`, and
      // inside testWidgets' FakeAsync the event queue never drains while a
      // periodic timer is pending — the first version of this test hung for ten
      // minutes. `tester.pump` advances FakeAsync deterministically instead.
      focus.setDuration(1);
      await focus.startSession();
      focus.applyTick(0);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      await pumpStats(tester);
    });

    final unlockedCount =
        FocusService().achievements.values.where((a) => a.isUnlocked).length;
    expect(unlockedCount, greaterThan(0),
        reason: 'completing a session must unlock at least "first session"');

    final total = FocusService().achievements.length;
    expect(find.text('$unlockedCount of $total earned'), findsOneWidget,
        reason: 'the earned count has to track reality, not stay at zero');
  });
}
