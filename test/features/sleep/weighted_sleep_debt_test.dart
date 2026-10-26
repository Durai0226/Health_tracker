/// "4h 20m behind over 14 nights — about 25 extra minutes a night for a week
/// clears it." The maths is in `sleep_debt_test`; this pins that the service
/// feeds it the right nights and that the dashboard, the engine and the coach
/// all speak from it.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';
import 'package:tablet_remainder/core/health/sleep_debt.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

final _now = DateTime(2026, 3, 10, 10, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (_) async => <String, dynamic>{},
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    // A process singleton: without this, sessions logged by one test are still
    // there for the next.
    SleepService.clearInMemory();
    await SleepService.resetForTesting();
    await SleepService.init();
  });

  tearDown(() async => db.close());

  /// Logs a night with EXACTLY [asleep] minutes asleep, ending [ageDays]
  /// mornings before the pinned "today".
  ///
  /// A manual session estimates asleep as 85% of time in bed at quality 3, so
  /// the bed time is derived backwards from the wanted figure. [asleep] must be
  /// a multiple of 17 for that to round-trip exactly (17 x 20 = 340 = 0.85 x
  /// 400), which the callers below respect.
  Future<void> logNight(int ageDays, int asleep) async {
    assert(asleep % 17 == 0, 'use a multiple of 17 so the 85% estimate is exact');
    final inBed = asleep * 20 ~/ 17;
    final wake = DateTime(_now.year, _now.month, _now.day - ageDays, 7, 0);
    await SleepService.logManualSession(
      bedtime: wake.subtract(Duration(minutes: inBed)),
      wakeTime: wake,
      quality: 3,
    );
  }

  group('SleepService.sleepDebt', () {
    test('reads only logged nights, with the right ages', () async {
      await withClock(Clock.fixed(_now), () async {
        await logNight(0, 374); // last night, 106 short
        await logNight(3, 374);
        // nights 1, 2 and 4.. are unlogged and must not count as zero sleep
        final r = SleepService.sleepDebt();
        expect(r.nights, 2);
        expect(r.debtMinutes, 212,
            reason: 'two nights, each 106 short, equal deficits so the weights '
                'cancel; the unlogged nights add nothing');
      });
    });

    test('is what the pure calculation says for the same nights', () async {
      await withClock(Clock.fixed(_now), () async {
        final ages = {0: 357, 1: 391, 2: 357, 5: 408, 9: 289, 13: 476};
        for (final e in ages.entries) {
          await logNight(e.key, e.value);
        }
        final expected = SleepDebt.compute(
          nights: [
            for (final e in ages.entries)
              (ageDays: e.key, asleepMinutes: e.value)
          ],
          targetMinutes: SleepService.getSchedule().targetMinutes,
        );
        final r = SleepService.sleepDebt();
        expect(r.debtMinutes, expected.debtMinutes);
        expect(r.nights, expected.nights);
      });
    });

    test('a night 14 mornings ago is outside the window', () async {
      await withClock(Clock.fixed(_now), () async {
        await logNight(14, 238);
        expect(SleepService.sleepDebt().nights, 0);
      });
    });

    test('the plain seven-night figure is untouched', () async {
      await withClock(Clock.fixed(_now), () async {
        await logNight(0, 374);
        await logNight(1, 374);
        // plain: target*2 - slept = 960 - 748
        expect(SleepService.sleepDebtMinutes(), 212);
      });
    });
  });

  group('InsightEngine.sleep', () {
    const behind = SleepDebtResult(
        debtMinutes: 260, nights: 12, catchUp: SleepCatchUp(40, 7));

    test('with a weighted debt, the behind note quotes it and the plan', () {
      final i = InsightEngine.sleep(
        lastNightMinutes: 470,
        targetMinutes: 480,
        weightedDebt: behind,
      )!;
      expect(i.id, 'sleep_balance_low');
      expect(i.detail, contains('4h 20m behind over 12 nights'));
      expect(i.detail, contains('about 40 extra minutes a night for a week'));
      expect(i.metric, '4h 20m behind');
    });

    test('too few nights stays quiet, whatever the plain figure says', () {
      final i = InsightEngine.sleep(
        lastNightMinutes: 470,
        targetMinutes: 480,
        debtMinutes: 3000,
        loggedNights: 7,
        weightedDebt: const SleepDebtResult(
            debtMinutes: 260, nights: 3, catchUp: SleepCatchUp(40, 7)),
      );
      expect(i?.id, isNot('sleep_balance_low'));
    });

    test('a small weighted debt stays quiet even if the plain figure is big',
        () {
      final i = InsightEngine.sleep(
        lastNightMinutes: 470,
        targetMinutes: 480,
        debtMinutes: 600,
        loggedNights: 7,
        weightedDebt: const SleepDebtResult(
            debtMinutes: 60, nights: 10, catchUp: SleepCatchUp(10, 7)),
      );
      expect(i?.id, isNot('sleep_balance_low'));
    });

    test('without a weighted debt the old behaviour is unchanged', () {
      final i = InsightEngine.sleep(
        lastNightMinutes: 470,
        targetMinutes: 480,
        debtMinutes: 600,
        loggedNights: 7,
      )!;
      expect(i.id, 'sleep_balance_low');
      expect(i.detail, contains('10h under your target'));
    });
  });

  group('CoachText.sleepTip', () {
    const behind = SleepDebtResult(
        debtMinutes: 260, nights: 12, catchUp: SleepCatchUp(40, 7));

    test('uses the weighted line when given', () {
      final t = const CoachText().sleepTip(
        lastNightMinutes: 420,
        targetMinutes: 480,
        debtMinutes: 0,
        regularity: 1,
        weightedDebt: behind,
      );
      expect(t, contains('4h 20m behind over 12 nights'));
      expect(t, contains('7h 0m last night'));
    });

    test('does not mention debt below the nights gate', () {
      final t = const CoachText().sleepTip(
        lastNightMinutes: 420,
        targetMinutes: 480,
        debtMinutes: 0,
        regularity: 1,
        weightedDebt: const SleepDebtResult(
            debtMinutes: 260, nights: 3, catchUp: SleepCatchUp(40, 7)),
      );
      expect(t, isNot(contains('behind over')));
    });
  });

  group('the dashboard', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 4000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exception.toString().contains('overflowed by')) return;
        prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const SleepDashboardScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('a short fortnight says how far behind and what clears it',
        (tester) async {
      await withClock(Clock.fixed(_now), () async {
        // Seven nights, 60 minutes under: behind, and a plan to clear it.
        for (var i = 0; i < 7; i++) {
          await logNight(i, 425); // 425 = 25 x 17; 55 short
        }
        await pump(tester);
        expect(find.text('A little behind on rest'), findsOneWidget);
        expect(find.textContaining('behind over 7 nights'), findsWidgets);
        expect(find.textContaining('extra minutes a night for'), findsWidgets);
      });
    });
  });
}
