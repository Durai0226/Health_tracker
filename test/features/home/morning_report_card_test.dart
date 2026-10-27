/// The Morning report on Today: until noon, once a day, from the real logs.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';
import 'package:tablet_remainder/features/home/services/morning_report_service.dart';
import 'package:tablet_remainder/features/home/widgets/morning_report_card.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  // Today at 08:00, real date: the stores keep windows relative to the wall clock.
  final real = DateTime.now();
  final morning = DateTime(real.year, real.month, real.day, 8);
  DateTime dayAgo(int n) => DateTime(real.year, real.month, real.day - n);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.resetForTesting();
    BiometricsService.clearInMemory();
    await BiometricsService.resetForTesting();
  });

  tearDown(() async => database.close());

  /// A night that ended on the morning [ago] days back, [hours] in bed.
  Future<void> night(int ago, double hours) => SleepService.logManualSession(
        bedtime: dayAgo(ago)
            .add(const Duration(hours: 7))
            .subtract(Duration(minutes: (hours * 60).round())),
        wakeTime: dayAgo(ago).add(const Duration(hours: 7)),
      );

  Future<void> usualWeek() async {
    for (var ago = 1; ago <= 7; ago++) {
      await night(ago, 8);
    }
  }

  group('the service', () {
    test('a short night against a usual one, this morning', () async {
      await usualWeek();
      await night(0, 6);
      final r = MorningReportService.today(now: morning)!;
      expect(r.lines.first, contains('under your usual'));
      expect(r.suggestion, isNotNull);
    });

    test('not after noon', () async {
      await usualWeek();
      await night(0, 6);
      expect(
          MorningReportService.today(
              now: DateTime(real.year, real.month, real.day, 12)),
          isNull);
      expect(
          MorningReportService.today(
              now: DateTime(real.year, real.month, real.day, 11, 59)),
          isNotNull);
    });

    test('not when the last night ended yesterday: nothing happened this morning',
        () async {
      await usualWeek();
      expect(MorningReportService.today(now: morning), isNull);
    });

    test('no sleep at all is no report', () {
      expect(MorningReportService.today(now: morning), isNull);
    });

    test('"your usual" is the nights before, not last night itself', () async {
      for (var ago = 1; ago <= 6; ago++) {
        await night(ago, 8);
      }
      await night(0, 4);
      final r = MorningReportService.today(now: morning)!;
      // Six earlier nights: the usual is about 7h 3xm, and last night is far under.
      expect(r.lines.first, contains('usual 7h'));
    });

    test('only the last fortnight makes the usual', () async {
      for (var ago = 1; ago <= 7; ago++) {
        await night(ago, 8);
      }
      for (var ago = 16; ago <= 22; ago++) {
        await night(ago, 4); // long ago, very short: not "usual" any more
      }
      await night(0, 6);
      expect(MorningReportService.today(now: morning)!.lines.first,
          contains('usual 7h'));
    });

    test('putting it away lasts the day, and only the day', () async {
      await usualWeek();
      await night(0, 6);
      await MorningReportService.dismissToday(now: morning);
      expect(MorningReportService.today(now: morning), isNull);

      final tomorrow = morning.add(const Duration(days: 1));
      // Tomorrow's night, as the service would see it.
      expect(MorningReportService.dismissedToday(now: tomorrow), isFalse);
    });
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester, {double width = 430, double scale = 1}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 2400);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SingleChildScrollView(child: MorningReportCard()))));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows the lines and the one suggestion', (tester) async {
      await withClock(Clock.fixed(morning), () async {
        await usualWeek();
        await night(0, 6);
        await pump(tester);

        expect(find.text('Morning report'), findsOneWidget);
        expect(find.textContaining('under your usual'), findsOneWidget);
        // The night left a debt against the target, which outranks "a short
        // night" in the one suggestion.
        expect(find.textContaining('extra minutes of sleep tonight'),
            findsOneWidget);
        expect(find.textContaining('A short night'), findsNothing,
            reason: 'one suggestion, not two');
      });
    });

    testWidgets('shows nothing when there is nothing to say', (tester) async {
      await withClock(Clock.fixed(morning), () async {
        await pump(tester);
        expect(find.text('Morning report'), findsNothing);
      });
    });

    testWidgets('dismissing puts it away for the day', (tester) async {
      await withClock(Clock.fixed(morning), () async {
        await usualWeek();
        await night(0, 6);
        await pump(tester);

        await tester.tap(find.byTooltip('Dismiss the morning report'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Morning report'), findsNothing);

        // A fresh card, as after leaving and returning to Today.
        await tester.pumpWidget(const SizedBox());
        await pump(tester);
        expect(find.text('Morning report'), findsNothing);
      });
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('fits at 320pt and ${scale}x text', (tester) async {
        await withClock(Clock.fixed(morning), () async {
          await usualWeek();
          await night(0, 6);
          final reports = <String>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (d) => reports.add(d.toString());
          try {
            await pump(tester, width: 320, scale: scale);
          } finally {
            FlutterError.onError = prev;
          }
          expect(find.text('Morning report'), findsOneWidget);
          expect(reports.where((r) => r.contains('morning_report_card.dart')),
              isEmpty);
        });
      });
    }
  });

  test('Today has it, after the briefing and before the pulse row', () {
    final src = File('lib/features/home/screens/home_dashboard.dart').readAsStringSync();
    final briefing = src.indexOf('_buildBriefingStrip(ext),');
    final card = src.indexOf('const MorningReportCard(),');
    final pulse = src.indexOf('_buildPulseRow(ext),');
    expect(briefing, greaterThan(0));
    expect(card, greaterThan(briefing));
    expect(pulse, greaterThan(card));
  });
}
