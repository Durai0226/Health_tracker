import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/core/health/focus_insights.dart';

/// The two pieces of new pure logic behind the Focus coach line.
///
/// Both are deliberately shy: they return null / say nothing when the evidence is
/// thin. That is the behaviour most worth pinning, because it is the behaviour a
/// future change is most likely to "improve" away — a suggestion is more visible
/// than its absence, and a confident recommendation drawn from two sessions is
/// worse than silence, since the user cannot tell which one they are being given.
void main() {
  List<FocusSessionRef> refs(List<int> minutes, {bool completed = true}) => [
        for (final m in minutes)
          FocusSessionRef(startHour: 10, minutes: m, completed: completed),
      ];

  group('suggestedMinutes — the length you actually finish', () {
    test('says nothing below five completed sessions', () {
      for (var n = 0; n < 5; n++) {
        expect(FocusInsights.suggestedMinutes(refs(List.filled(n, 25))), isNull,
            reason: 'with $n session(s) there is no basis for a suggestion, and '
                'the honest output is none');
      }
      expect(FocusInsights.suggestedMinutes(refs(List.filled(5, 25))), 25,
          reason: 'sanity: the boundary is inclusive, so the null results above '
              'are the rule and not a broken function');
    });

    test('abandoned sessions do not count towards the threshold', () {
      // The ambition is not the capacity. Ten abandoned 60-minute attempts say
      // nothing about what this user can finish, and feeding them back in would
      // keep recommending the length that is not working.
      expect(FocusInsights.suggestedMinutes(refs(List.filled(10, 60),
              completed: false)),
          isNull);
    });

    test('measures what was completed, not what was attempted', () {
      final mixed = <FocusSessionRef>[
        ...refs([20, 20, 20, 20, 20]),
        ...refs([90, 90, 90, 90, 90], completed: false),
      ];
      expect(FocusInsights.suggestedMinutes(mixed), 20,
          reason: 'a user who sets 90 and finishes 20 should be offered 20');
    });

    test('the median resists one outlier', () {
      // A single 180-minute marathon must not drag the suggestion up for weeks,
      // which is exactly what a mean would do (mean here is 52).
      expect(FocusInsights.suggestedMinutes(refs([20, 25, 25, 30, 180])), 25);
    });

    test('rounds to the nearest five so the app never suggests 19', () {
      expect(FocusInsights.suggestedMinutes(refs([19, 19, 19, 19, 19])), 20);
      expect(FocusInsights.suggestedMinutes(refs([23, 23, 23, 23, 23])), 25);
    });

    test('clamps into a range a session can plausibly be', () {
      expect(FocusInsights.suggestedMinutes(refs([1, 1, 1, 1, 1])), 5);
      expect(FocusInsights.suggestedMinutes(refs([600, 600, 600, 600, 600])), 120);
    });

    test('an even count averages the two middle values', () {
      // Rewritten: the first version of this test pinned nothing, and an audit
      // caught it.
      //
      //  * `refs([10,20,30,40])..addAll(refs([50]))` is a CASCADE — it returns the
      //    original list with 50 appended, so arity 5. An "even count" test that
      //    silently tested an odd one.
      //  * `[20,20,30,30,30,30]` is even, but both middle values are 30, so
      //    averaging them and picking either one give the same answer. It could
      //    not distinguish the behaviour it was named after.
      //
      // Six values, distinct middles: 20 and 30 -> 25. Picking the lower would
      // give 20 and picking the upper 30, so only averaging passes.
      expect(FocusInsights.suggestedMinutes(refs([5, 10, 20, 30, 60, 90])), 25);

      // And the odd case still resolves to the true middle, not an average.
      expect(FocusInsights.suggestedMinutes(refs([10, 20, 30, 40, 50])), 30);
    });
  });

  group('focusCoach — warm, and never a threat', () {
    const coach = CoachText();

    test('never uses loss-aversion language', () {
      // The line this replaced was: "Keep your 3-day streak alive — a single
      // 25-minute session today does it." CHI 2020 found streak anxiety to be the
      // leading reason people abandon habit trackers, and rigid-streak users 63%
      // more likely to quit after ONE missed day. Framing a session as avoiding
      // punishment is the mechanism being avoided here.
      const banned = [
        'alive',
        'don\'t lose',
        'dont lose',
        'lose your',
        'break your',
        'failed',
        'you missed',
      ];
      final lines = <String>[
        for (final today in [0, 10, 40])
          for (final streak in [0, 1, 3, 30])
            for (final grace in [true, false])
              coach.focusCoach(
                todayMinutes: today,
                streakDays: streak,
                totalSessions: 12,
                usedGraceDay: grace,
                bestHour: 14,
                suggestedMinutes: 20,
              ),
      ];
      expect(lines, isNotEmpty, reason: 'sanity: the matrix produced lines');
      for (final line in lines) {
        for (final word in banned) {
          expect(line.toLowerCase(), isNot(contains(word)),
              reason: 'loss-aversion phrasing crept back in: "$line"');
        }
      }
    });

    test('a grace day is stated out loud, retroactively', () {
      // StreakEngine has always forgiven one miss per rolling week and the result
      // was discarded, so the user was protected and never told. The reassurance
      // is the half that changes behaviour.
      final line = coach.focusCoach(
        todayMinutes: 0,
        streakDays: 4,
        totalSessions: 20,
        usedGraceDay: true,
      );
      expect(line, contains('grace day'));
      expect(line, contains('4'),
          reason: 'it must say the streak survived, with the number intact');
    });

    test('the best hour is only mentioned when it is known', () {
      final withHour = coach.focusCoach(
          todayMinutes: 0, streakDays: 0, totalSessions: 8, bestHour: 14);
      expect(withHour, contains('2 PM'));

      final withoutHour = coach.focusCoach(
          todayMinutes: 0, streakDays: 0, totalSessions: 8);
      expect(withoutHour, isNot(contains('PM')));
      expect(withoutHour, isNot(contains('null')),
          reason: 'a missing insight must be absent, not interpolated');
    });

    test('falls back to 25 minutes only while the real length is unknown', () {
      expect(
          coach.focusCoach(
              todayMinutes: 0, streakDays: 0, totalSessions: 0),
          contains('25'));
      expect(
          coach.focusCoach(
              todayMinutes: 0,
              streakDays: 0,
              totalSessions: 30,
              suggestedMinutes: 15),
          contains('15'));
    });

    test('no line interpolates a null or reads as a placeholder', () {
      for (final today in [0, 5, 25, 200]) {
        for (final streak in [0, 1, 9]) {
          final line = coach.focusCoach(
              todayMinutes: today, streakDays: streak, totalSessions: 3);
          expect(line, isNot(contains('null')));
          expect(line.trim(), isNotEmpty);
        }
      }
    });
  });
}
