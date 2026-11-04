/// "Predictions: calendar method only; temperature isn't used".
///
/// A temperature rise found in the CURRENT cycle's own log says when ovulation
/// happened, and the next period is counted on from it (ovulation + the luteal
/// phase) instead of from the cycle's start plus the typical length — but only
/// within a week of the calendar's answer, never with hormonal birth control, and
/// never from a rise that had not happened yet or belongs to an earlier cycle.
library;

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
import 'package:tablet_remainder/features/period/models/period_settings.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/period/widgets/prediction_card.dart';

final _base = DateTime(2026, 1, 1);
DateTime _day(int offset) => DateTime(_base.year, _base.month, _base.day + offset);

List<FlowDay> _history(List<int> startOffsets, {int periodLen = 5}) => [
      for (final off in startOffsets)
        for (var d = 0; d < periodLen; d++) FlowDay(_day(off + d), 2),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('the predictor', () {
    // Starts at 0, 28, 56, 84: the open cycle began on day 84, so the calendar says
    // the next period is on day 112 and ovulation on day 98 (14 days before it).
    final days = _history([0, 28, 56, 84]);
    final on = _day(100);

    CyclePrediction predict({
      DateTime? ovulated,
      bool birthControl = false,
      DateTime? at,
      int luteal = 14,
    }) =>
        CyclePredictor.predict(
          days: days,
          on: at ?? on,
          lutealPhaseLength: luteal,
          hormonalBirthControl: birthControl,
          confirmedOvulation: ovulated,
        );

    test('with no rise, it is the calendar, as ever', () {
      final p = predict();
      expect(p.basis, PredictionBasis.calendar);
      expect(p.predictedStart, _day(112));
      expect(p.ovulationDay, _day(98));
    });

    test('a rise that agrees with the calendar changes no date, and says so', () {
      final p = predict(ovulated: _day(98));
      expect(p.basis, PredictionBasis.temperature);
      expect(p.predictedStart, _day(112));
    });

    test('ovulation earlier than the calendar brings the period forward', () {
      final p = predict(ovulated: _day(94));
      expect(p.basis, PredictionBasis.temperature);
      expect(p.predictedStart, _day(108));
      expect(p.ovulationDay, _day(94), reason: 'known now, not counted back');
      expect(p.fertileStart, _day(89));
      expect(p.fertileEnd, _day(95));
      expect(p.daysUntilNextPeriod, 8);
    });

    test('later pushes it back', () {
      final p = predict(ovulated: _day(99));
      expect(p.predictedStart, _day(113));
    });

    test('it counts on by the person\'s own luteal length', () {
      expect(predict(ovulated: _day(94), luteal: 12).predictedStart, _day(106));
    });

    test('the window stays around the new date, no tighter than before', () {
      final calendar = predict();
      final temp = predict(ovulated: _day(94));
      expect(temp.windowStart!.difference(temp.predictedStart!).inDays,
          calendar.windowStart!.difference(calendar.predictedStart!).inDays);
      expect(temp.confidence, calendar.confidence,
          reason: 'a temperature rise is not a reason to be surer');
    });

    test('a week away from the calendar is still used; more is set aside', () {
      // Calendar ovulation is day 98; +7 is the edge.
      // Asked about on day 110, so none of them is still in the future.
      final later = _day(110);
      expect(predict(ovulated: _day(105), at: later).basis, PredictionBasis.temperature);
      expect(predict(ovulated: _day(91), at: later).basis, PredictionBasis.temperature);
      final late = predict(ovulated: _day(106), at: later);
      expect(late.basis, PredictionBasis.calendar);
      expect(late.predictedStart, _day(112));
      final early = predict(ovulated: _day(90), at: later);
      expect(early.basis, PredictionBasis.calendar);
      expect(early.predictedStart, _day(112));
      expect(CyclePredictor.maxTemperatureAdjustDays, 7);
    });

    test('with hormonal birth control it is ignored altogether', () {
      final p = predict(ovulated: _day(94), birthControl: true);
      expect(p.basis, PredictionBasis.calendar);
      expect(p.predictedStart, _day(112));
      expect(p.ovulationDay, isNull);
    });

    test('a rise from the cycle before is not this cycle\'s', () {
      final p = predict(ovulated: _day(70));
      expect(p.basis, PredictionBasis.calendar);
      expect(p.predictedStart, _day(112));
    });

    test('ovulation on the very day the cycle began is not this cycle\'s either', () {
      // Short cycles (21 days): ovulation 14 days before the next period sits at
      // day 7 of the cycle, and a rise "on day 0" would land one week from the
      // calendar's date, inside the limit — only its own check turns it away.
      final short = _history([0, 21, 42, 63]);
      final p = CyclePredictor.predict(
          days: short, on: _day(70), confirmedOvulation: _day(63));
      expect(p.basis, PredictionBasis.calendar);
      expect(p.predictedStart, _day(84));
    });

    test('a rise that has not happened yet is not used', () {
      final p = predict(ovulated: _day(101), at: _day(100));
      expect(p.basis, PredictionBasis.calendar);
    });

    test('the phase follows the cycle as now estimated', () {
      // Day 95: ovulation (94) is behind it. By the calendar the cycle is still in
      // its follicular phase; counted from the rise it is not.
      final calendar = predict(at: _day(95));
      final temp = predict(ovulated: _day(94), at: _day(95));
      expect(calendar.phaseToday, CyclePhase.follicular);
      expect(temp.phaseToday, isNot(CyclePhase.follicular));
    });

    test('without a history there is nothing to adjust', () {
      final p = CyclePredictor.predict(
          days: const [], on: on, confirmedOvulation: _day(94));
      expect(p.state, CycleState.onboarding);
      expect(p.basis, PredictionBasis.calendar);
    });
  });

  group('from the log', () {
    late AppDatabase db;

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
      for (final off in [0, 28, 56, 84, 112]) {
        final d = _day(off);
        await PeriodService.logDay(PeriodDay(id: PeriodDay.keyFor(d), date: d, flowIndex: 2));
      }
    });

    tearDown(() async => db.close());

    // The open cycle began on day 112 (23 April). Cycle days 8-13 sit at 36.4, then
    // 14-16 at 36.7: the first warmer day is cycle day 14, so ovulation was day 13
    // (offset 112 + 12 = 124, 5 May) and the next period 14 days on (19 May) —
    // two days before the calendar's 21 May.
    Future<void> logRise({int through = 16}) async {
      for (var cd = 8; cd <= through; cd++) {
        final d = _day(112 + cd - 1);
        await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(d),
          date: d,
          flowIndex: 0,
          bbtCelsius: cd < 14 ? 36.4 : 36.7,
        ));
      }
    }

    test('a rise in an EARLIER cycle is not mistaken for this one\'s', () async {
      // The previous cycle (from day 84) has its own rise; so does this one.
      for (var cd = 8; cd <= 16; cd++) {
        final d = _day(84 + cd - 1);
        await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(d),
          date: d,
          flowIndex: 0,
          bbtCelsius: cd < 14 ? 36.4 : 36.7,
        ));
      }
      await logRise();
      final p = PeriodService.getPrediction(on: _day(128));
      expect(p.basis, PredictionBasis.temperature);
      expect(p.predictedStart, _day(138),
          reason: 'this cycle\'s ovulation (5 May) + 14, not the last cycle\'s');
    });

    test('no readings: the calendar', () {
      final p = PeriodService.getPrediction(on: _day(130));
      expect(p.basis, PredictionBasis.calendar);
      expect(p.predictedStart, _day(140)); // 21 May
    });

    test('a rise in this cycle moves the period to ovulation + 14 days', () async {
      await logRise();
      final p = PeriodService.getPrediction(on: _day(128)); // 9 May
      expect(p.basis, PredictionBasis.temperature);
      expect(p.predictedStart, _day(138)); // 19 May
      expect(p.ovulationDay, _day(124)); // 5 May
    });

    test('asking about a day before the rise could be seen does not see it', () async {
      await logRise();
      // 6 May: the first warmer day only; three are needed.
      final p = PeriodService.getPrediction(on: _day(125));
      expect(p.basis, PredictionBasis.calendar);
      expect(p.predictedStart, _day(140));
    });

    test('one warmer day short of three is not a rise', () async {
      await logRise(through: 15);
      expect(PeriodService.getPrediction(on: _day(128)).basis, PredictionBasis.calendar);
    });

    test('with hormonal birth control the log is not read for it', () async {
      await logRise();
      await PeriodService.saveSettings(
          PeriodService.getSettings().copyWith(birthControlEnabled: true));
      final p = PeriodService.getPrediction(on: _day(128));
      expect(p.basis, PredictionBasis.calendar);
      expect(p.predictedStart, _day(140));
    });

    test('settings carry the luteal length the count uses', () async {
      await logRise();
      await PeriodService.saveSettings(
          PeriodService.getSettings().copyWith(lutealPhaseLength: 12));
      expect(PeriodService.getPrediction(on: _day(128)).predictedStart, _day(136));
      expect(PeriodService.getSettings().lutealPhaseLength, 12);
    });

    test('PeriodSettings is untouched by it', () {
      expect(PeriodService.getSettings(), isA<PeriodSettings>());
    });
  });

  group('the card', () {
    Future<void> show(WidgetTester tester, CyclePrediction p) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: PredictionCard(prediction: p))),
      ));
      await tester.pump();
    }

    final days = _history([0, 28, 56, 84]);

    testWidgets('says where the date comes from when it is the temperature', (tester) async {
      final p = CyclePredictor.predict(
          days: days, on: _day(100), confirmedOvulation: _day(94));
      await show(tester, p);
      expect(find.textContaining('temperature rise in your log this cycle'),
          findsOneWidget);
      expect(find.textContaining('illness, alcohol or a short night'), findsOneWidget);
    });

    testWidgets('and nothing of the kind on the calendar', (tester) async {
      final p = CyclePredictor.predict(days: days, on: _day(100));
      await show(tester, p);
      expect(find.textContaining('temperature rise'), findsNothing);
    });
  });
}
