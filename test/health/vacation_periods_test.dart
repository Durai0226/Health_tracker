import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/vacation_periods.dart';

void main() {
  DateTime d(int day) => DateTime(2026, 3, day);
  VacationPeriod p(int a, int b) => VacationPeriod(d(a), d(b));

  group('VacationPeriod', () {
    test('covers whole days, both ends included, ignoring the time', () {
      final v = VacationPeriod(DateTime(2026, 3, 5, 23, 59), DateTime(2026, 3, 8, 0, 1));
      expect(v.covers(DateTime(2026, 3, 5, 0, 0)), isTrue);
      expect(v.covers(DateTime(2026, 3, 8, 23, 59)), isTrue);
      expect(v.covers(DateTime(2026, 3, 4, 23, 59)), isFalse);
      expect(v.covers(DateTime(2026, 3, 9, 0, 0)), isFalse);
    });

    test('round-trips through its stored form', () {
      final v = p(5, 8);
      expect(v.encode(), '2026-03-05|2026-03-08');
      expect(VacationPeriod.decode(v.encode()), v);
    });

    test('garbage and backwards ranges decode to nothing', () {
      expect(VacationPeriod.decode('nope'), isNull);
      expect(VacationPeriod.decode('2026-03-08|2026-03-05'), isNull);
      expect(VacationPeriod.decode('a|b'), isNull);
      expect(VacationPeriods.decodeAll('not a list'), isEmpty);
      expect(VacationPeriods.decodeAll(['2026-03-05|2026-03-08', 'bad']).length, 1);
    });
  });

  group('add', () {
    test('a new period joins the list, oldest first', () {
      final r = VacationPeriods.add([p(20, 22)], from: d(5), until: d(8));
      expect(r, [p(5, 8), p(20, 22)]);
    });

    test('overlapping and touching periods merge into one', () {
      expect(VacationPeriods.add([p(5, 8)], from: d(7), until: d(12)), [p(5, 12)]);
      expect(VacationPeriods.add([p(5, 8)], from: d(9), until: d(12)), [p(5, 12)],
          reason: 'back to back is one holiday');
      expect(VacationPeriods.add([p(5, 8)], from: d(10), until: d(12)),
          [p(5, 8), p(10, 12)]);
    });

    test('an end before the start is treated as a single day', () {
      expect(VacationPeriods.add([], from: d(9), until: d(5)), [p(9, 9)]);
    });

    test('the list is capped, oldest dropped', () {
      var list = <VacationPeriod>[];
      for (var i = 0; i < VacationPeriods.maxKept + 5; i++) {
        list = VacationPeriods.add(list,
            from: DateTime(2020, 1, 1 + i * 3), until: DateTime(2020, 1, 1 + i * 3));
      }
      expect(list.length, VacationPeriods.maxKept);
      expect(list.first.start, DateTime(2020, 1, 1 + 5 * 3));
    });
  });

  group('active and frozen days', () {
    final list = [p(5, 8), p(20, 22)];

    test('active is the period covering today', () {
      expect(VacationPeriods.active(list, d(6)), p(5, 8));
      expect(VacationPeriods.active(list, d(9)), isNull);
    });

    test('frozen days run up to today and no further', () {
      expect(VacationPeriods.frozenDays(list, d(6)), {d(5), d(6)});
      expect(VacationPeriods.frozenDays(list, d(25)),
          {d(5), d(6), d(7), d(8), d(20), d(21), d(22)});
      expect(VacationPeriods.frozenDays(list, d(4)), isEmpty);
    });

    test('a past holiday keeps protecting its days after it is over', () {
      expect(VacationPeriods.frozenDays(list, d(30)).containsAll([d(5), d(8)]),
          isTrue);
    });
  });

  group('endEarly', () {
    test('cut to end yesterday, so days already spent away stay frozen', () {
      final r = VacationPeriods.endEarly([p(5, 12)], d(8));
      expect(r, [p(5, 7)]);
      expect(VacationPeriods.frozenDays(r, d(30)), {d(5), d(6), d(7)});
    });

    test('a vacation that starts today is removed — it never happened', () {
      expect(VacationPeriods.endEarly([p(8, 12)], d(8)), isEmpty);
    });

    test('other periods are left alone', () {
      expect(VacationPeriods.endEarly([p(1, 2), p(5, 12)], d(8)), [p(1, 2), p(5, 7)]);
    });

    test('with no vacation today it changes nothing', () {
      expect(VacationPeriods.endEarly([p(1, 2)], d(8)), [p(1, 2)]);
    });
  });
}
