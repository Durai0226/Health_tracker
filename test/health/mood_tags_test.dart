/// Mood tags: what the day earns by itself, and what goes with better days.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/mood_tag_insights.dart';
import 'package:tablet_remainder/core/health/mood_tags.dart';

void main() {
  group('names', () {
    test('every id the app offers has a label and a phrase', () {
      for (final id in [...MoodTags.manual, ...MoodTags.automatic]) {
        expect(MoodTags.label(id), isNot(id), reason: id);
        expect(MoodTags.phrase(id), isNotEmpty);
      }
    });

    test('an id from a later version is shown, not dropped', () {
      expect(MoodTags.label('hot_day'), 'Hot Day');
      expect(MoodTags.phrase('hot_day'), 'hot day');
    });

    test('which are automatic', () {
      expect(MoodTags.isAutomatic('short_night'), isTrue);
      expect(MoodTags.isAutomatic('walk'), isFalse);
    });

    test('the two lists do not overlap', () {
      expect(MoodTags.manual.toSet().intersection(MoodTags.automatic.toSet()),
          isEmpty);
    });
  });

  group('what the day earns', () {
    List<String> day({
      int? sleep,
      int? steps,
      int? goal,
      bool over = false,
      bool bleeding = false,
      int due = 0,
      int taken = 0,
      int missed = 0,
    }) =>
        MoodTags.forDay(
          sleepMinutes: sleep,
          steps: steps,
          stepGoal: goal,
          dayIsOver: over,
          bleeding: bleeding,
          dosesDue: due,
          dosesTaken: taken,
          dosesMissed: missed,
        );

    test('a night of seven hours is well slept; under six is short; between '
        'is neither', () {
      expect(day(sleep: 420), ['slept_well']);
      expect(day(sleep: 419), isEmpty);
      expect(day(sleep: 360), isEmpty);
      expect(day(sleep: 359), ['short_night']);
    });

    test('no night recorded is no sleep tag', () {
      expect(day(), isEmpty);
      expect(day(sleep: 0), isEmpty);
    });

    test('reaching the step goal is an active day, at any hour', () {
      expect(day(steps: 8000, goal: 8000), ['active_day']);
      expect(day(steps: 9500, goal: 8000, over: true), ['active_day']);
    });

    test('a quiet day needs the day to be over, and some steps', () {
      expect(day(steps: 2000, goal: 8000, over: true), ['quiet_day']);
      expect(day(steps: 2000, goal: 8000), isEmpty,
          reason: 'steps are still being counted until the day is over');
      expect(day(steps: 0, goal: 8000, over: true), isEmpty,
          reason: 'no steps read is not a quiet day');
      expect(day(steps: 3200, goal: 8000, over: true), isEmpty,
          reason: '40% is the line: at it, neither');
      expect(day(steps: 3199, goal: 8000, over: true), ['quiet_day']);
    });

    test('no goal, no activity tag', () {
      expect(day(steps: 9000), isEmpty);
      expect(day(steps: 9000, goal: 0), isEmpty);
    });

    test('bleeding is a period', () {
      expect(day(bleeding: true), ['period']);
    });

    test('every due dose taken is a tag; a missed one beats it', () {
      expect(day(due: 3, taken: 3), ['took_doses']);
      expect(day(due: 3, taken: 2), isEmpty,
          reason: 'one still to take is not yet either');
      expect(day(due: 3, taken: 2, missed: 1), ['missed_dose']);
      expect(day(due: 3, taken: 3, missed: 1), ['missed_dose'],
          reason: 'a missed dose is said even beside taken ones');
      expect(day(), isEmpty, reason: 'nothing due says nothing');
    });

    test('several can hold at once, in a steady order', () {
      expect(
          day(sleep: 300, steps: 9000, goal: 8000, bleeding: true, due: 2, taken: 2),
          ['short_night', 'active_day', 'period', 'took_doses']);
    });
  });

  group('what goes with better days', () {
    var d = 0;
    List<DayMood> days(int n, double score, Set<String> tags) => [
          for (var i = 0; i < n; i++)
            DayMood(
                day: DateTime(2026, 1, 1 + d++), score: score, tags: tags),
        ];

    test('a tag on better days is a win, with the sample and the size', () {
      final out = MoodTagInsights.insights([
        ...days(11, 3.0, {'walk'}),
        ...days(14, 2.2, {}),
      ]);
      expect(out, hasLength(1));
      final i = out.single;
      expect(i.id, 'mood_tag_walk');
      expect(i.title, 'Mood tends to be better on days with a walk');
      expect(i.severity, InsightSeverity.good);
      expect(i.metric, '+0.8');
      expect(i.detail, contains('averaged 3.0 out of 4 on the 11 days'));
      expect(i.detail, contains('2.2 on the other 14'));
      expect(i.detail, contains('not a sign that one causes the other'));
      expect(i.evidence!.groupA, 11);
      expect(i.evidence!.groupB, 14);
      expect(i.evidence!.line, startsWith('Based on 11 vs 14 days'));
    });

    test('a tag on lower days is a note, in the other direction', () {
      final out = MoodTagInsights.insights([
        ...days(8, 1.5, {'short_night'}),
        ...days(12, 2.6, {}),
      ]);
      final i = out.single;
      expect(i.title, 'Mood tends to be lower on days with a short night');
      expect(i.severity, InsightSeverity.info);
      expect(i.metric, '-1.1');
    });

    test('too few days on either side says nothing', () {
      expect(
          MoodTagInsights.insights([
            ...days(4, 3.5, {'walk'}),
            ...days(20, 2.0, {}),
          ]),
          isEmpty);
      expect(
          MoodTagInsights.insights([
            ...days(20, 3.5, {'walk'}),
            ...days(4, 2.0, {}),
          ]),
          isEmpty);
    });

    test('exactly five on each side is enough', () {
      expect(
          MoodTagInsights.insights([
            ...days(5, 3.5, {'walk'}),
            ...days(5, 2.0, {}),
          ]),
          hasLength(1));
    });

    test('a gap under half a point is not worth a word; half is', () {
      expect(
          MoodTagInsights.insights([
            ...days(10, 2.7, {'walk'}),
            ...days(10, 2.3, {}),
          ]),
          isEmpty);
      expect(
          MoodTagInsights.insights([
            ...days(10, 2.75, {'walk'}),
            ...days(10, 2.25, {}),
          ]),
          hasLength(1));
    });

    test('the three largest gaps, largest first', () {
      final out = MoodTagInsights.insights([
        // Each tag is on its own 6 days; a long untagged baseline beneath.
        ...days(6, 3.9, {'walk'}),
        ...days(6, 3.5, {'friends'}),
        ...days(6, 3.2, {'rest'}),
        ...days(6, 3.0, {'hobby'}),
        ...days(24, 1.5, {}),
      ]);
      expect(out.map((i) => i.id),
          ['mood_tag_walk', 'mood_tag_friends', 'mood_tag_rest']);
    });

    test('a day with several tags counts for each', () {
      final out = MoodTagInsights.insights([
        ...days(8, 3.4, {'walk', 'friends'}),
        ...days(10, 2.0, {}),
      ]);
      expect(out.map((i) => i.id).toSet(), {'mood_tag_walk', 'mood_tag_friends'});
    });

    test('no days, no insights', () {
      expect(MoodTagInsights.insights(const []), isEmpty);
    });
  });
}
