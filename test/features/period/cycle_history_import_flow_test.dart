/// Past periods come in from a health app and can be taken back.
///
/// `cycle_history_import_test.dart` covers which days a read means. This covers
/// what happens to them: the batch write, the Undo, and the button that asks,
/// shows what it found and only then writes — against a real in-memory database
/// and a fake health store, since headless tests cannot reach the plugin.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/period/models/flow_intensity.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/screens/cycle_history_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_dashboard.dart';
import 'package:tablet_remainder/features/period/services/cycle_history_import.dart';
import 'package:tablet_remainder/features/period/services/cycle_import_source.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/period/widgets/cycle_import_button.dart';

import '../../support/recording_notification_scheduler.dart';

/// A health store that answers from fields, and remembers what it was asked.
class FakeCycleSource implements CycleImportSource {
  FakeCycleSource({
    this.store = 'Health Connect',
    this.alreadyAllowed = false,
    this.grants = true,
    this.history = true,
    this.samples = const [],
    this.readFails = false,
    this.gate,
  });

  final String store;
  bool alreadyAllowed;
  bool grants;
  bool history;
  List<HealthDataPoint> samples;
  bool readFails;

  /// When set, [ask] waits on it — a permission sheet the person has not
  /// answered yet.
  Completer<bool>? gate;

  int asked = 0;
  int historyAsked = 0;
  final reads = <(DateTime, DateTime)>[];

  @override
  String get storeName => store;

  @override
  Future<bool> allowed() async => alreadyAllowed;

  @override
  Future<bool> ask() async {
    asked++;
    if (gate != null) return gate!.future;
    return grants;
  }

  @override
  Future<bool> fullHistory() async {
    historyAsked++;
    return history;
  }

  @override
  Future<List<HealthDataPoint>?> read(DateTime from, DateTime to) async {
    reads.add((from, to));
    return readFails ? null : samples;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final now = DateTime(2026, 9, 30, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    PeriodService.clearInMemory();
    await PeriodService.resetForTesting();
    await PeriodService.init();
  });

  tearDown(() async => db.close());

  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  HealthDataPoint flow(DateTime at, MenstrualFlow level) => HealthDataPoint(
        uuid: 'f-${at.millisecondsSinceEpoch}',
        value: MenstruationFlowHealthValue(flow: level, dateTime: at),
        type: HealthDataType.MENSTRUATION_FLOW,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.cycle.app',
        sourceName: 'Cycle app',
        recordingMethod: RecordingMethod.manual,
      );

  /// Two periods: three days from 1 Aug, two from 29 Aug.
  List<HealthDataPoint> twoPeriods() => [
        flow(DateTime(2026, 8, 1, 8), MenstrualFlow.medium),
        flow(DateTime(2026, 8, 2, 8), MenstrualFlow.heavy),
        flow(DateTime(2026, 8, 3, 8), MenstrualFlow.light),
        flow(DateTime(2026, 8, 29, 8), MenstrualFlow.medium),
        flow(DateTime(2026, 8, 30, 8), MenstrualFlow.medium),
      ];

  CycleImportPlan planFor(List<HealthDataPoint> samples) =>
      CycleHistoryImport.plan(
          CycleHistoryImport.daysFrom(samples, now: now), PeriodService.days);

  Future<List<String>> storedIds() async =>
      [for (final r in await db.periodDao.getAllDays()) r.id];

