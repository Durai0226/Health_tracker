/// "Based on 9 vs 7 days · Moderate".
///
/// A pattern used to say "Mood tends to dip on missed-dose days" off 5 days
/// against 5 in exactly the voice it used for 40 against 30. The engine's own
/// bar (a minimum group size and a floor on the gap) decides whether to speak at
/// all; this is what it says about how much to believe it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/correlation_engine.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/insight_kit.dart';

void main() {
  PatternEvidence ev(int a, int b, double ratio) =>
      PatternEvidence(groupA: a, groupB: b, effectRatio: ratio);

  group('strength', () {
    test('the least that can be said at all is an early signal', () {
      expect(ev(5, 5, 1.0).strength, PatternStrength.early);
    });

    test('a fair amount of data and a clear gap is moderate', () {
      expect(ev(8, 8, 1.5).strength, PatternStrength.moderate);
      expect(ev(9, 7, 1.6).strength, PatternStrength.early,
          reason: '7 days is under the 8 a moderate pattern needs');
    });

    test('plenty of data and a wide gap is strong', () {
      expect(ev(14, 14, 2.0).strength, PatternStrength.strong);
      expect(ev(30, 20, 5.0).strength, PatternStrength.strong);
    });

    test('both halves are needed: data without a gap, or a gap without data',
        () {
      expect(ev(30, 30, 1.2).strength, PatternStrength.early,
          reason: 'lots of days, but the gap is barely past the floor');
      expect(ev(30, 30, 1.7).strength, PatternStrength.moderate,
          reason: 'a clear gap but not a wide one');
      expect(ev(6, 6, 9.0).strength, PatternStrength.early,
          reason: 'a huge gap on twelve days is still twelve days');
    });

    test('the smaller group limits it: 40 days against 5 is a 5-day comparison',
        () {
      final e = ev(40, 5, 5.0);
      expect(e.smallerGroup, 5);
      expect(e.strength, PatternStrength.early);
    });

    test('the boundaries are exact', () {
      expect(ev(7, 7, 1.5).strength, PatternStrength.early);
      expect(ev(8, 8, 1.4999).strength, PatternStrength.early);
      expect(ev(8, 8, 1.5).strength, PatternStrength.moderate);
      expect(ev(13, 13, 2.0).strength, PatternStrength.moderate);
      expect(ev(14, 14, 1.9999).strength, PatternStrength.moderate);
      expect(ev(14, 14, 2.0).strength, PatternStrength.strong);
    });
  });

  group('the line', () {
    test('counts nights when asked to, days otherwise', () {
      expect(const PatternEvidence(groupA: 9, groupB: 7, effectRatio: 1.0).line,
          'Based on 9 vs 7 days · Early signal');
      expect(
          const PatternEvidence(
                  groupA: 9, groupB: 7, effectRatio: 1.0, unit: 'nights')
              .line,
          'Based on 9 vs 7 nights · Early signal');
    });

    test('names both samples and the strength', () {
      expect(ev(9, 7, 1.0).line, 'Based on 9 vs 7 days · Early signal');
      expect(ev(10, 9, 1.6).line, 'Based on 10 vs 9 days · Moderate');
      expect(ev(20, 18, 3.0).line, 'Based on 20 vs 18 days · Strong');
    });
  });

  group('every comparison the engine makes carries it', () {
    List<DayMetric> adherence({
      required int adherent,
      required double adherentValue,
      required int missed,
      required double missedValue,
    }) {
      final base = DateTime(2026, 1, 1);
      return [
        for (var i = 0; i < adherent; i++)
          DayMetric(
              day: base.add(Duration(days: i)),
              adherent: true,
              value: adherentValue),
        for (var i = 0; i < missed; i++)
          DayMetric(
              day: base.add(Duration(days: 100 + i)),
              adherent: false,
              value: missedValue),
      ];
    }

    test('mood vs adherence: the counts and the ratio against its own floor',
        () {
      // Mean 1.0 vs 2.0: a gap of 1.0 against a 0.5 floor is a ratio of 2.
      final i = CorrelationEngine.moodVsAdherence(adherence(
          adherent: 14, adherentValue: 1.0, missed: 14, missedValue: 2.0))!;
      expect(i.evidence!.groupA, 14);
      expect(i.evidence!.groupB, 14);
      expect(i.evidence!.effectRatio, closeTo(2.0, 1e-9));
      expect(i.evidence!.strength, PatternStrength.strong);
    });

    test('the same gap on thin data reads as early', () {
      final i = CorrelationEngine.moodVsAdherence(adherence(
          adherent: 5, adherentValue: 1.0, missed: 5, missedValue: 2.0))!;
      expect(i.evidence!.strength, PatternStrength.early);
      expect(i.evidence!.line, 'Based on 5 vs 5 days · Early signal');
    });

    test('blood pressure vs adherence: against a 5 mmHg floor', () {
      final i = CorrelationEngine.bloodPressureVsAdherence(adherence(
          adherent: 10, adherentValue: 120, missed: 9, missedValue: 135))!;
      expect(i.evidence!.groupA, 10);
      expect(i.evidence!.groupB, 9);
      expect(i.evidence!.effectRatio, closeTo(3.0, 1e-9));
      expect(i.evidence!.strength, PatternStrength.moderate,
          reason: 'a wide gap, but 9 days is under the 14 strong asks for');
    });

    test('hydration vs adherence: the difference runs the other way round',
        () {
      // Adherent days drink MORE; against a 200 ml floor a 400 ml gap is 2.0.
      final i = CorrelationEngine.hydrationVsAdherence(adherence(
          adherent: 15, adherentValue: 2400, missed: 15, missedValue: 2000))!;
      expect(i.evidence!.effectRatio, closeTo(2.0, 1e-9));
      expect(i.evidence!.strength, PatternStrength.strong);
    });

    test('focus vs sleep and hydration vs sleep', () {
      final base = DateTime(2026, 1, 1);
      List<GroupedDay> grouped(int n, double longV, double shortV) => [
            for (var i = 0; i < n; i++)
              GroupedDay(
                  day: base.add(Duration(days: i)), inGroup: true, value: longV),
            for (var i = 0; i < n; i++)
              GroupedDay(
                  day: base.add(Duration(days: 100 + i)),
                  inGroup: false,
                  value: shortV),
          ];

      final focus = CorrelationEngine.focusVsSleep(grouped(8, 0.9, 0.6))!;
      expect(focus.evidence!.groupA, 8);
      expect(focus.evidence!.effectRatio, closeTo(2.0, 1e-9)); // 0.3 / 0.15
      expect(focus.evidence!.strength, PatternStrength.moderate);

      final water = CorrelationEngine.hydrationVsSleep(grouped(6, 2400, 2000))!;
      expect(water.evidence!.groupB, 6);
      expect(water.evidence!.effectRatio, closeTo(2.0, 1e-9)); // 400 / 200
      expect(water.evidence!.strength, PatternStrength.early);
    });
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester, Insight insight) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: InsightCard(insight: insight)),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    const plain = Insight(
      id: 'x',
      feature: InsightFeature.crossCutting,
      severity: InsightSeverity.info,
      title: 'Mood tends to dip on missed-dose days',
      detail: 'A pattern in your own data.',
      why: 'Group means.',
    );

    testWidgets('shows the sample and the strength under the detail',
        (tester) async {
      await pump(
          tester,
          Insight(
            id: plain.id,
            feature: plain.feature,
            severity: plain.severity,
            title: plain.title,
            detail: plain.detail,
            why: plain.why,
            evidence: ev(9, 7, 1.6),
          ));
      expect(find.text('Based on 9 vs 7 days · Early signal'), findsOneWidget);
    });

    testWidgets('an insight that is not a comparison shows nothing of the kind',
        (tester) async {
      await pump(tester, plain);
      expect(find.textContaining('Based on'), findsNothing);
    });
  });
}
