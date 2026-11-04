/// The mood report: how a window of days went, and the PDF made from it.
///
/// The log's scale runs 0 = Great … 4 = Terrible; the report reads a day's score
/// the other way (4 = Great), the way the tag patterns do. Both ends of that, the
/// window's edges and what the PDF leaves out are the places this can go wrong.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/services/mood_report_service.dart';

import '../support/pdf_words.dart';

void main() {
  // A Wednesday, late in the day, so "today" is not midnight.
  final now = DateTime(2026, 9, 30, 21, 30);

  var n = 0;
  MoodEntry entry(DateTime at, int index,
          {List<String> tags = const [], String? note}) =>
      MoodEntry(
          id: 'm${n++}',
          moodIndex: index,
          takenAt: at,
          tags: tags,
          note: note,
          createdAt: at);

  /// An entry on September [day] at noon.
  MoodEntry sep(int day, int index, {List<String> tags = const [], String? note}) =>
      entry(DateTime(2026, 9, day, 12), index, tags: tags, note: note);

  MoodReportSummary sum(List<MoodEntry> e, {int days = 30}) =>
      MoodReportService.summarize(e, windowDays: days, now: now);

  group('the label for an average', () {
    test('each level of the scale reads as itself', () {
      expect(MoodReportService.labelForScore(4), 'Great');
      expect(MoodReportService.labelForScore(3), 'Good');
      expect(MoodReportService.labelForScore(2), 'Okay');
      expect(MoodReportService.labelForScore(1), 'Bad');
      expect(MoodReportService.labelForScore(0), 'Terrible');
    });

    test('between levels it rounds to the nearer, and a half goes to the better',
        () {
      expect(MoodReportService.labelForScore(3.4), 'Good');
      expect(MoodReportService.labelForScore(3.5), 'Good');
      expect(MoodReportService.labelForScore(2.5), 'Okay');
      expect(MoodReportService.labelForScore(0.4), 'Terrible');
    });
  });

  group('the window', () {
    test('is the days ending today, both ends included', () {
      final s = sum([
        entry(DateTime(2026, 9, 1, 0, 0), 0), // first day of 30, at midnight
        entry(DateTime(2026, 8, 31, 23, 59), 0), // the day before: out
        entry(DateTime(2026, 9, 30, 23, 59), 0), // today, late: in
        entry(DateTime(2026, 10, 1, 0, 1), 0), // tomorrow: out
      ]);
      expect(s.start, DateTime(2026, 9, 1));
      expect(s.end, DateTime(2026, 9, 30));
      expect(s.entries, 2);
      expect([for (final d in s.days) d.day], [DateTime(2026, 9, 1), DateTime(2026, 9, 30)]);
    });

    test('counts back across a month boundary', () {
      final s = MoodReportService.summarize(const [],
          windowDays: 30, now: DateTime(2026, 3, 5, 12));
      expect(s.start, DateTime(2026, 2, 4));
    });

    test('nothing logged is empty, with nothing to average', () {
      final s = sum(const []);
      expect(s.isEmpty, isTrue);
      expect(s.average, isNull);
      expect(s.averageLabel, isNull);
      expect(s.daysLogged, 0);
      expect(s.weeks, isEmpty, reason: 'a column of gaps says nothing');
      expect(s.levelEntries, [0, 0, 0, 0, 0]);
    });
  });

  group('the average', () {
    test('a day logged twice is the mean of the two', () {
      final s = sum([sep(10, 0), sep(10, 4)]); // Great and Terrible
      expect(s.days.single.score, 2.0);
      expect(s.days.single.entries, 2);
      expect(s.averageLabel, 'Okay');
    });

    test('each day counts once, however many times it was logged', () {
      // Four Greats on one day and a single Terrible on another: by entry that is
      // 3.2 ("Good"); by day it is 2.0 ("Okay").
      final s = sum([sep(10, 0), sep(10, 0), sep(10, 0), sep(10, 0), sep(11, 4)]);
      expect(s.average, 2.0);
      expect(s.averageLabel, 'Okay');
      expect(s.entries, 5);
    });

    test('the levels count entries, on the log\'s own scale', () {
      final s = sum([sep(1, 0), sep(1, 0), sep(2, 1), sep(3, 4)]);
      expect(s.levelEntries, [2, 1, 0, 0, 1]);
    });
  });

  group('week by week', () {
    test('a week is just the average: nothing under two weeks', () {
      expect(sum([sep(30, 1)], days: 7).weeks, isEmpty);
      expect(sum([sep(30, 1)], days: 13).weeks, isEmpty);
    });

    test('blocks of seven counted back from today; the oldest may be short', () {
      final s = sum([sep(30, 0), sep(24, 0), sep(1, 4)]);
      // 30 days: 24–30, 17–23, 10–16, 3–9, then 1–2.
      expect(s.weeks, hasLength(5));
      expect(s.weeks.first.start, DateTime(2026, 9, 24));
      expect(s.weeks.first.end, DateTime(2026, 9, 30));
      expect(s.weeks.last.start, DateTime(2026, 9, 1));
      expect(s.weeks.last.end, DateTime(2026, 9, 2));
      expect(s.weeks.first.daysLogged, 2);
      expect(s.weeks.first.score, 4.0);
      expect(s.weeks.last.daysLogged, 1);
      expect(s.weeks.last.score, 0.0);
    });

    test('a week with nothing logged is a gap, not a middling mood', () {
      final s = sum([sep(30, 0), sep(1, 0)]);
      final gap = s.weeks[1];
      expect(gap.daysLogged, 0);
      expect(gap.score, isNull);
    });
  });

  group('harder days', () {
    test('Bad and Terrible days, newest first; Okay is not one', () {
      final s = sum([
        sep(5, 3), // Bad
        sep(9, 2), // Okay
        sep(12, 4), // Terrible
        sep(20, 0),
      ]);
      expect([for (final d in s.hardDays) d.day.day], [12, 5]);
    });

    test('a day that averages to Bad and a half counts; one that averages Okay does not',
        () {
      final s = sum([
        sep(5, 3), sep(5, 4), // 1 and 0 -> 0.5
        sep(6, 2), sep(6, 3), // 2 and 1 -> 1.5: the limit, included
        sep(7, 1), sep(7, 3), // 3 and 1 -> 2.0
      ]);
      expect([for (final d in s.hardDays) d.day.day], [6, 5]);
    });
  });

  group('tags', () {
    test('count the days they were on, not the entries', () {
      // 'work' is met first, so a tie that fell back on the order the tags were
      // seen in would list it ahead of 'walk'.
      final s = sum([
        sep(1, 1, tags: ['work']),
        sep(1, 1, tags: ['work']),
        sep(2, 1, tags: ['walk', 'work']),
        sep(3, 1, tags: ['walk']),
        sep(4, 1, tags: ['hobby']),
      ]);
      expect([for (final t in s.topTags) (t.tag, t.days)],
          [('walk', 2), ('work', 2)],
          reason: 'one day is not enough to list; ties go by name');
    });

    test('at most five are listed, most days first', () {
      final tags = ['walk', 'exercise', 'friends', 'family', 'work', 'rest'];
      final entries = <MoodEntry>[];
      for (var i = 0; i < tags.length; i++) {
        // tag i is on (6 - i) days, so the order is the list's own.
        for (var d = 0; d < 6 - i + 1; d++) {
          entries.add(sep(1 + d, 1, tags: [tags[i]]));
        }
      }
      final s = sum(entries);
      expect(s.topTags, hasLength(5));
      expect(s.topTags.first.tag, 'walk');
      expect([for (final t in s.topTags) t.tag], isNot(contains('rest')));
    });
  });

  group('patterns', () {
    test('a tag that goes with better days is surfaced, from the window\'s days',
        () {
      final e = <MoodEntry>[
        for (var d = 1; d <= 5; d++) sep(d, 0, tags: ['walk']), // Great
        for (var d = 6; d <= 10; d++) sep(d, 3), // Bad
      ];
      final s = sum(e);
      expect(s.patterns.map((p) => p.id), contains('mood_tag_walk'));
    });

    test('too few days: nothing to say', () {
      final s = sum([sep(1, 0, tags: ['walk']), sep(2, 3)]);
      expect(s.patterns, isEmpty);
    });
  });

  group('the PDF', () {
    Future<String> pdf(MoodReportSummary s, {String? patient}) async =>
        pdfWords(await MoodReportService.buildPdf(s,
                patientName: patient, generatedAt: DateTime(2026, 10, 1)))
            .join(' ');

    test('is a PDF', () async {
      final bytes = await MoodReportService.buildPdf(sum([sep(5, 1)]));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('says what it is, for whom, which days and when it was made', () async {
      final t = await pdf(sum([sep(5, 1)]), patient: 'Asha');
      expect(t, contains('Mood Report'));
      expect(t, contains('Patient: Asha'));
      expect(t, contains('Period: 2026-09-01 to 2026-09-30'));
      expect(t, contains('Generated: 2026-10-01'));
    });

    test('names no patient when there is none', () async {
      expect(await pdf(sum([sep(5, 1)])), isNot(contains('Patient:')));
    });

    test('the headline is the average of the days, with how many were logged',
        () async {
      final t = await pdf(sum([sep(5, 1), sep(6, 1), sep(6, 2)]));
      // Days: 5 -> 3.0, 6 -> 2.5; mean 2.75 -> Good.
      expect(t, contains('Good'));
      expect(t, contains('average mood'));
      expect(t, contains('2 of 30 days logged'));
      expect(t, contains('3 entries'));
    });

    test('lists every level with its count and share', () async {
      final t = await pdf(sum([sep(1, 0), sep(2, 0), sep(3, 1), sep(4, 4)]));
      for (final level in ['Great', 'Good', 'Okay', 'Bad', 'Terrible']) {
        expect(t, contains(level));
      }
      expect(t, contains('50%')); // two of four are Great
    });

    test('a week-by-week table only when there are weeks to show', () async {
      expect(await pdf(sum([sep(30, 1)])), contains('Week by week'));
      expect(await pdf(sum([sep(30, 1)], days: 7)), isNot(contains('Week by week')));
    });

    test('harder days are listed with their date and tags, or not at all',
        () async {
      final hard = await pdf(sum([sep(5, 4, tags: ['work']), sep(6, 0)]));
      expect(hard, contains('Days rated Bad or Terrible'));
      expect(hard, contains('1 of 2 days logged'));
      expect(hard, contains('2026-09-05'));
      expect(hard, contains('Work'));

      expect(await pdf(sum([sep(6, 0)])), isNot(contains('Days rated Bad or Terrible')));
    });

    test('lists at most the twelve most recent harder days, and says so', () async {
      final e = [for (var d = 1; d <= 15; d++) sep(d, 4)];
      final t = await pdf(sum(e));
      expect(t, contains('15 of 15 days logged'));
      expect(t, contains('the most recent 12 are listed'));
      // "date Mood": a row of the harder-days table, which the week table's
      // "2026-09-03 to 2026-09-09" is not.
      expect(t, contains('2026-09-15 Terrible'));
      expect(t, contains('2026-09-04 Terrible'));
      expect(t, isNot(contains('2026-09-03 Terrible')),
          reason: 'the oldest three fall off the list');
      expect(t, isNot(contains('2026-09-01 Terrible')));
    });

    test('the notes never reach the file', () async {
      final t = await pdf(sum([
        sep(5, 4, note: 'argued with my sister about the money'),
        sep(6, 1, note: 'அம்மா'),
      ]));
      expect(t, isNot(contains('sister')));
      expect(t, isNot(contains('money')));
    });

    test('carries the not-a-diagnosis line', () async {
      final t = await pdf(sum([sep(5, 1)]));
      expect(t, contains('not a'));
      expect(t, contains('diagnosis'));
      expect(t, contains('talk to a clinician'));
    });

    test('with nothing logged it says so and prints no tables', () async {
      final t = await pdf(sum(const []));
      expect(t, contains('Nothing logged in this period'));
      expect(t, isNot(contains('How the entries felt')));
      expect(t, isNot(contains('Week by week')));
    });

    test('shows a pattern when the days support one', () async {
      final e = <MoodEntry>[
        for (var d = 1; d <= 5; d++) sep(d, 0, tags: ['walk']),
        for (var d = 6; d <= 10; d++) sep(d, 3),
      ];
      final t = await pdf(sum(e));
      expect(t, contains('Patterns in these entries'));
      expect(t, contains('Mood tends to be better on days with a walk'));
    });
  });
}
