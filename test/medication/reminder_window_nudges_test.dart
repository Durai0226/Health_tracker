import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';
import 'package:tablet_remainder/features/medication/services/reminder_window_nudges.dart';

/// Phase 4's pure logic: the (up to 3) minute-of-day placements for a
/// reminder window's nudges, the collision-free id scheme for them, and the
/// shared resolved-flag key format the background isolate and the main
/// isolate must agree on byte-for-byte.
void main() {
  group('windowNudgeMinutes', () {
    test('start, geometric middle, and end for a plain window', () {
      final minutes = windowNudgeMinutes(
        startMinuteOfDay: 8 * 60, // 8:00
        windowMinutes: 60,
      );
      expect(minutes, [480, 510, 540]); // 8:00, 8:30, 9:00
    });

    test('an adaptive suggestion strictly inside the window replaces the '
        'geometric middle', () {
      final minutes = windowNudgeMinutes(
        startMinuteOfDay: 8 * 60,
        windowMinutes: 60,
        adaptiveSuggestedMinutes: 8 * 60 + 45, // 8:45 — the user's real habit
      );
      expect(minutes, [480, 525, 540]); // 8:00, 8:45 (not 8:30), 9:00
    });

    test('an adaptive suggestion AT or OUTSIDE the window is ignored, '
        'falling back to the geometric middle', () {
      final atStart = windowNudgeMinutes(
        startMinuteOfDay: 8 * 60,
        windowMinutes: 60,
        adaptiveSuggestedMinutes: 8 * 60, // == start, not strictly inside
      );
      expect(atStart, [480, 510, 540]);

      final beforeWindow = windowNudgeMinutes(
        startMinuteOfDay: 8 * 60,
        windowMinutes: 60,
        adaptiveSuggestedMinutes: 7 * 60, // 7:00, before the window opens
      );
      expect(beforeWindow, [480, 510, 540]);

      final afterWindow = windowNudgeMinutes(
        startMinuteOfDay: 8 * 60,
        windowMinutes: 60,
        adaptiveSuggestedMinutes: 10 * 60, // 10:00, past the window
      );
      expect(afterWindow, [480, 510, 540]);
    });

    test('a very short window dedupes down to 2 or even 1 nudge instead of '
        '3 firing at the same minute', () {
      // 1-minute window: the geometric middle (480 + 1~/2 = 480) rounds down
      // to the same minute as start, so it's dropped — only start and end
      // (481) survive.
      final oneMin = windowNudgeMinutes(startMinuteOfDay: 480, windowMinutes: 1);
      expect(oneMin, [480, 481]);
      expect(oneMin.toSet().length, oneMin.length); // strictly increasing, no dup

      // Zero-length window: only the start survives.
      final zero = windowNudgeMinutes(startMinuteOfDay: 480, windowMinutes: 0);
      expect(zero, [480]);
    });

    test('always starts with the window\'s own start minute', () {
      final minutes = windowNudgeMinutes(startMinuteOfDay: 1230, windowMinutes: 45);
      expect(minutes.first, 1230);
    });
  });

  group('windowNudgeId', () {
    test('is collision-free across medicines, times, and nudge indices', () {
      final ids = <int>{};
      for (var med = 0; med < 5; med++) {
        for (var t = 0; t < 3; t++) {
          for (var n = 0; n < maxNudgesPerTime; n++) {
            final id = windowNudgeId(med, t, n);
            expect(ids.add(id), isTrue, reason: 'duplicate id for ($med,$t,$n)');
          }
        }
      }
    });

    test('lands in its own disjoint range, clear of the medicine-slot range', () {
      final id = windowNudgeId(0, 0, 0);
      expect(id, windowNudgeIdOffset);
      expect(id, greaterThanOrEqualTo(slotIdOffset + 1440)); // clear of 100000-101439
    });

    test('consecutive nudge indices for the same dose are consecutive ids '
        '(alarmCallback\'s chaining relies on id+1 == next nudge)', () {
      final base = windowNudgeId(2, 1, 0);
      expect(windowNudgeId(2, 1, 1), base + 1);
      expect(windowNudgeId(2, 1, 2), base + 2);
    });
  });

  group('nudgeResolvedKey', () {
    test('is a deterministic, stable string for the same inputs', () {
      final t = DateTime(2026, 3, 1, 8, 0);
      expect(nudgeResolvedKey('m1', t), nudgeResolvedKey('m1', t));
    });

    test('differs for a different medicine or a different scheduled time', () {
      final t = DateTime(2026, 3, 1, 8, 0);
      final other = DateTime(2026, 3, 1, 8, 1);
      expect(nudgeResolvedKey('m1', t), isNot(nudgeResolvedKey('m2', t)));
      expect(nudgeResolvedKey('m1', t), isNot(nudgeResolvedKey('m1', other)));
    });

    test('embeds the scheduled time as a parseable millisecondsSinceEpoch '
        '(reconcileMissedDoses\' pruning parses this back out)', () {
      final t = DateTime(2026, 3, 1, 8, 0);
      final key = nudgeResolvedKey('m1', t);
      final millisStr = key.split('_').last;
      expect(int.tryParse(millisStr), t.millisecondsSinceEpoch);
    });
  });

  group('ScheduledTime.windowMinutes', () {
    test('defaults to off (null, hasWindow false) — exact time is untouched', () {
      final t = ScheduledTime(hour: 8, minute: 0);
      expect(t.windowMinutes, isNull);
      expect(t.hasWindow, isFalse);
    });

    test('round-trips through toJson/fromJson', () {
      final t = ScheduledTime(hour: 8, minute: 0, windowMinutes: 60);
      final decoded = ScheduledTime.fromJson(t.toJson());
      expect(decoded.windowMinutes, 60);
      expect(decoded.hasWindow, isTrue);
    });

    test('an OLD persisted blob with no windowMinutes key parses as off, '
        'not a crash (background-isolate fromJson must fail open)', () {
      final decoded = ScheduledTime.fromJson({'hour': 8, 'minute': 0});
      expect(decoded.windowMinutes, isNull);
      expect(decoded.hasWindow, isFalse);
    });

    test('copyWith(clearWindow: true) actually clears it — plain '
        'windowMinutes-null copyWith would no-op via null-coalescing', () {
      final withWindow = ScheduledTime(hour: 8, minute: 0, windowMinutes: 60);
      final stillHasIt = withWindow.copyWith(); // no args — must not clear
      expect(stillHasIt.windowMinutes, 60);
      final cleared = withWindow.copyWith(clearWindow: true);
      expect(cleared.windowMinutes, isNull);
      expect(cleared.hasWindow, isFalse);
    });
  });
}
