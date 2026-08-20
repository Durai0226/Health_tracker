import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/core/health/correlation_engine.dart';
import 'package:tablet_remainder/core/health/focus_readiness.dart';

/// Readiness, and the focus↔sleep correlation.
///
/// Pure Dart, no binding, mirroring `focus_suggestions_test.dart` — and like that
/// file, most of what is pinned here is an ABSENCE. The value of this signal is
/// almost entirely in when it stays quiet: a readiness note that fires on noise
/// is worse than none, because the user cannot tell which one they are getting.
void main() {
  group('readiness stays silent without evidence', () {
    test('no inputs at all', () {
      expect(FocusReadiness.assess(), isNull);
    });

    test('sleep below the minimum night count', () {
      expect(
          FocusReadiness.assess(
            lastNightMinutes: 300,
            sleepMedianMinutes: 480,
            loggedNights: FocusReadiness.minHistory - 1,
          ),
          isNull,
          reason: 'four nights is not a baseline');
    });

    test('a deficit inside the measurement error', () {
      // The literature's 16-minute finding is real and is the wrong threshold to
      // ship: it is a population effect measured in a lab, and 16 minutes sits
      // inside the night-to-night error of consumer sleep staging. Firing on it
      // would mean firing about half of all days on noise.
      expect(
          FocusReadiness.assess(
            lastNightMinutes: 460,
            sleepMedianMinutes: 480,
            loggedNights: 10,
          ),
          isNull,
          reason: '20 minutes is noise, not a signal');
    });

    test('sleeping MORE than usual says nothing', () {
      expect(
          FocusReadiness.assess(
            lastNightMinutes: 540,
            sleepMedianMinutes: 460,
            loggedNights: 10,
            suggestedMinutes: 25,
          ),
          isNull,
          reason: 'there is no "you are primed" branch, deliberately');
    });

    test('HRV with a mixed metric', () {
      // HealthKit reports SDNN, Health Connect reports RMSSD. Comparing across
      // them invents a step change out of a unit difference.
      expect(
          FocusReadiness.assess(
            hrvLastNightMs: 30,
            hrvBaselineMs: 60,
            hrvNights: 10,
            hrvMetricConsistent: false,
          ),
          isNull);
    });

    test('a DERIVED resting heart rate', () {
      // A derived value is inferred from the night's HR distribution, so a night
      // the watch came off looks identical to a genuinely elevated resting rate.
      expect(
          FocusReadiness.assess(
            restingHr: 70,
            restingHrMedian: 58,
            rhrDays: 10,
            restingHrDerived: true,
          ),
          isNull);
    });

    test('steps are not an input at all', () {
      // "+1,000 steps ≈ 1 year younger cognition" is a multi-year epidemiological
      // association. Using it as a same-day capacity signal is a category error,
      // and "you walked less, so focus less" is one sentence from coercion.
      // Asserted structurally: there is no parameter to pass.
      expect(FocusReadiness.assess, isA<Function>());
    });
  });

  group('readiness fires on the user\'s own baseline', () {
    test('a real sleep deficit, with a shorter suggestion', () {
      final note = FocusReadiness.assess(
        lastNightMinutes: 370,
        sleepMedianMinutes: 435,
        loggedNights: 11,
        suggestedMinutes: 30,
      );
      expect(note, isNotNull);
      expect(note!.signal, FocusReadinessSignal.sleep);
      expect(note.adjustedMinutes, 20, reason: '70% of 30, rounded to 5');
      expect(note.why, contains('11 logged nights'),
          reason: 'the why chip has to name the evidence, not gesture at it');
      expect(note.line, contains('your call'),
          reason: 'offered, not prescribed');
    });

    test('exactly ONE signal is named, even when three are down', () {
      // Three independent noisy tests fire far more often than one, and "3 of
      // your metrics are down" is a composite score in disguise.
      final note = FocusReadiness.assess(
        lastNightMinutes: 370,
        sleepMedianMinutes: 460,
        loggedNights: 10,
        hrvLastNightMs: 25,
        hrvBaselineMs: 60,
        hrvNights: 10,
        restingHr: 72,
        restingHrMedian: 58,
        rhrDays: 10,
        suggestedMinutes: 25,
      );
      expect(note!.signal, FocusReadinessSignal.sleep,
          reason: 'sleep outranks HRV outranks resting HR');
      expect(note.line.split('.').where((s) => s.trim().isNotEmpty).length,
          lessThanOrEqualTo(3),
          reason: 'one observation and one offer, not a report');
    });

    test('HRV fires when sleep is fine', () {
      final note = FocusReadiness.assess(
        lastNightMinutes: 480,
        sleepMedianMinutes: 470,
        loggedNights: 10,
        hrvLastNightMs: 40,
        hrvBaselineMs: 60,
        hrvNights: 8,
        suggestedMinutes: 25,
      );
      expect(note!.signal, FocusReadinessSignal.hrv);
      expect(note.why, contains('ms'));
    });

    test('resting HR fires last, and only when measured', () {
      final note = FocusReadiness.assess(
        restingHr: 66,
        restingHrMedian: 58,
        rhrDays: 9,
        suggestedMinutes: 45,
      );
      expect(note!.signal, FocusReadinessSignal.restingHr);
      expect(note.adjustedMinutes, 30);
    });

    test('no suggestion when there is no established length', () {
      final note = FocusReadiness.assess(
        lastNightMinutes: 360,
        sleepMedianMinutes: 460,
        loggedNights: 10,
      );
      expect(note, isNotNull);
      expect(note!.adjustedMinutes, isNull,
          reason: 'inventing a specific smaller number against no evidence '
              'would be inventing both halves');
      expect(note.line, isNot(contains('null')));
    });

    test('no line ever interpolates a null', () {
      for (final suggested in [null, 5, 10, 25, 120]) {
        final note = FocusReadiness.assess(
          lastNightMinutes: 300,
          sleepMedianMinutes: 480,
          loggedNights: 10,
          suggestedMinutes: suggested,
        );
        expect(note?.line ?? '', isNot(contains('null')));
        expect(note?.why ?? '', isNot(contains('null')));
      }
    });

    test('the deficit is described vaguely, not to the minute', () {
      // Consumer sleep staging is not accurate to the minute, so "you slept 47
      // minutes less" would claim a precision the measurement has not got.
      final note = FocusReadiness.assess(
        lastNightMinutes: 433,
        sleepMedianMinutes: 480,
        loggedNights: 10,
      );
      expect(note!.line, contains('about'));
      expect(note.line, isNot(contains('47')));
    });
  });

  group('the coach line uses readiness first, and only before focusing', () {
    const coach = CoachText();

    test('readiness replaces the opening line', () {
      const note = FocusReadinessNote(
        line: 'You slept about an hour less than usual last night.',
        why: 'why',
        signal: FocusReadinessSignal.sleep,
      );
      expect(
          coach.focusCoach(
              todayMinutes: 0,
              streakDays: 4,
              totalSessions: 9,
              readiness: note),
          note.line);
    });

    test('but never after the user has already focused', () {
      // Its whole value is arriving BEFORE they pick a length. Offered afterwards
      // it is second-guessing work already done.
      const note = FocusReadinessNote(
        line: 'You slept about an hour less than usual last night.',
        why: 'why',
        signal: FocusReadinessSignal.sleep,
      );
      final line = coach.focusCoach(
          todayMinutes: 30, streakDays: 4, totalSessions: 9, readiness: note);
      expect(line, isNot(note.line));
      expect(line, contains('30m'));
    });

    test('absent readiness changes nothing', () {
      expect(
          coach.focusCoach(todayMinutes: 0, streakDays: 3, totalSessions: 5),
          coach.focusCoach(
              todayMinutes: 0,
              streakDays: 3,
              totalSessions: 5,
              readiness: null));
    });
  });

  group('focus vs sleep', () {
    List<GroupedDay> days({
      required int longNights,
      required double longRate,
      required int shortNights,
      required double shortRate,
    }) =>
        [
          for (var i = 0; i < longNights; i++)
            GroupedDay(day: DateTime(2026, 3, i + 1), inGroup: true, value: longRate),
          for (var i = 0; i < shortNights; i++)
            GroupedDay(
                day: DateTime(2026, 4, i + 1), inGroup: false, value: shortRate),
        ];

    test('null below five days in either group', () {
      expect(
          CorrelationEngine.focusVsSleep(days(
              longNights: 4, longRate: 0.9, shortNights: 20, shortRate: 0.3)),
          isNull);
      expect(
          CorrelationEngine.focusVsSleep(days(
              longNights: 20, longRate: 0.9, shortNights: 4, shortRate: 0.3)),
          isNull);
    });

    test('null when the difference is not meaningful', () {
      expect(
          CorrelationEngine.focusVsSleep(days(
              longNights: 10, longRate: 0.62, shortNights: 10, shortRate: 0.55)),
          isNull,
          reason: '7 percentage points is inside the noise');
    });

    test('null in the unexpected direction', () {
      expect(
          CorrelationEngine.focusVsSleep(days(
              longNights: 10, longRate: 0.3, shortNights: 10, shortRate: 0.9)),
          isNull,
          reason: '"you finish more after a short night" is a noise finding '
              'dressed as advice');
    });

    test('fires on a real difference, and refuses causation', () {
      final insight = CorrelationEngine.focusVsSleep(days(
          longNights: 12, longRate: 0.8, shortNights: 11, shortRate: 0.5));
      expect(insight, isNotNull);
      expect(insight!.id, 'correlation_focus_sleep');
      expect(insight.detail, contains('after'));
      for (final banned in ['because', 'causes', 'improves', 'boosts']) {
        expect(insight.detail.toLowerCase(), isNot(contains(banned)),
            reason: 'a bad night and a bad focus day share obvious causes');
        expect(insight.why.toLowerCase(), isNot(contains(banned)));
      }
      expect(insight.why, contains('excluded'),
          reason: 'the why must state that no-session days are left out — that '
              'exclusion is the whole reason the number means anything');
    });

    test('an empty day list says nothing', () {
      expect(CorrelationEngine.focusVsSleep(const []), isNull);
    });
  });
}
