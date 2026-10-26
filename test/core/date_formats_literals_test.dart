/// Literal words inside a `DateFormat` pattern have to be quoted.
///
/// `DateFormat('EEE, MMM d at h:mm a')` looks like it renders
/// "Mon, Mar 14 at 8:05 AM". It does not: intl reads the `a` of "at" as its
/// am/pm pattern character, so the string comes out "Mon, Mar 14 PMt 8:05 PM"
/// — only the `t` survives as a literal. That shipped on the medicine detail
/// screen's Schedule card, directly under the heading "Next Dose".
///
/// The formatter's own doc comment claimed the correct output, which is the
/// reason it went unnoticed: the pattern and the comment disagreed and only
/// the comment was ever read.
library;

import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/date_formats.dart';

void main() {
  // A morning instant, so an am/pm leak shows up as a stray "AM".
  final morning = DateTime(2026, 3, 14, 8, 5);
  // ...and an evening one, because the original defect was first seen as "PMt".
  final evening = DateTime(2026, 3, 14, 20, 5);

  test('"at" renders as the word, not as am/pm plus a stray t', () {
    expect(DateFormats.weekdayDayMonthTime.format(morning), 'Sat, Mar 14 at 8:05 AM');
    expect(DateFormats.weekdayDayMonthTime.format(evening), 'Sat, Mar 14 at 8:05 PM');
  });

  test('no meridiem leaks into the literal', () {
    for (final d in [morning, evening]) {
      final s = DateFormats.weekdayDayMonthTime.format(d);
      expect(s, isNot(contains('AMt')), reason: s);
      expect(s, isNot(contains('PMt')), reason: s);
      // Exactly one meridiem, at the end where it belongs.
      expect(RegExp(r'\b(AM|PM)\b').allMatches(s).length, 1, reason: s);
    }
  });

  /// Every other formatter in the file, checked the same way.
  ///
  /// The scan that found this one looked for letters outside quotes that are
  /// not intl pattern characters; this is the runtime half of it.
  test('no formatter emits a doubled or stray meridiem', () {
    final formatters = <String, DateFormat>{
      'dayMonth': DateFormats.dayMonth,
      'dayMonthYear': DateFormats.dayMonthYear,
      'dayMonthTime': DateFormats.dayMonthTime,
      'time': DateFormats.time,
      'weekdayDayMonthShort': DateFormats.weekdayDayMonthShort,
      'weekdayDayMonthLong': DateFormats.weekdayDayMonthLong,
      'weekdayDayMonthMedium': DateFormats.weekdayDayMonthMedium,
      'weekdayDayMonthTime': DateFormats.weekdayDayMonthTime,
      'dayMonthDotTime': DateFormats.dayMonthDotTime,
      'numericShort': DateFormats.numericShort,
    };
    formatters.forEach((name, f) {
      for (final d in [morning, evening]) {
        final s = f.format(d);
        expect(RegExp(r'(AM|PM)').allMatches(s).length, lessThan(2),
            reason: '$name rendered "$s" — a literal letter is leaking into '
                'the meridiem pattern');
      }
    });
  });
}