  group('writing the days', () {
    test('every day lands, in memory and in the database, and the cycles follow',
        () async {
      final result = await CycleHistoryImport.apply(planFor(twoPeriods()));

      expect(result.days, 5);
      expect(PeriodService.days.keys.toSet(),
          {'2026-08-01', '2026-08-02', '2026-08-03', '2026-08-29', '2026-08-30'});
      expect(PeriodService.days['2026-08-02']!.flowIndex,
          FlowIntensity.heavy.flowIndex);
      expect(await storedIds(),
          ['2026-08-01', '2026-08-02', '2026-08-03', '2026-08-29', '2026-08-30']);
      expect(PeriodService.getCycles(), hasLength(2),
          reason: 'recomputed once, after the whole batch');
    });

    test('a day the person logged something else for keeps it', () async {
      await PeriodService.logDay(PeriodDay.empty(d(2026, 8, 1))
          .copyWith(note: 'cramps', mood: 2));

      await CycleHistoryImport.apply(planFor(twoPeriods()));

      final first = PeriodService.days['2026-08-01']!;
      expect(first.flowIndex, FlowIntensity.medium.flowIndex);
      expect(first.note, 'cramps');
      expect(first.mood, 2);
      final stored = await db.periodDao.getDay('2026-08-01');
      expect(stored!.note, 'cramps');
      expect(stored.flowIndex, FlowIntensity.medium.flowIndex);
    });

    test('a flow the person logged is theirs, and is never replaced', () async {
      await PeriodService.logDay(PeriodDay.empty(d(2026, 8, 2)).copyWith(flowIndex: 1));

      final result = await CycleHistoryImport.apply(planFor(twoPeriods()));

      expect(PeriodService.days['2026-08-02']!.flowIndex, 1,
          reason: 'their Spotting, not the imported Heavy');
      expect(result.prior.keys, isNot(contains('2026-08-02')));
      expect(result.days, 4);
    });

    test('a flow logged while the confirmation was open is theirs too', () async {
      final plan = planFor(twoPeriods()); // made before the day below was logged
      await PeriodService.logDay(PeriodDay.empty(d(2026, 8, 2)).copyWith(flowIndex: 3));

      final result = await CycleHistoryImport.apply(plan);

      expect(PeriodService.days['2026-08-02']!.flowIndex, 3,
          reason: 'the plan is checked again at the moment it is applied');
      expect(result.prior.keys, isNot(contains('2026-08-02')));
      expect((await db.periodDao.getDay('2026-08-02'))!.flowIndex, 3);
    });

    test('a day logged while the import is being written is not dropped',
        () async {
      final pending = CycleHistoryImport.apply(planFor(twoPeriods()));
      // Logged in the middle of the batch, from another screen or a notification.
      await PeriodService.logDay(PeriodDay.empty(d(2026, 9, 10)).copyWith(flowIndex: 2));
      await pending;

      expect(PeriodService.days.keys, contains('2026-09-10'),
          reason: 'the map is updated as it is after the write, not before it');
      expect(PeriodService.days, hasLength(6));
      expect(await storedIds(), contains('2026-09-10'));
    });

    test('nothing to add writes nothing and says so', () async {
      final result =
          await CycleHistoryImport.apply(planFor(const <HealthDataPoint>[]));

      expect(result.days, 0);
      expect(PeriodService.days, isEmpty);
    });

    test('one notification for the whole batch, not one a day', () async {
      var notified = 0;
      void count() => notified++;
      PeriodService.listenToDays().addListener(count);
      addTearDown(() => PeriodService.listenToDays().removeListener(count));

      final result = await CycleHistoryImport.apply(planFor(twoPeriods()));
      expect(notified, 1, reason: 'five days, one rebuild');

      notified = 0;
      await CycleHistoryImport.undo(result);
      expect(notified, 1);
    });
  });

  group('the import is all or nothing', () {
    test('a failure part-way leaves no day behind, and is thrown', () async {
      // The third day cannot be written: its insert raises, as a full disk or a
      // locked database would.
      await db.customStatement('''
        CREATE TRIGGER refuse_third BEFORE INSERT ON period_days
        WHEN NEW.id = '2026-08-03'
        BEGIN SELECT RAISE(ABORT, 'refused'); END''');

      await expectLater(
          CycleHistoryImport.apply(planFor(twoPeriods())), throwsA(anything));

      expect(PeriodService.days, isEmpty,
          reason: 'what the screens show is what is stored');
      expect(await storedIds(), isEmpty,
          reason: 'the two days written before the failure were rolled back');
      expect(PeriodService.getCycles(), isEmpty);
    });
  });

