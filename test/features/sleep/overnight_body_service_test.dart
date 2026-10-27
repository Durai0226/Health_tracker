/// The overnight body check and heart-rate dip, read from the stored daily
/// biometrics and the night's sleep, and the offer of a rest day.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/overnight_body.dart';
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_day.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_metric.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/services/overnight_body_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  // Mid-morning today: last night has just ended. The real date, not a pinned
  // one: the biometrics store keeps a window of days relative to the wall clock
  // when it loads, so days from a fixed past date would simply not be loaded.
  final real = DateTime.now();
  final now = DateTime(real.year, real.month, real.day, 9);

  DateTime dayAgo(int n) => DateTime(now.year, now.month, now.day - n);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    BiometricsService.clearInMemory();
    await BiometricsService.resetForTesting();
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> day(
    int ago, {
    int? rest,
    double? hrv,
    HrvMetric hrvMetric = HrvMetric.rmssd,
    double? spo2,
    double? resp,
    double? skin,
    SkinTempMetric? skinMetric,
    double? bodyTemp,
    List<int?> hourly = const [],
  }) async {
    final d = dayAgo(ago);
    await database.biometricsDao.upsertDay(BiometricDay(
      id: key(d),
      date: d,
      createdAt: d,
      updatedAt: d,
      restingHr: rest,
      hrvNightlyMs: hrv,
      hrvMetric: hrv == null ? null : hrvMetric,
      spo2Avg: spo2,
      respiratoryRateAvg: resp,
      skinTempC: skin,
      skinTempMetric: skin == null ? null : skinMetric,
      bodyTempAvgC: bodyTemp,
      hourlyHr: hourly,
    ).toCompanion());
  }

  Future<void> load() => BiometricsService.reloadFromDb();

  /// Fourteen ordinary days before today (1..14 ago), with a little spread.
  Future<void> ordinaryHistory({
    HrvMetric hrvMetric = HrvMetric.rmssd,
    SkinTempMetric? skinMetric,
    int from = 1,
    int to = 14,
  }) async {
    for (var ago = from; ago <= to; ago++) {
      final s = ago.isEven ? 1 : -1;
      await day(ago,
          rest: 56 + s,
          hrv: 45.0 + 4 * s,
          hrvMetric: hrvMetric,
          spo2: 96.0 + s,
          resp: 14.0 + 0.4 * s,
          skin: skinMetric == null ? null : 0.0 + 0.2 * s,
          skinMetric: skinMetric);
    }
  }

  Future<R> at<R>(Future<R> Function() body) =>
      withClock(Clock.fixed(now), body);

  group('the check', () {
    test('counts the signals outside their usual, out of those it could check',
        () async {
      await ordinaryHistory();
      await day(0, rest: 66, hrv: 45, spo2: 91, resp: 14);
      await load();

      final c = OvernightBody.checkFor(now)!;
      expect(c.checked, 4);
      expect(c.outside, 2);
      expect(c.headline, '2 of 4 overnight signals are outside your usual range.');
      expect(c.outsideSignals.map((s) => s.signal),
          [BodySignal.restingHr, BodySignal.bloodOxygen]);
    });

    test('last night is not part of its own usual', () async {
      await ordinaryHistory();
      // 94.9 is just under the usual 94.96-97.04. Counted into its own range it
      // would pull the floor down to 94.87 and slip inside.
      await day(0, rest: 56, spo2: 94.9, resp: 14);
      await load();
      expect(OvernightBody.checkFor(now)!.outsideSignals.single.signal,
          BodySignal.bloodOxygen);
    });

    test('only the 28 days before count, not older ones', () async {
      await ordinaryHistory(from: 1, to: 6); // six days: not enough for a range
      for (var ago = 29; ago <= 34; ago++) {
        await day(ago, rest: 56 + (ago.isEven ? 1 : -1), spo2: 96.0 + (ago.isEven ? 1 : -1), resp: 14);
      }
      await day(0, rest: 56, spo2: 96, resp: 14);
      await load();

      expect(OvernightBody.checkFor(now), isNull,
          reason: 'six days in the window is not a range; the six from a month '
              'back are outside it and cannot help make one up');
    });

    test('nothing without last night\'s data', () async {
      await ordinaryHistory();
      await load();
      expect(OvernightBody.checkFor(now), isNull);
    });

    test('nothing with a week of history missing', () async {
      await ordinaryHistory(from: 1, to: 5);
      await day(0, rest: 70, spo2: 96, resp: 14);
      await load();
      expect(OvernightBody.checkFor(now), isNull);
    });

    test('HRV is compared with the SAME statistic only', () async {
      // The history is SDNN; last night is RMSSD: not comparable, so not used.
      await ordinaryHistory(hrvMetric: HrvMetric.sdnn);
      await day(0, rest: 56, hrv: 20, hrvMetric: HrvMetric.rmssd, spo2: 96, resp: 14);
      await load();
      final c = OvernightBody.checkFor(now)!;
      expect(c.signals.map((s) => s.signal), isNot(contains(BodySignal.hrv)));
    });

    test('a skin temperature that is a change from baseline is its own signal',
        () async {
      await ordinaryHistory(skinMetric: SkinTempMetric.deltaFromBaseline);
      await day(0,
          rest: 56,
          spo2: 96,
          skin: 0.8,
          skinMetric: SkinTempMetric.deltaFromBaseline);
      await load();
      final c = OvernightBody.checkFor(now)!;
      final t = c.signals.singleWhere(
          (s) => s.signal == BodySignal.temperatureChange);
      expect(t.isOutside, isTrue);
      expect(t.valueText, '+0.8 °C');
    });

    test('an absolute one is compared with absolutes, never with changes',
        () async {
      await ordinaryHistory(skinMetric: SkinTempMetric.deltaFromBaseline);
      await day(0,
          rest: 56, spo2: 96, skin: 33.4, skinMetric: SkinTempMetric.absolute);
      await load();
      final c = OvernightBody.checkFor(now)!;
      expect(c.signals.map((s) => s.signal),
          isNot(contains(BodySignal.temperature)),
          reason: 'there are no absolute readings before last night');
      expect(c.signals.map((s) => s.signal),
          isNot(contains(BodySignal.temperatureChange)));
    });
  });

  group('the heart-rate dip', () {
    List<int?> hourly({int night = 55, int daytime = 70}) => [
          for (var h = 0; h < 24; h++) (h >= 9 && h < 21) ? daytime : night
        ];

    test('from the hourly rates and the night\'s sleep', () async {
      await day(1, hourly: hourly());
      await day(0, hourly: hourly());
      await load();
      await at(() => SleepService.logManualSession(
            bedtime: dayAgo(1).add(const Duration(hours: 23)),
            wakeTime: dayAgo(0).add(const Duration(hours: 7)),
          ));

      final d = OvernightBody.dipFor(now)!;
      expect(d.dayAvg, 70);
      expect(d.nightAvg, 55);
      expect(d.dipPercent, 21);
    });

    test('nothing without the night\'s sleep, or the hourly rates', () async {
      await day(1, hourly: hourly());
      await day(0, hourly: hourly());
      await load();
      expect(OvernightBody.dipFor(now), isNull, reason: 'no sleep logged');

      await at(() => SleepService.logManualSession(
            bedtime: dayAgo(1).add(const Duration(hours: 23)),
            wakeTime: dayAgo(0).add(const Duration(hours: 7)),
          ));
      await day(1);
      await load();
      expect(OvernightBody.dipFor(now), isNull, reason: 'no hourly rates');
    });
  });

  group('the rest-day offer', () {
    /// Today and yesterday both with [outside] of four signals off.
    Future<void> twoNights({int todayOff = 3, int yesterdayOff = 3}) async {
      await ordinaryHistory(from: 2, to: 16);
      Future<void> night(int ago, int off) => day(ago,
          rest: off >= 1 ? 70 : 56,
          hrv: off >= 2 ? 20 : 45,
          spo2: off >= 3 ? 90 : 96,
          resp: off >= 4 ? 19 : 14);
      await night(0, todayOff);
      await night(1, yesterdayOff);
      await load();
    }

    test('two nights in a row with most signals off', () async {
      await twoNights();
      expect(OvernightBody.restOffered(now: now), isTrue);
    });

    test('one such night is not enough', () async {
      await twoNights(yesterdayOff: 1);
      expect(OvernightBody.restOffered(now: now), isFalse);
    });

    test('two signals off is not most of them', () async {
      await twoNights(todayOff: 2, yesterdayOff: 2);
      expect(OvernightBody.restOffered(now: now), isFalse);
    });

    test('and not once today is already a rest day', () async {
      await twoNights();
      await RestDayStore.markToday(RestKind.rest, now: now);
      expect(OvernightBody.restOffered(now: now), isFalse);
    });

    test('and not with fewer than four signals to go on', () async {
      await ordinaryHistory(from: 2, to: 16);
      for (final ago in [0, 1]) {
        await day(ago, rest: 70, spo2: 90, hrv: 20); // three signals, all off
      }
      await load();
      expect(OvernightBody.restOffered(now: now), isFalse);
    });
  });

  group('on the Sleep screen', () {
    Future<void> open(WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (_) async => <String, dynamic>{},
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/device_info'), null));
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 6000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const SleepDashboardScreen()));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
    }

    Future<void> twoBadNights() async {
      await ordinaryHistory(from: 2, to: 16);
      for (final ago in [0, 1]) {
        await day(ago, rest: 70, hrv: 20, spo2: 90, resp: 14);
      }
      await load();
      await SleepService.logManualSession(
        bedtime: dayAgo(1).add(const Duration(hours: 23)),
        wakeTime: dayAgo(0).add(const Duration(hours: 7)),
      );
    }

    testWidgets('the card says what was off, and nothing is hidden behind a score',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await twoBadNights();
        await open(tester);

        expect(find.text('Overnight body check'), findsOneWidget);
        expect(find.text('3 of 4 overnight signals are outside your usual range.'),
            findsOneWidget);
        expect(find.textContaining('Resting heart rate: 70 bpm'), findsOneWidget);
        expect(find.textContaining('not a diagnosis'), findsOneWidget);
      });
    });

    testWidgets('a rest day is offered, taken, and taken back', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await twoBadNights();
        await open(tester);

        expect(find.text('Take a rest day'), findsOneWidget);
        expect(RestDayStore.kindToday(now: now), isNull,
            reason: 'offered, never done for them');

        await tester.tap(find.text('Take a rest day'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(RestDayStore.kindToday(now: now), RestKind.rest);
        expect(find.text('Today is marked as a rest day.'), findsOneWidget);

        await tester.tap(find.text('Undo'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(RestDayStore.kindToday(now: now), isNull);
        expect(find.text('Take a rest day'), findsOneWidget);
      });
    });

    testWidgets('no wearable data, no card', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await SleepService.logManualSession(
          bedtime: dayAgo(1).add(const Duration(hours: 23)),
          wakeTime: dayAgo(0).add(const Duration(hours: 7)),
        );
        await open(tester);
        expect(find.text('Overnight body check'), findsNothing);
      });
    });
  });
}
