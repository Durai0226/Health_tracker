/// "What moves your sleep", read from the real logs: the night's sleep, and what
/// the day before it held.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/insights/services/insight_service.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_mover_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  // Midday, so "today" is unambiguous.
  final now = DateTime(2026, 6, 20, 12);

  DateTime dayAt(int offset, [int hour = 0]) =>
      DateTime(2026, 6, 20 + offset, hour);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.resetForTesting();
    await StepService.resetForTesting();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  /// The night that ENDS on the morning of [wake] (an offset from today):
  /// [hours] hours in bed, which a manual log reads as about 88% asleep.
  Future<void> night(int wake, double hours) => SleepService.logManualSession(
        bedtime: dayAt(wake, 7).subtract(Duration(minutes: (hours * 60).round())),
        wakeTime: dayAt(wake, 7),
      );

  Future<void> coffeeAt(int day, int hour) async {
    final coffee = WaterService.getBeverage('coffee')!;
    await WaterService.addWaterLogForDate(
        date: dayAt(day), amountMl: 250, beverage: coffee, time: dayAt(day, hour));
  }

  Future<void> waterAt(int day, int hour) async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLogForDate(
        date: dayAt(day), amountMl: 250, beverage: water, time: dayAt(day, hour));
  }

  Future<void> run(Future<void> Function() body) =>
      withClock(Clock.fixed(now), body);

  group('the nights, with what the day before held', () {
    test('late caffeine is 20 mg or more from 14:00', () async {
      await run(() async {
        await night(-1, 8);
        await coffeeAt(-2, 15); // the day before that night
        final n = SleepMovers.nights(now: now).single;
        expect(n.lateCaffeine, isTrue);
      });
    });

    test('a morning coffee is not late', () async {
      await run(() async {
        await night(-1, 8);
        await coffeeAt(-2, 9);
        await waterAt(-2, 16);
        expect(SleepMovers.nights(now: now).single.lateCaffeine, isFalse);
      });
    });

    test('a day with nothing logged is UNKNOWN, not "no caffeine"', () async {
      await run(() async {
        await night(-1, 8);
        final n = SleepMovers.nights(now: now).single;
        expect(n.lateCaffeine, isNull);
        expect(n.eveningAlcohol, isNull);
        expect(n.activeDay, isNull);
      });
    });

    test('a day whose drinks were all deleted is unknown again', () async {
      await run(() async {
        await night(-1, 8);
        await coffeeAt(-2, 15);
        final day = WaterService.getDataForDate(dayAt(-2))!;
        await WaterService.removeWaterLogForDate(dayAt(-2), day.logs.single.id);
        expect(SleepMovers.nights(now: now).single.lateCaffeine, isNull);
      });
    });

    test('a trace of caffeine (under 20 mg) is not late caffeine', () async {
      await run(() async {
        await night(-1, 8);
        final weak = WaterService.getBeverage('coffee')!.copyWith(caffeinePerMl: 5);
        await WaterService.addWaterLogForDate(
            date: dayAt(-2), amountMl: 250, beverage: weak, time: dayAt(-2, 15));
        expect(SleepMovers.nights(now: now).single.lateCaffeine, isFalse,
            reason: '12 mg: under the 20 mg that is worth a word');
      });
    });

    test('an evening drink with alcohol, from 17:00', () async {
      await run(() async {
        await night(-1, 8);
        await night(-3, 8);
        final beer = WaterService.getBeverage('beer')!;
        await WaterService.addWaterLogForDate(
            date: dayAt(-2), amountMl: 330, beverage: beer, time: dayAt(-2, 20));
        await WaterService.addWaterLogForDate(
            date: dayAt(-4), amountMl: 330, beverage: beer, time: dayAt(-4, 12));
        final byNight = {
          for (final n in SleepMovers.nights(now: now)) n.night.day: n.eveningAlcohol,
        };
        expect(byNight[19], isTrue, reason: 'beer at 20:00 the day before');
        expect(byNight[17], isFalse, reason: 'a lunchtime beer is not an evening one');
      });
    });

    test('a night with no sleep logged is not a night', () async {
      await run(() async {
        await coffeeAt(-2, 15);
        expect(SleepMovers.nights(now: now), isEmpty);
      });
    });

    test('an active day is one that met its step goal', () async {
      await run(() async {
        await night(-1, 8);
        StepService.storeHealthDayForTesting(dayAt(-2, 12), 20000, isToday: false);
        expect(SleepMovers.nights(now: now).single.activeDay, isTrue);
      });
    });

    test('a day with steps short of the goal is not active', () async {
      await run(() async {
        await night(-1, 8);
        StepService.storeHealthDayForTesting(dayAt(-2, 12), 500, isToday: false);
        expect(SleepMovers.nights(now: now).single.activeDay, isFalse);
      });
    });

    test('the sleep is the minutes asleep', () async {
      await run(() async {
        await night(-1, 8);
        final n = SleepMovers.nights(now: now).single;
        expect(n.asleepMinutes, greaterThan(400));
        expect(n.asleepMinutes, lessThan(480));
      });
    });
  });

  group('the patterns', () {
    /// Six nights after late caffeine at 6 h in bed, and six after none at 8 h.
    Future<void> seed() async {
      for (var i = 0; i < 6; i++) {
        final wake = -1 - i;
        await night(wake, 6);
        await coffeeAt(wake - 1, 15);
      }
      for (var i = 0; i < 6; i++) {
        final wake = -8 - i;
        await night(wake, 8);
        await waterAt(wake - 1, 15);
      }
    }

    test('late caffeine and shorter nights become an insight', () async {
      await run(() async {
        await seed();
        final i = SleepMovers.insights(now: now)
            .singleWhere((x) => x.id == 'sleep_mover_late_caffeine');
        expect(i.title, contains('caffeine after 2 pm'));
        expect(i.title, contains('less'));
        expect(i.evidence!.line, startsWith('Based on 6 vs 6 nights'));
      });
    });

    test('and it reaches Trends through the insight service', () async {
      await run(() async {
        await seed();
        final all = await InsightService.gatherAll();
        expect(all.map((i) => i.id), contains('sleep_mover_late_caffeine'));
      });
    });

    test('too few nights say nothing', () async {
      await run(() async {
        for (var i = 0; i < 4; i++) {
          await night(-1 - i, 6);
          await coffeeAt(-2 - i, 15);
        }
        for (var i = 0; i < 6; i++) {
          await night(-8 - i, 8);
          await waterAt(-9 - i, 15);
        }
        expect(SleepMovers.insights(now: now), isEmpty);
      });
    });
  });

  testWidgets('the Sleep screen shows them', (tester) async {
    // The health probe awaits this channel; unanswered, the screen never leaves
    // its loading skeleton under FakeAsync.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (_) async => <String, dynamic>{},
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/device_info'), null));
    await withClock(Clock.fixed(now), () async {
      for (var i = 0; i < 6; i++) {
        await night(-1 - i, 6);
        await coffeeAt(-2 - i, 15);
      }
      for (var i = 0; i < 6; i++) {
        await night(-8 - i, 8);
        await waterAt(-9 - i, 15);
      }
      await night(0, 7);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 6000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const SleepDashboardScreen()));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.text('What moves your sleep'), findsOneWidget);
      expect(find.textContaining('caffeine after 2 pm'), findsWidgets);
    });
  });
}
