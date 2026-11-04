/// Hormonal birth control on the cycle screen.
///
/// The setting was stored and read by nothing, so someone on the pill was still
/// shown a fertile window and an ovulation day counted back from their next
/// period — an estimate of something that may not be happening. With it on those
/// are not estimated, the ring and the phase named under it agree, and the card
/// says why.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/period/models/cycle_phase.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/models/period_reminder_config.dart';
import 'package:tablet_remainder/features/period/models/period_settings.dart';
import 'package:tablet_remainder/features/period/screens/period_calendar_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_dashboard.dart';
import 'package:tablet_remainder/features/period/screens/period_reminder_settings_screen.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';
import 'package:tablet_remainder/features/period/services/period_reminder_service.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/period/widgets/birth_control_card.dart';
import 'package:tablet_remainder/features/period/widgets/cycle_phase_wheel.dart';
import 'package:tablet_remainder/features/period/widgets/prediction_card.dart';

final _base = DateTime(2026, 1, 1);

List<FlowDay> _history(List<int> startOffsets, {int periodLen = 5}) => [
      for (final off in startOffsets)
        for (var d = 0; d < periodLen; d++)
          FlowDay(_base.add(Duration(days: off + d)), 2),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('the prediction', () {
    // Four starts, 28 days apart; day 5 of the open cycle.
    final days = _history([0, 28, 56, 84]);
    final on = _base.add(const Duration(days: 88));

    CyclePrediction predict({bool birthControl = false, DateTime? at}) =>
        CyclePredictor.predict(
            days: days, on: at ?? on, hormonalBirthControl: birthControl);

    test('without it, an ovulation day and a fertile window are estimated', () {
      final p = predict();
      expect(p.ovulationDay, isNotNull);
      expect(p.fertileStart, isNotNull);
      expect(p.fertileEnd, isNotNull);
    });

    test('with it, none of the three is', () {
      final p = predict(birthControl: true);
      expect(p.ovulationDay, isNull);
      expect(p.fertileStart, isNull);
      expect(p.fertileEnd, isNull);
    });

    test('the next period is estimated exactly as before', () {
      final a = predict();
      final b = predict(birthControl: true);
      expect(b.predictedStart, a.predictedStart);
      expect(b.windowStart, a.windowStart);
      expect(b.windowEnd, a.windowEnd);
      expect(b.cycleLengthEstimate, a.cycleLengthEstimate);
      expect(b.confidence, a.confidence);
      expect(b.state, a.state);
      expect(b.daysUntilNextPeriod, a.daysUntilNextPeriod);
      expect(b.dayOfCycle, a.dayOfCycle);
    });

    test('the phase today is never ovulation, on any day of the cycle', () {
      for (var offset = 84; offset < 84 + 28; offset++) {
        final p = predict(birthControl: true, at: _base.add(Duration(days: offset)));
        expect(p.phaseToday, isNot(CyclePhase.ovulation), reason: 'day $offset');
      }
    });

    test('without it, the phase does reach ovulation, so the above is the flag',
        () {
      final seen = {
        for (var offset = 84; offset < 84 + 28; offset++)
          predict(at: _base.add(Duration(days: offset))).phaseToday,
      };
      expect(seen, contains(CyclePhase.ovulation));
    });

    test('pregnancy is unchanged by it', () {
      final p = CyclePredictor.predict(
        days: days,
        on: on,
        pregnancyMode: true,
        pregnancyStartDate: _base,
        hormonalBirthControl: true,
      );
      expect(p.state, CycleState.pregnancy);
    });

    test('no cycles yet is still onboarding', () {
      final p = CyclePredictor.predict(
          days: const [], on: on, hormonalBirthControl: true);
      expect(p.state, CycleState.onboarding);
    });
  });

  group('phaseOn', () {
    CyclePhase phase(int offset, {required bool ovulationPhase}) =>
        CyclePredictor.phaseOn(
          _base.add(Duration(days: offset)),
          lastStart: _base,
          cycleLength: 28,
          periodLength: 5,
          lutealLength: 14,
          ovulationPhase: ovulationPhase,
        );

    test('by default the days around index 14 are ovulation', () {
      expect(phase(12, ovulationPhase: true), CyclePhase.follicular);
      expect(phase(13, ovulationPhase: true), CyclePhase.ovulation);
      expect(phase(14, ovulationPhase: true), CyclePhase.ovulation);
      expect(phase(15, ovulationPhase: true), CyclePhase.ovulation);
      expect(phase(16, ovulationPhase: true), CyclePhase.luteal);
    });

    test('without an ovulation phase, those days join the follicular one up to '
        'index 14 and the luteal one after', () {
      expect(phase(12, ovulationPhase: false), CyclePhase.follicular);
      expect(phase(13, ovulationPhase: false), CyclePhase.follicular);
      expect(phase(14, ovulationPhase: false), CyclePhase.follicular);
      expect(phase(15, ovulationPhase: false), CyclePhase.luteal);
      expect(phase(16, ovulationPhase: false), CyclePhase.luteal);
    });

    test('the period is the period either way', () {
      for (final off in [0, 2, 4]) {
        expect(phase(off, ovulationPhase: false), CyclePhase.menstrual);
      }
    });

    test('phaseForDate takes the same flag', () {
      final days = _history([0, 28, 56, 84]);
      final d = _base.add(const Duration(days: 84 + 14));
      expect(CyclePredictor.phaseForDate(d, days: days), CyclePhase.ovulation);
      expect(CyclePredictor.phaseForDate(d, days: days, ovulationPhase: false),
          CyclePhase.follicular);
    });
  });

  group('the ring', () {
    List<WheelArc> arcs({required bool showOvulation}) => wheelArcs(
        cycleLength: 28,
        periodLength: 5,
        lutealLength: 14,
        showOvulation: showOvulation);

    test('has four arcs by default, covering the cycle without a gap', () {
      final a = arcs(showOvulation: true);
      expect(a.map((e) => e.phase), [
        CyclePhase.menstrual,
        CyclePhase.follicular,
        CyclePhase.ovulation,
        CyclePhase.luteal,
      ]);
      expect((a.first.start, a.last.end), (0, 28));
      for (var i = 1; i < a.length; i++) {
        expect(a[i].start, a[i - 1].end, reason: 'arc $i starts where the last ends');
      }
    });

    test('without ovulation has three arcs, still covering the cycle', () {
      final a = arcs(showOvulation: false);
      expect(a.map((e) => e.phase),
          [CyclePhase.menstrual, CyclePhase.follicular, CyclePhase.luteal]);
      expect((a.first.start, a.last.end), (0, 28));
      for (var i = 1; i < a.length; i++) {
        expect(a[i].start, a[i - 1].end);
      }
    });

    test('and its follicular arc ends where phaseOn stops saying follicular', () {
      // Index 14 is the last follicular day, so the arc ends at 15.
      final a = arcs(showOvulation: false);
      expect(a[1].end, 15);
      expect(a[2].start, 15);
    });

    test('a zero cycle length falls back to 28', () {
      final a = wheelArcs(
          cycleLength: 0, periodLength: 5, lutealLength: 14, showOvulation: false);
      expect(a.last.end, 28);
    });
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: child))));
      await tester.pump();
    }

    final withFertile = CyclePrediction(
      predictedStart: DateTime(2026, 5, 21),
      windowStart: DateTime(2026, 5, 20),
      windowEnd: DateTime(2026, 5, 22),
      ovulationDay: DateTime(2026, 5, 7),
      fertileStart: DateTime(2026, 5, 2),
      fertileEnd: DateTime(2026, 5, 8),
      daysUntilNextPeriod: 16,
      state: CycleState.ready,
    );
    final withoutFertile = CyclePrediction(
      predictedStart: DateTime(2026, 5, 21),
      windowStart: DateTime(2026, 5, 20),
      windowEnd: DateTime(2026, 5, 22),
      daysUntilNextPeriod: 16,
      state: CycleState.ready,
    );
    const note = 'No fertile window or ovulation day is estimated while hormonal '
        'birth control is on.';

    testWidgets('the switch shows what it does, and says it when tapped',
        (tester) async {
      var value = false;
      late StateSetter set;
      await pump(
          tester,
          StatefulBuilder(builder: (context, setState) {
            set = setState;
            return BirthControlCard(
                value: value, onChanged: (v) => set(() => value = v));
          }));
      expect(find.text('Hormonal birth control'), findsOneWidget);
      expect(find.textContaining('pill, patch, ring, implant'), findsOneWidget);

      await tester.tap(find.text('Hormonal birth control'));
      await tester.pump();
      expect(value, isTrue);
      expect(find.text('No fertile window or ovulation day is estimated.'),
          findsOneWidget);
      expect(find.textContaining('pill, patch, ring, implant'), findsNothing);
    });

    testWidgets('the prediction card names the fertile window when there is one',
        (tester) async {
      await pump(tester, PredictionCard(prediction: withFertile));
      expect(find.text('Fertile window (estimate)'), findsOneWidget);
      expect(find.text(note), findsNothing);
    });

    testWidgets('with it on and no window, it explains the absence', (tester) async {
      await pump(
          tester, PredictionCard(prediction: withoutFertile, birthControl: true));
      expect(find.text('Fertile window (estimate)'), findsNothing);
      expect(find.text(note), findsOneWidget);
      expect(find.text('Next period'), findsOneWidget, reason: 'the estimate stays');
    });

    testWidgets('with no window and it off, it does not invent a reason',
        (tester) async {
      await pump(tester, PredictionCard(prediction: withoutFertile));
      expect(find.text(note), findsNothing);
    });

    testWidgets('the not-enough-data line stops promising a fertile window',
        (tester) async {
      await pump(tester,
          const PredictionCard(prediction: CyclePrediction.onboarding));
      expect(find.textContaining('period and fertile window'), findsOneWidget);
      await pump(
          tester,
          const PredictionCard(
              prediction: CyclePrediction.onboarding, birthControl: true));
      expect(find.textContaining('fertile window'), findsNothing);
      expect(find.textContaining('estimate your next period here'), findsOneWidget);
    });
  });

  group('the screens', () {
    late AppDatabase db;
    // Day 13 of a cycle that began 23 April: inside the estimated fertile window.
    final now = DateTime(2026, 5, 5, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      PeriodService.clearInMemory();
      await PeriodService.resetForTesting();
      await PeriodService.init();
      var start = DateTime(2026, 1, 1);
      Future<void> log(DateTime d) => PeriodService.logDay(
          PeriodDay(id: PeriodDay.keyFor(d), date: d, flowIndex: 2));
      await log(start);
      for (var i = 0; i < 4; i++) {
        start = DateTime(start.year, start.month, start.day + 28);
        await log(start);
      }
    });

    tearDown(() async => db.close());

    Future<void> openWith(WidgetTester tester, Widget home) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 3200);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
    }

    void pinned(String name, Future<void> Function(WidgetTester) body) =>
        testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

    Future<void> setBirthControl(bool on, {TrackingMode? mode}) =>
        PeriodService.saveSettings(PeriodService.getSettings()
            .copyWith(birthControlEnabled: on, trackingMode: mode));

    pinned('off: the dashboard shows the fertile window, and the switch is off',
        (tester) async {
      await openWith(tester, const PeriodDashboard());
      expect(find.text('Fertile window (estimate)'), findsOneWidget);
      expect(find.text('Hormonal birth control'), findsOneWidget);
      expect(find.textContaining('pill, patch, ring, implant'), findsOneWidget);
    });

    pinned('tapping the switch turns the setting on, and it is kept', (tester) async {
      await openWith(tester, const PeriodDashboard());
      await tester.tap(find.text('Hormonal birth control'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(PeriodService.getSettings().birthControlEnabled, isTrue);
      expect(find.text('Fertile window (estimate)'), findsNothing);
      expect(
          find.text('No fertile window or ovulation day is estimated while hormonal '
              'birth control is on.'),
          findsOneWidget);
      expect(find.text('No fertile window or ovulation day is estimated.'),
          findsOneWidget);

      // Survives a restart.
      await tester.pumpWidget(const SizedBox());
      await PeriodService.resetForTesting();
      await PeriodService.init();
      expect(PeriodService.getSettings().birthControlEnabled, isTrue);
    });

    pinned('on: the service gives no fertile window and no ovulation phase',
        (tester) async {
      await setBirthControl(true);
      final p = PeriodService.getPrediction(on: now);
      expect(p.fertileStart, isNull);
      expect(p.ovulationDay, isNull);
      expect(p.predictedStart, isNotNull);
      for (var d = 0; d < 28; d++) {
        expect(PeriodService.phaseOn(DateTime(2026, 4, 23 + d)),
            isNot(CyclePhase.ovulation),
            reason: 'day $d');
      }
    });

    pinned('off: the service still has them', (tester) async {
      final p = PeriodService.getPrediction(on: now);
      expect(p.fertileStart, isNotNull);
      expect(PeriodService.phaseOn(DateTime(2026, 5, 7)), CyclePhase.ovulation);
    });

    pinned('the ring drops its ovulation arc with it, and keeps it without',
        (tester) async {
      await openWith(tester, const PeriodDashboard());
      var wheel = tester.widget<CyclePhaseWheel>(find.byType(CyclePhaseWheel));
      expect(wheel.showOvulation, isTrue);
      expect(wheel.arcs.map((a) => a.phase), contains(CyclePhase.ovulation));

      await tester.pumpWidget(const SizedBox());
      await setBirthControl(true);
      await openWith(tester, const PeriodDashboard());
      wheel = tester.widget<CyclePhaseWheel>(find.byType(CyclePhaseWheel));
      expect(wheel.showOvulation, isFalse);
      expect(wheel.arcs.map((a) => a.phase),
          isNot(contains(CyclePhase.ovulation)));
    });

    pinned('the switch turns it back off', (tester) async {
      await setBirthControl(true);
      await openWith(tester, const PeriodDashboard());
      expect(find.text('Fertile window (estimate)'), findsNothing);
      await tester.tap(find.text('Hormonal birth control'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(PeriodService.getSettings().birthControlEnabled, isFalse);
      expect(find.text('Fertile window (estimate)'), findsOneWidget);
    });

    pinned('a temperature shift is not announced as ovulation while it is on',
        (tester) async {
      // A rise on day 8 of the open cycle (began 23 April).
      final start = DateTime(2026, 4, 23);
      for (var d = 1; d <= 10; d++) {
        final day = DateTime(start.year, start.month, start.day + d - 1);
        await PeriodService.logDay((PeriodService.getDay(day) ?? PeriodDay.empty(day))
            .copyWith(bbtCelsius: d < 8 ? 36.3 + (d.isEven ? 0.05 : 0.0) : 36.7));
      }
      await openWith(tester, const PeriodDashboard());
      expect(find.text('Temperature shift'), findsOneWidget, reason: 'the control');

      await tester.pumpWidget(const SizedBox());
      await setBirthControl(true);
      await openWith(tester, const PeriodDashboard());
      expect(find.text('Temperature shift'), findsNothing);
    });

    pinned('the BBT hint (about confirming ovulation) goes with it', (tester) async {
      await setBirthControl(false, mode: TrackingMode.ttc);
      await openWith(tester, const PeriodDashboard());
      expect(find.text('Track BBT daily'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await setBirthControl(true);
      await openWith(tester, const PeriodDashboard());
      expect(find.text('Track BBT daily'), findsNothing);
    });

    pinned('the calendar key stops naming a fill it never paints', (tester) async {
      await openWith(tester, const PeriodCalendarScreen());
      expect(find.text('Fertile window'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await setBirthControl(true);
      await openWith(tester, const PeriodCalendarScreen());
      expect(find.text('Fertile window'), findsNothing);
      expect(find.text('Predicted'), findsOneWidget, reason: 'the rest of the key stays');
    });

    pinned('the reminders: the fertile-window switch is for TTC without it',
        (tester) async {
      await setBirthControl(false, mode: TrackingMode.ttc);
      await openWith(tester, const PeriodReminderSettingsScreen());
      expect(find.text('Fertile window'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await setBirthControl(true, mode: TrackingMode.ttc);
      await openWith(tester, const PeriodReminderSettingsScreen());
      expect(find.text('Fertile window'), findsNothing);
      expect(find.text('Cycle coming up'), findsOneWidget);
    });

    pinned('and nothing is planned for a fertile window while it is on',
        (tester) async {
      await setBirthControl(true, mode: TrackingMode.ttc);
      final plan = PeriodReminderPlanner.plan(
        prediction: PeriodService.getPrediction(on: now),
        mode: TrackingMode.ttc,
        config: const PeriodReminderConfig(fertileEnabled: true),
        now: now,
      );
      expect(plan.where((r) => r.title == 'Fertile window'), isEmpty);
    });
  });
}
