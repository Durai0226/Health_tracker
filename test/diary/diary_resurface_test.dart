/// Finding an entry again, and meeting an old one: search, "On this day", and
/// the prompt the Diary offers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/diary/models/diary_entry.dart';
import 'package:tablet_remainder/features/diary/services/diary_prompts.dart';
import 'package:tablet_remainder/features/diary/services/diary_search.dart';
import 'package:tablet_remainder/features/diary/services/on_this_day.dart';

DiaryEntry entry(
  String id, {
  String? title,
  String body = 'a day',
  DateTime? at,
  int? mood,
  List<String> tags = const [],
}) {
  final when = at ?? DateTime(2026, 3, 1, 20);
  return DiaryEntry(
    id: id,
    title: title,
    body: body,
    entryAt: when,
    createdAt: when,
    moodIndex: mood,
    tags: tags,
  );
}

void main() {
  group('search', () {
    final entries = [
      entry('a', title: 'Garden', body: 'Planted the tomatoes.'),
      entry('b', body: 'Long walk by the river with Sam.', tags: ['walk', 'friends']),
      entry('c', body: 'Rough one. Could not switch off.', mood: 3),
      entry('d', body: 'Tomatoes again, and a short night.', tags: ['rest']),
    ];

    List<String> ids(String q) =>
        [for (final e in DiarySearch.filter(entries, q)) e.id];

    test('a blank query is everything, in order', () {
      expect(ids(''), ['a', 'b', 'c', 'd']);
      expect(ids('   '), ['a', 'b', 'c', 'd']);
    });

    test('matches the title and the body, ignoring case', () {
      expect(ids('GARDEN'), ['a']);
      expect(ids('tomatoes'), ['a', 'd']);
    });

    test('matches a tag by the name it is shown under', () {
      expect(ids('friends'), ['b']);
      expect(ids('rest'), ['d']);
    });

    test('and a mood by its name', () {
      expect(ids('bad'), ['c']);
    });

    test('every word has to be there, in any order', () {
      expect(ids('tomatoes night'), ['d']);
      expect(ids('night tomatoes'), ['d']);
      expect(ids('tomatoes river'), isEmpty);
    });

    test('extra spaces do not matter', () {
      expect(ids('  walk    river '), ['b']);
    });

    test('nothing matches nothing', () {
      expect(ids('zebra'), isEmpty);
    });

    test('a mood out of range does not throw', () {
      expect(
          DiarySearch.filter([entry('x', body: 'odd', mood: 9)], 'odd'), hasLength(1));
    });
  });

  group('on this day', () {
    final today = DateTime(2026, 6, 15, 9);

    List<String> ids(List<DiaryEntry> es, {DateTime? on}) => [
          for (final i in OnThisDay.forDay(es, on ?? today)) i.entry.id,
        ];

    test('the same date in an earlier year', () {
      final es = [
        entry('last', at: DateTime(2025, 6, 15, 21)),
        entry('other', at: DateTime(2025, 6, 16, 21)),
      ];
      expect(ids(es), ['last']);
    });

    test('never this year: that is just today', () {
      expect(ids([entry('now', at: DateTime(2026, 6, 15, 8))]), isEmpty);
    });

    test('the most recent year first, and how long ago each was', () {
      final es = [
        entry('old', at: DateTime(2022, 6, 15)),
        entry('new', at: DateTime(2025, 6, 15)),
        entry('mid', at: DateTime(2024, 6, 15)),
      ];
      final items = OnThisDay.forDay(es, today);
      expect([for (final i in items) i.entry.id], ['new', 'mid', 'old']);
      expect([for (final i in items) i.label],
          ['1 year ago', '2 years ago', '4 years ago']);
    });

    test('two on the same date in one year: the later one first', () {
      final es = [
        entry('morning', at: DateTime(2025, 6, 15, 8)),
        entry('night', at: DateTime(2025, 6, 15, 22)),
      ];
      expect(ids(es), ['night', 'morning']);
    });

    test('no more than three', () {
      final es = [
        for (var y = 2019; y < 2026; y++) entry('y$y', at: DateTime(y, 6, 15)),
      ];
      expect(ids(es), ['y2025', 'y2024', 'y2023']);
      expect(OnThisDay.forDay(es, today, max: 5), hasLength(5));
    });

    test('29 February comes round on 28 February in a year without one', () {
      final es = [entry('leap', at: DateTime(2024, 2, 29, 12))];
      expect(ids(es, on: DateTime(2026, 2, 28)), ['leap']);
      expect(ids(es, on: DateTime(2026, 3, 1)), isEmpty);
    });

    test('and on 29 February itself in a leap year, not the day before', () {
      final es = [entry('leap', at: DateTime(2020, 2, 29, 12))];
      expect(ids(es, on: DateTime(2028, 2, 29)), ['leap']);
      expect(ids(es, on: DateTime(2028, 2, 28)), isEmpty);
    });

    test('28 February keeps its own entries in a year without a 29th', () {
      final es = [
        entry('own', at: DateTime(2025, 2, 28)),
        entry('leap', at: DateTime(2024, 2, 29)),
      ];
      expect(ids(es, on: DateTime(2026, 2, 28)), ['own', 'leap']);
    });

    test('a diary with nothing in it has nothing on this day', () {
      expect(OnThisDay.forDay(const [], today), isEmpty);
    });
  });

  group('the prompt', () {
    DiaryPrompt? pick({
      bool wroteToday = false,
      int? sleep,
      int missed = 0,
      int? mood,
    }) =>
        DiaryPrompts.pick(
          wroteToday: wroteToday,
          sleepMinutes: sleep,
          missedDosesYesterday: missed,
          recentMoodIndex: mood,
        );

    test('a short night asks what got in the way', () {
      final p = pick(sleep: 5 * 60)!;
      expect(p.id, 'short_night');
      expect(p.text, 'What got in the way of sleep?');
    });

    test('six hours is not short; nor is no sleep recorded', () {
      expect(pick(sleep: 6 * 60), isNull);
      expect(pick(sleep: 0), isNull);
      expect(pick(sleep: null), isNull);
    });

    test('a missed dose yesterday', () {
      expect(pick(missed: 1)!.id, 'missed_dose');
    });

    test('a low mood, and a great one', () {
      expect(pick(mood: 3)!.id, 'low_mood');
      expect(pick(mood: 4)!.id, 'low_mood');
      expect(pick(mood: 0)!.id, 'great_mood');
    });

    test('an ordinary mood, or nothing at all, prompts nothing', () {
      expect(pick(mood: 1), isNull);
      expect(pick(mood: 2), isNull);
      expect(pick(), isNull);
    });

    test('the order: sleep, then a dose, then the mood', () {
      expect(pick(sleep: 300, missed: 2, mood: 4)!.id, 'short_night');
      expect(pick(missed: 2, mood: 4)!.id, 'missed_dose');
      expect(pick(mood: 4)!.id, 'low_mood');
    });

    test('a day that already has an entry prompts nothing', () {
      expect(pick(wroteToday: true, sleep: 240, missed: 1, mood: 4), isNull);
    });
  });
}
