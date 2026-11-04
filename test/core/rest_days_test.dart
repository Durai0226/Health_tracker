import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/rest_days.dart';

void main() {
  final today = DateTime(2026, 3, 10, 15);

  test('a day round-trips through its stored form', () {
    final d = RestDay(DateTime(2026, 3, 10, 22, 5), RestKind.unwell);
    expect(d.day, DateTime(2026, 3, 10), reason: 'only the calendar day counts');
    expect(RestDay.decode(d.encode()), d);
    expect(d.encode(), '2026-03-10|unwell');
  });

  test('junk in storage is skipped, not thrown on', () {
    final decoded = RestDays.decodeAll(
        ['2026-03-10|rest', 'nonsense', '2026-03-11|party', '|rest', 42, null]);
    expect(decoded, [RestDay(DateTime(2026, 3, 10), RestKind.rest)]);
    expect(RestDays.decodeAll('not a list'), isEmpty);
    expect(RestDays.decodeAll(null), isEmpty);
  });

  test('marking replaces an earlier mark for the same day', () {
    var days = RestDays.mark(const [], today, RestKind.rest, today: today);
    days = RestDays.mark(days, today, RestKind.unwell, today: today);
    expect(days, [RestDay(today, RestKind.unwell)]);
    expect(RestDays.kindOn(days, DateTime(2026, 3, 10, 1)), RestKind.unwell);
  });

  test('unmarking removes only that day', () {
    var days = RestDays.mark(const [], DateTime(2026, 3, 9), RestKind.rest, today: today);
    days = RestDays.mark(days, today, RestKind.unwell, today: today);
    days = RestDays.unmark(days, today);
    expect(RestDays.kindOn(days, today), isNull);
    expect(RestDays.kindOn(days, DateTime(2026, 3, 9)), RestKind.rest);
  });

  test('frozen days stop at today: nothing has been missed in the future', () {
    final days = [
      RestDay(DateTime(2026, 3, 8), RestKind.rest),
      RestDay(today, RestKind.unwell),
      RestDay(DateTime(2026, 3, 12), RestKind.rest),
    ];
    expect(RestDays.frozenDays(days, today),
        {DateTime(2026, 3, 8), DateTime(2026, 3, 10)});
  });

  test('old marks are dropped; recent ones kept', () {
    final old = DateTime(2026, 3, 10 - RestDays.keepDays - 1);
    final edge = DateTime(2026, 3, 10 - RestDays.keepDays);
    var days = [RestDay(old, RestKind.rest), RestDay(edge, RestKind.rest)];
    days = RestDays.mark(days, today, RestKind.rest, today: today);
    expect(days.map((d) => d.day), [edge, DateTime(2026, 3, 10)]);
  });

  test('kindOn on an unmarked day is null', () {
    expect(RestDays.kindOn(const [], today), isNull);
  });

  group('a rest of a few days', () {
    test('marks that many days in a row from the start, today included', () {
      final days = RestDays.markRun(const [], today, RestKind.rest, 3, today: today);
      expect(days.map((d) => d.day), [
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 11),
        DateTime(2026, 3, 12),
      ]);
      expect(days.every((d) => d.kind == RestKind.rest), isTrue);
    });

    test('one day is the same as marking the day', () {
      expect(RestDays.markRun(const [], today, RestKind.rest, 1, today: today),
          RestDays.mark(const [], today, RestKind.rest, today: today));
    });

    test('never fewer than one day and never more than a week', () {
      expect(RestDays.markRun(const [], today, RestKind.rest, 0, today: today).length, 1);
      expect(RestDays.markRun(const [], today, RestKind.rest, -4, today: today).length, 1);
      expect(RestDays.markRun(const [], today, RestKind.rest, 30, today: today).length,
          RestDays.maxRunDays);
      expect(RestDays.maxRunDays, 7);
    });

    test('replaces what was marked on those days, and leaves the others', () {
      final before = [
        RestDay(DateTime(2026, 3, 8), RestKind.unwell),
        RestDay(DateTime(2026, 3, 11), RestKind.unwell),
      ];
      final days = RestDays.markRun(before, today, RestKind.rest, 3, today: today);
      expect(RestDays.kindOn(days, DateTime(2026, 3, 8)), RestKind.unwell);
      expect(RestDays.kindOn(days, DateTime(2026, 3, 11)), RestKind.rest);
    });

    test('steps by calendar day across a clock change', () {
      // 8 March 2026 is when the US clocks go forward: a 23-hour day. From late on
      // the 7th, adding 24 hours would land on the 9th and skip the 8th. (Only a
      // machine in a zone with daylight saving can tell; run with
      // `TZ=America/New_York`, as the DST tests here are.)
      final late = DateTime(2026, 3, 7, 23, 30);
      final days = RestDays.markRun(const [], late, RestKind.rest, 3, today: late);
      expect(days.map((d) => d.day),
          [DateTime(2026, 3, 7), DateTime(2026, 3, 8), DateTime(2026, 3, 9)]);
    });

    test('the days ahead are not frozen until they arrive', () {
      final days = RestDays.markRun(const [], today, RestKind.rest, 3, today: today);
      expect(RestDays.frozenDays(days, today), {DateTime(2026, 3, 10)});
      expect(RestDays.frozenDays(days, DateTime(2026, 3, 12)).length, 3);
    });
  });
}
