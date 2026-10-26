/// The Sleep summary card must not call an old night "last night".
///
/// The card renders the most recent *logged* session. On a morning you have
/// not logged yet, that is an older night — and the eyebrow above it was the
/// constant string 'LAST NIGHT'.
///
/// Found on device on Sep 30: the card read "LAST NIGHT · 7h 39m · Mon, Sep 28"
/// while a "Log last night" button sat directly above it. That button is only
/// offered because last night has no session, so the screen was both asking
/// for last night and claiming to show it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';

void main() {
  // Wednesday, just after midnight — the moment the defect was seen.
  final now = DateTime(2026, 9, 30, 0, 26);

  String eyebrow(DateTime wake) => sleepSummaryEyebrow(wake, now: now);

  test('a night you woke from this morning is last night', () {
    expect(eyebrow(DateTime(2026, 9, 30, 7, 0)), 'LAST NIGHT');
  });

  test('after midnight, yesterday morning still counts', () {
    // Read at 00:26 having not yet slept: the night that ended yesterday
    // morning is still the last one you had.
    expect(eyebrow(DateTime(2026, 9, 29, 7, 0)), 'LAST NIGHT');
  });

  test('the night on the device is not called last night', () {
    // "Mon, Sep 28" under a Sep 30 clock.
    expect(eyebrow(DateTime(2026, 9, 28, 7, 0)), 'MOST RECENT');
  });

  test('older gaps are never called last night', () {
    for (final daysBack in const [2, 3, 7, 30]) {
      final wake = now.subtract(Duration(days: daysBack));
      expect(eyebrow(wake), 'MOST RECENT',
          reason: '$daysBack days back was labelled last night');
    }
  });

  test('the boundary is calendar days, not elapsed hours', () {
    // 00:26 Sep 30 minus a session waking 07:00 on Sep 28 is only 41 hours,
    // which a truncating `inDays` would call 1. Two dates back is two nights.
    expect(eyebrow(DateTime(2026, 9, 28, 7, 0)), 'MOST RECENT');
    // ...and a session waking late on the 29th is one date back, so it counts
    // even though barely any time has passed.
    expect(eyebrow(DateTime(2026, 9, 29, 23, 0)), 'LAST NIGHT');
  });
}
