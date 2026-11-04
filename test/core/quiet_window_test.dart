/// The clock arithmetic behind quiet hours: is a time inside the window, and when
/// does the window end after it?
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/quiet_window.dart';

void main() {
  const night = QuietWindow(startMinute: 22 * 60, endMinute: 7 * 60);
  const afternoon = QuietWindow(startMinute: 13 * 60, endMinute: 15 * 60);

  DateTime at(int h, int m, {int day = 13, int month = 3, int year = 2026}) =>
      DateTime(year, month, day, h, m);

  group('a window through midnight (22:00 to 07:00)', () {
    test('it runs through midnight', () {
      expect(night.crossesMidnight, isTrue);
      expect(afternoon.crossesMidnight, isFalse);
    });

    test('inside: late evening, midnight, small hours', () {
      for (final t in [at(22, 0), at(23, 59), at(0, 0), at(3, 30), at(6, 59)]) {
        expect(night.covers(t), isTrue, reason: '$t');
      }
    });

    test('outside: morning, day, early evening', () {
      for (final t in [at(7, 0), at(7, 1), at(12, 0), at(21, 59)]) {
        expect(night.covers(t), isFalse, reason: '$t');
      }
    });

    test('quiet begins AT its start and ends BEFORE its end', () {
      expect(night.covers(at(22, 0)), isTrue, reason: 'start is inclusive');
      expect(night.covers(at(21, 59)), isFalse);
      expect(night.covers(at(6, 59)), isTrue);
      expect(night.covers(at(7, 0)), isFalse,
          reason: 'a reminder due the minute quiet ends is not held');
    });

    test('the date makes no difference', () {
      expect(night.covers(at(23, 0, day: 1, month: 1, year: 2030)), isTrue);
      expect(night.covers(at(12, 0, day: 29, month: 2, year: 2028)), isFalse);
    });
  });

  group('a window within one day (13:00 to 15:00)', () {
    test('inside and outside, with the same inclusive start and exclusive end', () {
      expect(afternoon.covers(at(13, 0)), isTrue);
      expect(afternoon.covers(at(14, 59)), isTrue);
      expect(afternoon.covers(at(15, 0)), isFalse);
      expect(afternoon.covers(at(12, 59)), isFalse);
      expect(afternoon.covers(at(23, 0)), isFalse);
      expect(afternoon.covers(at(0, 0)), isFalse);
    });
  });

  group('a window of no length', () {
    const none = QuietWindow(startMinute: 600, endMinute: 600);

    test('covers nothing — it is not a window that lasts all day', () {
      expect(none.isEmpty, isTrue);
      for (var h = 0; h < 24; h++) {
        expect(none.covers(at(h, 0)), isFalse, reason: 'hour $h');
      }
      expect(none.endAfter(at(10, 0)), isNull);
    });

    test('a real window is not empty', () {
      expect(night.isEmpty, isFalse);
      expect(afternoon.isEmpty, isFalse);
    });
  });

  group('when the window ends', () {
    test('before midnight, it waits until tomorrow morning', () {
      expect(night.endAfter(at(23, 0)), at(7, 0, day: 14));
      expect(night.endAfter(at(22, 0)), at(7, 0, day: 14));
      expect(night.endAfter(at(23, 59)), at(7, 0, day: 14));
    });

    test('after midnight, it waits until this morning', () {
      expect(night.endAfter(at(0, 0)), at(7, 0));
      expect(night.endAfter(at(3, 0)), at(7, 0));
      expect(night.endAfter(at(6, 59)), at(7, 0));
    });

    test('a window within the day ends the same day', () {
      expect(afternoon.endAfter(at(13, 30)), at(15, 0));
    });

    test('an end that is not on the hour is kept to the minute', () {
      const w = QuietWindow(startMinute: 22 * 60 + 30, endMinute: 6 * 60 + 45);
      expect(w.endAfter(at(23, 0)), at(6, 45, day: 14));
      expect(w.endAfter(at(2, 0)), at(6, 45));
    });

    test('outside the window there is nothing to wait for', () {
      expect(night.endAfter(at(12, 0)), isNull);
      expect(night.endAfter(at(7, 0)), isNull);
      expect(afternoon.endAfter(at(15, 0)), isNull);
    });

    test('across the end of a month and of a year', () {
      expect(night.endAfter(at(23, 0, day: 31, month: 1)),
          DateTime(2026, 2, 1, 7));
      expect(night.endAfter(at(23, 0, day: 28, month: 2, year: 2028)),
          DateTime(2028, 2, 29, 7));
      expect(night.endAfter(at(23, 0, day: 31, month: 12, year: 2026)),
          DateTime(2027, 1, 1, 7));
    });
  });

  test('two windows with the same minutes are equal', () {
    expect(night,
        const QuietWindow(startMinute: 22 * 60, endMinute: 7 * 60));
    expect(night == afternoon, isFalse);
    expect(night.hashCode,
        const QuietWindow(startMinute: 22 * 60, endMinute: 7 * 60).hashCode);
  });
}
