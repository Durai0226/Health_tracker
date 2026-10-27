/// A low reading, followed up; readings, read by meal and hour; and the insulin
/// that goes with a reading.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/services/glucose_recheck.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;
  final now = DateTime(2026, 6, 30, 12, 0);

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  GlucoseReading reading(int mgdl,
          {GlucoseContext ctx = GlucoseContext.fasting,
          DateTime? at,
          double? insulin,
          String? id}) =>
      GlucoseReading(
        id: id ?? 'g${(at ?? now).microsecondsSinceEpoch}-$mgdl',
        valueMgdl: mgdl,
        context: ctx,
        takenAt: at ?? now,
        insulinUnits: insulin,
        createdAt: at ?? now,
      );

  /// Whether a recheck is armed right now: the last thing done to it was arming.
  bool recheckPending() {
    var pending = false;
    for (final op in scheduler.sequence) {
      if (op.startsWith('arm:985001@')) pending = true;
      if (op == 'cancel:985001') pending = false;
    }
    return pending;
  }

  group('the recheck itself', () {
    test('only a low or a severe low is followed up, fifteen minutes on', () {
      expect(GlucoseRecheck.dueAfter(reading(65)), now.add(const Duration(minutes: 15)));
      expect(GlucoseRecheck.dueAfter(reading(50)), now.add(const Duration(minutes: 15)));
      expect(GlucoseRecheck.dueAfter(reading(70)), isNull,
          reason: '70 is the bottom of range');
      expect(GlucoseRecheck.dueAfter(reading(69)), isNotNull);
      expect(GlucoseRecheck.dueAfter(reading(110)), isNull);
      expect(GlucoseRecheck.dueAfter(reading(300)), isNull,
          reason: 'a high is not a 15-minute matter');
    });

    test('a new low arms one reminder, in its own id, at the right time',
        () async {
      final due = await withClock(
          Clock.fixed(now), () => GlucoseRecheck.afterSave(reading(62)));

      expect(due, now.add(const Duration(minutes: 15)));
      final armed = scheduler.lastFor(GlucoseRecheck.notificationId)!;
      expect(armed.when.toUtc(), now.add(const Duration(minutes: 15)).toUtc());
      expect(armed.title, 'Recheck your blood sugar');
      expect(armed.body, isNot(contains('62')),
          reason: 'a lock screen should not carry the reading');
      expect(recheckPending(), isTrue);
    });

    test('a reading that is not low arms nothing', () async {
      final due = await withClock(
          Clock.fixed(now), () => GlucoseRecheck.afterSave(reading(110)));
      expect(due, isNull);
      expect(scheduler.scheduled, isEmpty);
    });

    test('and takes down the recheck an earlier low set: it was answered',
        () async {
      await withClock(Clock.fixed(now), () => GlucoseRecheck.afterSave(reading(62)));
      expect(recheckPending(), isTrue);

      await withClock(
          Clock.fixed(now.add(const Duration(minutes: 20))),
          () => GlucoseRecheck.afterSave(
              reading(105, at: now.add(const Duration(minutes: 20)))));

      expect(recheckPending(), isFalse);
    });

    test('a second low replaces the first rather than adding to it', () async {
      await withClock(Clock.fixed(now), () => GlucoseRecheck.afterSave(reading(62)));
      final later = now.add(const Duration(minutes: 20));
      await withClock(Clock.fixed(later),
          () => GlucoseRecheck.afterSave(reading(58, at: later)));

      final ops = scheduler.sequence
          .where((o) => o.endsWith('985001') || o.startsWith('arm:985001'))
          .toList();
      expect(ops.last, startsWith('arm:985001'));
      expect(ops[ops.length - 2], 'cancel:985001',
          reason: 'withdrawn before it is re-armed, or the old one is orphaned');
      expect(scheduler.lastFor(985001)!.when.toUtc(),
          later.add(const Duration(minutes: 15)).toUtc());
    });

    test('a low logged after the fact has nothing to wait for', () async {
      final earlier = now.subtract(const Duration(hours: 2));
      final due = await withClock(Clock.fixed(now),
          () => GlucoseRecheck.afterSave(reading(60, at: earlier)));
      expect(due, isNull);
      expect(recheckPending(), isFalse);
    });

    test('and one logged 14 minutes ago still has a minute to go', () async {
      final at = now.subtract(const Duration(minutes: 14));
      final due = await withClock(
          Clock.fixed(now), () => GlucoseRecheck.afterSave(reading(60, at: at)));
      expect(due, now.add(const Duration(minutes: 1)));
    });

    test('a reminder that could not be armed is not claimed', () async {
      scheduler.refuseExactMidCall.add(GlucoseRecheck.notificationId);
      scheduler.midCallError = StateError('the OS said no');

      final due = await withClock(
          Clock.fixed(now), () => GlucoseRecheck.afterSave(reading(62)));

      expect(due, isNull,
          reason: 'the screen would say "recheck reminder set" for one that '
              'was never set');
      expect(recheckPending(), isFalse);
    });

    test('cancel takes it down', () async {
      await withClock(Clock.fixed(now), () => GlucoseRecheck.afterSave(reading(62)));
      await GlucoseRecheck.cancel();
      expect(recheckPending(), isFalse);
    });

    test('its id clears every other reserved block', () {
      expect(GlucoseRecheck.notificationId, greaterThan(980000));
      expect(GlucoseRecheck.notificationId, lessThan(990000),
          reason: '990001 is the period family');
    });
  });

  group('on the Blood sugar screen', () {
    void pinned(String name, Future<void> Function(WidgetTester) body) =>
        testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

    Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 3000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const BloodSugarScreen()));
        await pumpFor(tester, 8);
      } finally {
        FlutterError.onError = prev;
      }
    }

    Future<void> logReading(WidgetTester tester, String value,
        {String? insulin}) async {
      // The empty state has a "Log reading" button; once there are readings the
      // screen floats a "Log" instead.
      final empty = find.text('Log reading');
      await tester.tap(empty.evaluate().isNotEmpty ? empty.first : find.text('Log'));
      await pumpFor(tester);
      await tester.enterText(find.byType(TextField).first, value);
      if (insulin != null) {
        await tester.enterText(find.widgetWithText(TextField, 'units'), insulin);
      }
      await tester.pump();
      await tester.tap(find.text('Save reading'));
      await pumpFor(tester, 10);
    }

    pinned('a new low reading says the recheck is set, and Cancel takes it back',
        (tester) async {
      await open(tester);
      await logReading(tester, '62');

      expect(find.text('Recheck reminder set for 12:15 PM'), findsOneWidget);
      expect(recheckPending(), isTrue);

      await tester.tap(find.text('Cancel'));
      await pumpFor(tester);
      expect(recheckPending(), isFalse);
    });

    pinned('a reading in range sets no recheck and says nothing of one',
        (tester) async {
      await open(tester);
      await logReading(tester, '105');

      expect(find.textContaining('Recheck reminder'), findsNothing);
      expect(scheduler.scheduled, isEmpty);
    });

    pinned('editing a low reading is not a new check', (tester) async {
      await VitalsStorageService.saveGlucose(reading(62, id: 'low1'));
      await open(tester);
      await tester.tap(find.textContaining('Low · Fasting').last);
      await pumpFor(tester);
      await tester.tap(find.text('Update reading'));
      await pumpFor(tester, 10);

      expect(find.textContaining('Recheck reminder'), findsNothing);
      expect(scheduler.scheduled, isEmpty);
    });

    pinned('a reading in mmol/L is read in mmol/L', (tester) async {
      await CleanStorageService.setAppPreference('glucose_unit', 'mmoll');
      await open(tester);
      await logReading(tester, '3.4'); // 61 mg/dL
      expect(find.text('Recheck reminder set for 12:15 PM'), findsOneWidget);
    });

    // ---- insulin -----------------------------------------------------------

    pinned('the insulin units are saved with the reading, and shown', (tester) async {
      await open(tester);
      await logReading(tester, '140', insulin: '4.5');

      final saved = (await VitalsStorageService.getAllGlucose()).single;
      expect(saved.insulinUnits, 4.5);
      expect(find.textContaining('4.5 units insulin'), findsOneWidget);
    });

    pinned('a comma is a decimal point; a whole number has no ".0"',
        (tester) async {
      await open(tester);
      await logReading(tester, '140', insulin: '4,5');
      expect((await VitalsStorageService.getAllGlucose()).single.insulinUnits, 4.5);

      await logReading(tester, '120', insulin: '6');
      expect(find.textContaining('6 units insulin'), findsOneWidget);
      expect(find.textContaining('6.0 units'), findsNothing);
    });

    pinned('left empty, there are none', (tester) async {
      await open(tester);
      await logReading(tester, '140');
      expect((await VitalsStorageService.getAllGlucose()).single.insulinUnits,
          isNull);
    });

    pinned('nonsense stays on the form and says why', (tester) async {
      await open(tester);
      for (final bad in ['abc', '0', '-3', '201']) {
        await tester.tap(find.text('Log reading').first);
        await pumpFor(tester);
        await tester.enterText(find.byType(TextField).first, '140');
        await tester.enterText(find.widgetWithText(TextField, 'units'), bad);
        await tester.pump();
        await tester.tap(find.text('Save reading'));
        await pumpFor(tester);
        expect(find.textContaining('Enter insulin units from 0.5 to 200'),
            findsOneWidget, reason: bad);
        expect(await VitalsStorageService.getAllGlucose(), isEmpty, reason: bad);
        await tester.tapAt(const Offset(5, 5)); // dismiss the sheet
        await pumpFor(tester);
      }
    });

    pinned('editing keeps the units, and emptying the field clears them',
        (tester) async {
      await VitalsStorageService.saveGlucose(reading(140, id: 'g1', insulin: 4));
      await open(tester);

      await tester.tap(find.textContaining('4 units insulin'));
      await pumpFor(tester);
      expect(find.widgetWithText(TextField, '4'), findsOneWidget);
      await tester.tap(find.text('Update reading'));
      await pumpFor(tester, 10);
      expect((await VitalsStorageService.getAllGlucose()).single.insulinUnits, 4);

      await tester.tap(find.textContaining('4 units insulin'));
      await pumpFor(tester);
      await tester.enterText(find.widgetWithText(TextField, '4'), '');
      await tester.pump();
      await tester.tap(find.text('Update reading'));
      await pumpFor(tester, 10);
      expect((await VitalsStorageService.getAllGlucose()).single.insulinUnits,
          isNull);
    });

    // ---- patterns ----------------------------------------------------------

    pinned('readings that run high after breakfast are named, in the unit shown',
        (tester) async {
      for (var i = 0; i < 6; i++) {
        await VitalsStorageService.saveGlucose(reading(200,
            ctx: GlucoseContext.afterMeal,
            at: DateTime(2026, 6, 29 - i, 9, 30)));
      }
      await open(tester);

      expect(find.text('By time of day'), findsOneWidget);
      expect(find.text('After breakfast readings often run high'), findsOneWidget);
      expect(find.textContaining('6 of 6 after breakfast readings'), findsOneWidget);
      expect(find.textContaining('200 mg/dL'), findsWidgets);
    });

    pinned('and in mmol/L for someone who reads in mmol/L', (tester) async {
      await CleanStorageService.setAppPreference('glucose_unit', 'mmoll');
      for (var i = 0; i < 6; i++) {
        await VitalsStorageService.saveGlucose(reading(198,
            ctx: GlucoseContext.afterMeal,
            at: DateTime(2026, 6, 29 - i, 9, 30)));
      }
      await open(tester);
      expect(find.textContaining('11.0 mmol/L'), findsWidgets);
      expect(find.textContaining('198 mg/dL'), findsNothing);
    });

    pinned('too few readings say nothing', (tester) async {
      for (var i = 0; i < 4; i++) {
        await VitalsStorageService.saveGlucose(reading(200,
            ctx: GlucoseContext.afterMeal,
            at: DateTime(2026, 6, 29 - i, 9, 30)));
      }
      await open(tester);
      expect(find.text('By time of day'), findsNothing);
    });
  });
}
