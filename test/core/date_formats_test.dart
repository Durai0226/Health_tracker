import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tablet_remainder/core/utils/date_formats.dart';

/// The shared formatters replaced ~30 inline `DateFormat(...)` constructions
/// that were being built per row, per rebuild, inside list builders.
///
/// The risk in that refactor is not performance — it is silently changing what
/// the user sees. These tests pin each shared formatter's output against a
/// freshly-constructed formatter with the original pattern, so a wrong mapping
/// (e.g. 'MMM d' where 'MMM d, h:mm a' was meant) fails loudly.
void main() {
  final d = DateTime(2026, 3, 14, 8, 5);
  final dPm = DateTime(2026, 11, 2, 20, 45);

  void same(String pattern, String actual, {DateTime? on}) {
    expect(actual, DateFormat(pattern).format(on ?? d),
        reason: "output drifted from the original '$pattern' pattern");
  }

  test('each shared formatter matches its original pattern', () {
    same('MMM d', DateFormats.dayMonth.format(d));
    same('MMM d, yyyy', DateFormats.dayMonthYear.format(d));
    same('MMM d, h:mm a', DateFormats.dayMonthTime.format(d));
    same('h:mm a', DateFormats.time.format(d));
    same('h:mm', DateFormats.timeNoMeridiem.format(d));
    same('a', DateFormats.meridiem.format(d));
    same('E', DateFormats.weekdayNarrow.format(d));
    same('EEE', DateFormats.weekdayShort.format(d));
    same('EEE, MMM d', DateFormats.weekdayDayMonthShort.format(d));
    same('EEEE, MMMM d', DateFormats.weekdayDayMonthLong.format(d));
    same('EEEE, MMM d', DateFormats.weekdayDayMonthMedium.format(d));
    same('EEE, MMM d at h:mm a', DateFormats.weekdayDayMonthTime.format(d));
    same('MMM d · h:mm a', DateFormats.dayMonthDotTime.format(d));
    same('d', DateFormats.dayOfMonth.format(d));
    same('M/d', DateFormats.numericShort.format(d));
  });

  test('formatters are reusable across calls (no hidden per-call state)', () {
    // A shared formatter would be unsafe if `format` mutated it. Interleave
    // two different instants and two different formatters.
    final a1 = DateFormats.time.format(d);
    final b1 = DateFormats.dayMonthTime.format(dPm);
    final a2 = DateFormats.time.format(d);
    final b2 = DateFormats.dayMonthTime.format(dPm);
    expect(a2, a1);
    expect(b2, b1);
    expect(DateFormats.time.format(dPm), isNot(a1));
  });

  test('dayLabel adds the year only when it differs from the reference', () {
    final ref = DateTime(2026, 6, 1);
    expect(DateFormats.dayLabel(DateTime(2026, 3, 14), reference: ref),
        DateFormat('MMM d').format(DateTime(2026, 3, 14)));
    expect(DateFormats.dayLabel(DateTime(2025, 3, 14), reference: ref),
        DateFormat('MMM d, yyyy').format(DateTime(2025, 3, 14)));
  });

  test('AM and PM both render', () {
    expect(DateFormats.time.format(d).toUpperCase(), contains('AM'));
    expect(DateFormats.time.format(dPm).toUpperCase(), contains('PM'));
  });
}