  group('taking it back', () {
    test('days the import added are gone, in memory and stored', () async {
      final result = await CycleHistoryImport.apply(planFor(twoPeriods()));

      await CycleHistoryImport.undo(result);

      expect(PeriodService.days, isEmpty);
      expect(await storedIds(), isEmpty);
      expect(PeriodService.getCycles(), isEmpty);
    });

    test('a day that had other data is put back as it was, without the flow',
        () async {
      await PeriodService.logDay(PeriodDay.empty(d(2026, 8, 1))
          .copyWith(note: 'cramps', mood: 2));
      final result = await CycleHistoryImport.apply(planFor(twoPeriods()));

      await CycleHistoryImport.undo(result);

      final first = PeriodService.days['2026-08-01']!;
      expect(first.flowIndex, 0);
      expect(first.note, 'cramps');
      expect(first.mood, 2);
      final stored = await db.periodDao.getDay('2026-08-01');
      expect(stored!.flowIndex, 0);
      expect(stored.note, 'cramps');
      expect(PeriodService.days.keys, ['2026-08-01'],
          reason: 'only the day that existed before');
    });

    test('days the person logged themselves are left alone by the Undo',
        () async {
      await PeriodService.logDay(PeriodDay.empty(d(2026, 8, 2)).copyWith(flowIndex: 1));
      final result = await CycleHistoryImport.apply(planFor(twoPeriods()));

      await CycleHistoryImport.undo(result);

      expect(PeriodService.days.keys, ['2026-08-02']);
      expect(PeriodService.days['2026-08-02']!.flowIndex, 1);
    });

    test('importing again after an Undo works: the removed days come back',
        () async {
      final first = await CycleHistoryImport.apply(planFor(twoPeriods()));
      await CycleHistoryImport.undo(first);

      final again = await CycleHistoryImport.apply(planFor(twoPeriods()));

      expect(again.days, 5);
      expect(PeriodService.days, hasLength(5));
      expect(await storedIds(), hasLength(5),
          reason: 'a removed day is a tombstone, and re-logging clears it');
    });
  });

  group('the preview says what is about to happen', () {
    CycleImportPlan plan(List<ImportedFlowDay> days, {int logged = 0}) =>
        CycleImportPlan(
            toAdd: days,
            alreadyLogged: logged,
            periods: CycleHistoryImport.plan(days, const {}).periods);

    final run = [
      ImportedFlowDay(d(2026, 8, 1), FlowIntensity.medium),
      ImportedFlowDay(d(2026, 8, 2), FlowIntensity.heavy),
      ImportedFlowDay(d(2026, 8, 29), FlowIntensity.light),
    ];

    test('counts the days and the periods, with their span', () {
      expect(
          CycleImportButton.preview(
              plan: plan(run), store: 'Health Connect', fullHistory: true),
          'Health Connect has 3 days of bleeding between Aug 1, 2026 and '
          'Aug 29, 2026, in 2 periods. You can undo this right after.');
    });

    test('one day is one day, in one period, on that date', () {
      expect(
          CycleImportButton.preview(
              plan: plan([run.first]), store: 'Apple Health', fullHistory: true),
          'Apple Health has 1 day of bleeding on Aug 1, 2026, in 1 period. '
          'You can undo this right after.');
    });

    test('says how many are already logged and stay as they were', () {
      expect(
          CycleImportButton.preview(
              plan: plan(run, logged: 4),
              store: 'Health Connect',
              fullHistory: true),
          contains('4 days you already logged stay exactly as you logged them.'));
      expect(
          CycleImportButton.preview(
              plan: plan(run, logged: 1),
              store: 'Health Connect',
              fullHistory: true),
          contains('1 day you already logged stay exactly'));
    });

    test('says so when only the last month was shared', () {
      final text = CycleImportButton.preview(
          plan: plan(run), store: 'Health Connect', fullHistory: false);
      expect(text, contains('only shares about the last 30 days'));
      expect(text, contains('earlier periods are not included'));
      expect(
          CycleImportButton.preview(
              plan: plan(run), store: 'Health Connect', fullHistory: true),
          isNot(contains('30 days')));
    });
  });

