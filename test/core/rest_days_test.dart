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
}
