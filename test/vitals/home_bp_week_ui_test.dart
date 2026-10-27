/// The home-BP week on the Blood pressure screen and in its service: offered,
/// started (with reminders only if asked), tracked, finished, put away.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/services/home_bp_week_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/medication/widgets/home_bp_week_card.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  // A Wednesday afternoon, day 3 of a week that began on Monday 1 June.
  final now = DateTime(2026, 6, 3, 14, 0);
  final monday = DateTime(2026, 6, 1);

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

  var seq = 0;
  Future<void> bp(DateTime at, int s, int d) =>
      VitalsStorageService.saveBp(BloodPressureReading(
          id: 'b${seq++}', systolic: s, diastolic: d, takenAt: at, createdAt: at));

  /// A morning and an evening session on each of [days] (1-based).
  Future<void> sessions(Iterable<int> days, {int s = 124, int d = 80}) async {
    for (final day in days) {
      await bp(DateTime(2026, 6, day, 8, 0), s, d);
      await bp(DateTime(2026, 6, day, 8, 1), s, d);
      await bp(DateTime(2026, 6, day, 20, 0), s + 4, d + 2);
      await bp(DateTime(2026, 6, day, 20, 1), s + 4, d + 2);
    }
  }

  group('the service', () {
    test('no week until one is started', () {
      expect(HomeBpWeekService.start, isNull);
      expect(HomeBpWeekService.current(const []), isNull);
    });

    test('begin sets the first day, and the week is under way', () async {
      await withClock(Clock.fixed(now), () async {
        await HomeBpWeekService.begin(
            morningReminder: false, eveningReminder: false, day: monday);
        expect(HomeBpWeekService.start, monday);
        final p = HomeBpWeekService.current(const [])!;
        expect(p.dayNumber, 3);
        expect(p.ended, isFalse);
      });
    });

    test('reminders are switched on only when asked for', () async {
      await HomeBpWeekService.begin(
          morningReminder: true, eveningReminder: false, day: monday);
      expect(VitalsReminderService.isEnabled(VitalsReminderService.bp), isTrue);
      expect(VitalsReminderService.isEnabled(VitalsReminderService.bpEvening),
          isFalse);
      expect(scheduler.armedIds, contains(VitalsReminderService.bp.id));
      expect(scheduler.armedIds, isNot(contains(VitalsReminderService.bpEvening.id)));
    });

    test('neither switched on means neither is touched', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      expect(scheduler.scheduled, isEmpty);
      expect(VitalsReminderService.isEnabled(VitalsReminderService.bp), isFalse);
    });

    test('a finished week is shown until it is put away', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      final later = DateTime(2026, 6, 9, 9);
      await withClock(Clock.fixed(later), () async {
        expect(HomeBpWeekService.current(const [])!.ended, isTrue);
        await HomeBpWeekService.close();
        expect(HomeBpWeekService.current(const []), isNull);
      });
    });

    test('closing a running week does not end it', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await withClock(Clock.fixed(now), () async {
        await HomeBpWeekService.close();
        expect(HomeBpWeekService.current(const []), isNotNull);
      });
    });

    test('stop clears it, finished or not', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await HomeBpWeekService.stop();
      expect(HomeBpWeekService.start, isNull);
      expect(HomeBpWeekService.current(const []), isNull);
    });

    test('a new week after a closed one is open again', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await withClock(Clock.fixed(DateTime(2026, 6, 9, 9)), () async {
        await HomeBpWeekService.close();
        await HomeBpWeekService.begin(
            morningReminder: false,
            eveningReminder: false,
            day: DateTime(2026, 6, 9));
        expect(HomeBpWeekService.current(const [])!.ended, isFalse);
      });
    });

    test('it is one person\'s week, not the household\'s', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await ActiveProfileService().setActiveDependent('dep1');
      expect(HomeBpWeekService.start, isNull,
          reason: 'someone else\'s readings must not fill in this week');
      await ActiveProfileService().setActiveDependent(null);
      expect(HomeBpWeekService.start, monday);
    });

    test('the summary says what it is, in words fit to paste', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      final readings = [
        for (var day = 2; day <= 6; day++) ...[
          BloodPressureReading(id: 'a$day', systolic: 126, diastolic: 80,
              takenAt: DateTime(2026, 6, day, 8), createdAt: now),
          BloodPressureReading(id: 'b$day', systolic: 132, diastolic: 84,
              takenAt: DateTime(2026, 6, day, 20), createdAt: now),
        ],
      ];
      await withClock(Clock.fixed(DateTime(2026, 6, 9, 9)), () async {
        final text = HomeBpWeekService.summaryText(
            HomeBpWeekService.current(readings)!);
        expect(text, contains('Home blood pressure, Jun 1 to Jun 7, 2026'));
        expect(text, contains('Average: 129/82 mmHg (Stage 1 High range) from '
            '10 sessions on 5 days; the first day is left out.'));
        expect(text, contains('Morning 126/80 · Evening 132/84'));
        expect(text, contains('not a diagnosis'));
      });
    });

    test('and says "so far" while it is not yet enough', () async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      final readings = [
        BloodPressureReading(id: 'a', systolic: 126, diastolic: 80,
            takenAt: DateTime(2026, 6, 2, 8), createdAt: now),
      ];
      await withClock(Clock.fixed(now), () async {
        final text = HomeBpWeekService.summaryText(
            HomeBpWeekService.current(readings)!);
        expect(text, contains('So far: 126/80 mmHg'));
        expect(text, contains('from 1 session on 1 day'));
      });
    });
  });

  group('on the Blood pressure screen', () {
    void pinned(String name, Future<void> Function(WidgetTester) body,
            {DateTime? at}) =>
        testWidgets(name,
            (tester) => withClock(Clock.fixed(at ?? now), () => body(tester)));

    Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester, {double width = 430}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 4000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const BloodPressureScreen()));
        await pumpFor(tester, 8);
      } finally {
        FlutterError.onError = prev;
      }
    }

    pinned('it is offered, in words, once there are readings', (tester) async {
      await bp(DateTime(2026, 6, 3, 8), 120, 80);
      await open(tester);

      expect(find.text('Home BP week'), findsOneWidget);
      expect(find.textContaining('Seven days, a reading morning and evening'),
          findsOneWidget);
      expect(find.text('Start a week'), findsOneWidget);
    });

    pinned('Start asks about reminders, both on as an offer', (tester) async {
      await bp(DateTime(2026, 6, 3, 8), 120, 80);
      await open(tester);

      await tester.tap(find.text('Start a week'));
      await pumpFor(tester);
      expect(find.text('Start a home BP week'), findsOneWidget);
      expect(find.text('Morning reminder'), findsOneWidget);
      expect(find.text('Evening reminder'), findsOneWidget);
      // Nothing has been switched on by merely looking.
      expect(scheduler.scheduled, isEmpty);

      await tester.tap(find.text('Start'));
      await pumpFor(tester, 10);

      expect(HomeBpWeekService.start, DateTime(2026, 6, 3));
      expect(find.text('Day 1 of 7'), findsOneWidget);
      expect(scheduler.armedIds, containsAll([
        VitalsReminderService.bp.id,
        VitalsReminderService.bpEvening.id,
      ]));
    });

    pinned('and each can be declined', (tester) async {
      await bp(DateTime(2026, 6, 3, 8), 120, 80);
      await open(tester);

      await tester.tap(find.text('Start a week'));
      await pumpFor(tester);
      await tester.tap(find.text('Morning reminder'));
      await tester.pump();
      await tester.tap(find.text('Evening reminder'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await pumpFor(tester, 10);

      expect(find.text('Day 1 of 7'), findsOneWidget);
      expect(scheduler.scheduled, isEmpty);
    });

    pinned('under way: the day, what is due, and the average so far',
        (tester) async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await sessions([2]);
      await open(tester);

      expect(find.text('Day 3 of 7'), findsOneWidget);
      expect(find.text('Due now: your evening readings.'), findsOneWidget,
          reason: 'it is two in the afternoon and today\'s morning is gone');
      expect(find.textContaining('So far: 126/81 from 2 sessions'), findsOneWidget);
    });

    pinned('the dots say what was taken', (tester) async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await sessions([1, 2]);
      await open(tester);

      // By the label the widget declares: `bySemanticsLabel` needs the semantics
      // tree switched on, and what is under test is what the dot says.
      Finder dot(String label) => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label);
      expect(dot('Day 1 morning: taken'), findsOneWidget);
      expect(dot('Day 2 evening: taken'), findsOneWidget);
      expect(dot('Day 3 morning: missed'), findsOneWidget);
      expect(dot('Day 3 evening: to do'), findsOneWidget);
      expect(dot('Day 6 morning: to do'), findsOneWidget);
    });

    pinned('stopping asks first, and keeps the readings', (tester) async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await sessions([2]);
      await open(tester);

      await tester.tap(find.text('Stop this week'));
      await pumpFor(tester);
      expect(find.text('Stop this home week?'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await pumpFor(tester);
      expect(find.text('Day 3 of 7'), findsOneWidget);

      await tester.tap(find.text('Stop this week'));
      await pumpFor(tester);
      await tester.tap(find.text('Stop week'));
      await pumpFor(tester, 10);

      expect(find.text('Start a week'), findsOneWidget);
      expect(await VitalsStorageService.getAllBp(), hasLength(4));
    });

    pinned('finished: the average, its range, and a way to copy it', (tester) async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await sessions([1, 2, 3, 4, 5, 6, 7], s: 128, d: 82);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester);

      expect(find.text('Your home week'), findsOneWidget);
      Finder inCard(Finder f) =>
          find.descendant(of: find.byType(HomeBpWeekCard), matching: f);
      expect(inCard(find.text('130/83')), findsOneWidget);
      expect(find.text('Stage 1 High range'), findsOneWidget);
      expect(find.textContaining('From 12 sessions on 6 days'), findsOneWidget);

      await tester.tap(find.text('Copy summary'));
      await pumpFor(tester);
      expect(copied, contains('Average: 130/83 mmHg'));
      expect(find.text('Summary copied'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await pumpFor(tester, 10);
      expect(find.text('Your home week'), findsNothing);
      expect(find.text('Start a week'), findsOneWidget);
    }, at: DateTime(2026, 6, 9, 9));

    pinned('finished with too little: says so, no big number', (tester) async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await sessions([2, 3]);
      await open(tester);

      expect(find.text('Your home week'), findsOneWidget);
      expect(find.textContaining('Not quite enough for a home average'),
          findsOneWidget);
      expect(find.text('Copy summary'), findsOneWidget,
          reason: 'what there is can still be shown');
    }, at: DateTime(2026, 6, 9, 9));

    pinned('the card fits at 320pt with large text', (tester) async {
      await HomeBpWeekService.begin(
          morningReminder: false, eveningReminder: false, day: monday);
      await sessions([1, 2]);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 6000);
      addTearDown(tester.view.reset);

      final reports = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const BloodPressureScreen()));
        await pumpFor(tester, 8);
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.text('Day 3 of 7'), findsOneWidget,
          reason: 'on screen, or this proved nothing');
      expect(reports.where((r) => r.contains('home_bp_week_card.dart')), isEmpty);
    });
  });
}