  group('the button', () {
    Future<void> show(WidgetTester tester, FakeCycleSource source) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1200);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
                body: Center(child: CycleImportButton(source: source)))));
        await tester.pump(const Duration(milliseconds: 100));
      } finally {
        FlutterError.onError = prev;
      }
    }

    Future<void> settle(WidgetTester tester, [int ms = 600]) async {
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        for (var t = 0; t < ms; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
    }

    Future<void> tapImport(WidgetTester tester, String store) async {
      await tester.tap(find.text('Import from $store'));
      await settle(tester);
    }

    void pinned(String name, Future<void> Function(WidgetTester) body) =>
        testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

    pinned('is named for the phone\'s own health app', (tester) async {
      await show(tester, FakeCycleSource(store: 'Apple Health'));
      expect(find.text('Import from Apple Health'), findsOneWidget);
    });

    pinned('asks, reads two years back, shows what it found, then imports',
        (tester) async {
      final source = FakeCycleSource(samples: twoPeriods());
      await show(tester, source);

      await tapImport(tester, 'Health Connect');

      expect(source.asked, 1);
      expect(source.reads, hasLength(1));
      expect(source.reads.single.$1, DateTime(2024, 9, 30),
          reason: 'midnight, two years before today');
      expect(source.reads.single.$2, now);
      expect(find.text('Import your periods?'), findsOneWidget);
      expect(find.textContaining('has 5 days of bleeding'), findsOneWidget);
      expect(PeriodService.days, isEmpty, reason: 'nothing is written until asked');

      await tester.tap(find.text('Import'));
      await settle(tester);

      expect(PeriodService.days, hasLength(5));
      expect(find.text('Imported 5 days from Health Connect'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    pinned('the Undo in the toast takes every day back', (tester) async {
      await show(tester, FakeCycleSource(samples: twoPeriods()));
      await tapImport(tester, 'Health Connect');
      await tester.tap(find.text('Import'));
      await settle(tester);
      expect(PeriodService.days, hasLength(5));

      await tester.tap(find.text('Undo'));
      await settle(tester);

      expect(PeriodService.days, isEmpty);
    });

    pinned('closing the preview writes nothing', (tester) async {
      await show(tester, FakeCycleSource(samples: twoPeriods()));
      await tapImport(tester, 'Health Connect');

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(PeriodService.days, isEmpty);
      expect(find.textContaining('Imported'), findsNothing);
    });

    pinned('a store already allowed is not asked again', (tester) async {
      final source = FakeCycleSource(alreadyAllowed: true, samples: twoPeriods());
      await show(tester, source);

      await tapImport(tester, 'Health Connect');

      expect(source.asked, 0);
      expect(find.text('Import your periods?'), findsOneWidget);
    });

    pinned('declined: says nothing was imported, and does not read', (tester) async {
      final source = FakeCycleSource(grants: false, samples: twoPeriods());
      await show(tester, source);

      await tapImport(tester, 'Health Connect');

      expect(find.textContaining('did not share your cycle data'), findsOneWidget);
      expect(source.reads, isEmpty);
      expect(source.historyAsked, 0,
          reason: 'no point asking for more history without the permission');
      expect(PeriodService.days, isEmpty);
    });

    pinned('a read that failed is an error, not "no periods"', (tester) async {
      await show(tester, FakeCycleSource(readFails: true));

      await tapImport(tester, 'Health Connect');

      expect(find.text('Could not read from Health Connect. Please try again.'),
          findsOneWidget);
      expect(find.textContaining('No periods found'), findsNothing);
    });

    pinned('no periods in the store: says how far it looked', (tester) async {
      await show(tester, FakeCycleSource());

      await tapImport(tester, 'Health Connect');

      expect(find.text('No periods found in Health Connect from the last two years.'),
          findsOneWidget);
      expect(find.text('Import your periods?'), findsNothing);
    });

    pinned('and when only a month was shared, says a month', (tester) async {
      await show(tester, FakeCycleSource(history: false));

      await tapImport(tester, 'Health Connect');

      expect(find.text('No periods found in Health Connect from the last 30 days.'),
          findsOneWidget);
    });

    pinned('the preview says when earlier periods were out of reach', (tester) async {
      await show(tester, FakeCycleSource(history: false, samples: twoPeriods()));

      await tapImport(tester, 'Health Connect');

      expect(find.textContaining('only shares about the last 30 days'),
          findsOneWidget);
    });

    pinned('everything already logged: nothing to confirm', (tester) async {
      await CycleHistoryImport.apply(planFor(twoPeriods()));
      await show(tester, FakeCycleSource(samples: twoPeriods()));

      await tapImport(tester, 'Health Connect');

      expect(find.text('Everything Health Connect has is already logged here.'),
          findsOneWidget);
      expect(find.text('Import your periods?'), findsNothing);
    });

    pinned('a second tap while the first is waiting does not ask twice',
        (tester) async {
      final gate = Completer<bool>();
      final source = FakeCycleSource(gate: gate, samples: twoPeriods());
      await show(tester, source);

      await tester.tap(find.text('Import from Health Connect'));
      await tester.pump(const Duration(milliseconds: 50));
      // The button is a spinner now; tapping where it was must not start another.
      await tester.tap(find.byType(CycleImportButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(source.asked, 1);

      gate.complete(false);
      await settle(tester);
    });

    pinned('a failed write says nothing was changed', (tester) async {
      await db.customStatement('''
        CREATE TRIGGER refuse_third BEFORE INSERT ON period_days
        WHEN NEW.id = '2026-08-03'
        BEGIN SELECT RAISE(ABORT, 'refused'); END''');
      await show(tester, FakeCycleSource(samples: twoPeriods()));
      await tapImport(tester, 'Health Connect');

      await tester.tap(find.text('Import'));
      await settle(tester);

      expect(find.text('Could not import from Health Connect. Nothing was changed.'),
          findsOneWidget);
      expect(PeriodService.days, isEmpty);
      expect(find.textContaining('Imported'), findsNothing);
    });
  });

  group('where it is offered', () {
    Future<void> open(WidgetTester tester, Widget screen) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 3200);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
    }

    void pinned(String name, Future<void> Function(WidgetTester) body) =>
        testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

    pinned('a cycle with nothing logged: beside "Log your period"', (tester) async {
      await open(tester, const PeriodDashboard());

      expect(find.text('Start tracking your cycle'), findsOneWidget);
      expect(find.text('Log your period'), findsOneWidget);
      expect(find.byType(CycleImportButton), findsOneWidget);
      expect(find.text('Import from Health Connect'), findsOneWidget);
    });

    pinned('once there is history it is not in the way', (tester) async {
      await PeriodService.logDay(PeriodDay.empty(d(2026, 9, 20)).copyWith(flowIndex: 2));
      await open(tester, const PeriodDashboard());

      expect(find.text('Start tracking your cycle'), findsNothing);
      expect(find.byType(CycleImportButton), findsNothing);
    });

    pinned('the empty Cycle history offers it too', (tester) async {
      await open(tester, const CycleHistoryScreen());

      expect(find.text('No cycles yet'), findsOneWidget);
      expect(find.byType(CycleImportButton), findsOneWidget);
    });

    pinned('and a Cycle history with cycles does not', (tester) async {
      await CycleHistoryImport.apply(planFor(twoPeriods()));
      await open(tester, const CycleHistoryScreen());

      expect(find.text('No cycles yet'), findsNothing);
      expect(find.byType(CycleImportButton), findsNothing);
    });
  });
}
