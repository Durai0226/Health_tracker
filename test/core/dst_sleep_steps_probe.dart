// Not a `_test.dart` file on purpose: `flutter test` must NOT pick this up
// directly. It is re-executed by dst_sleep_steps_test.dart in a child process
// with `TZ=America/New_York`, because a Dart process reads its timezone once at
// startup and cannot switch it at runtime.
//
// Unlike dst_date_arithmetic_probe.dart this one is a `flutter_test` suite run
// with `flutter test`, not a bare `dart run` entrypoint: SleepService and
// StepService reach package:flutter (ValueNotifier, debugPrint), drift and the
// health plugin, so they cannot be compiled by the standalone Dart VM at all —
// `dart run` dies in the FFI transformer before it reaches main().
//
// Regression scope: the two day-key seams the sleep and step features hang off.
// Both are `@visibleForTesting` precisely so a DST run could reach them, and
// until this file existed neither had a single caller in test/.
//
//  * `SleepService.nightKeyFor` — a segment starting at/after 18:00 belongs to
//    the NEXT calendar day. With `startOfDay(d).add(const Duration(days: 1))`
//    that +1 is 24 elapsed hours, so on a 25-hour civil day it lands back on
//    its own date: the night of Nov 1→2 is filed under Nov 1, COLLIDING with
//    the night of Oct 31→1, and the two get aggregated into one session.
//  * `StepService.recentSyncDays` — the days pulled from the health store.
//    `subtract(Duration(days: i))` from a midnight anchor slides to 23:00 of
//    the day before across spring forward, so the DST Sunday is never requested
//    and shows 0 steps forever.
//  * `SleepService.logManualSession` — when wake <= bedtime the bedtime is
//    moved to the previous evening. That must keep the wall-clock hour: "I went
//    to bed at 23:00" stays 23:00, and the night across a 25-hour day is a real
//    9 hours long.
//
// 2026 US transitions: spring forward Mar 8 (23h day), fall back Nov 1 (25h).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

/// Printed for the parent to read when the child did NOT get a DST zone, so a
/// no-DST machine registers as a skip rather than as a silent pass.
const noDstSentinel = 'DST_SLEEP_STEPS_PROBE_NO_DST';

String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A zone with no DST makes every assertion below trivially true, which would
  // be a false pass — the exact failure mode this audit is about.
  final hasDst = DateTime(2026, 1, 15).timeZoneOffset !=
      DateTime(2026, 7, 15).timeZoneOffset;
  if (!hasDst) {
    // ignore: avoid_print
    print(noDstSentinel);
    test('probe needs a DST zone', () {
      markTestSkipped('no DST in this zone; nothing here can observe the bug');
    });
    return;
  }

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  group('SleepService.nightKeyFor across a 25-hour civil day', () {
    test('an evening on the fall-back day belongs to the NEXT morning', () {
      // startOfDay(Nov 1) + 24 elapsed hours = Nov 1 23:00 EST — still Nov 1.
      expect(SleepService.nightKeyFor(DateTime(2026, 11, 1, 23)), '2026-11-02');
      expect(SleepService.nightKeyFor(DateTime(2026, 11, 1, 21, 30)),
          '2026-11-02');
    });

    test('two consecutive evenings never share a night key', () {
      // This is the corruption itself: under Duration stepping both Oct 31
      // 23:00 and Nov 1 23:00 resolve to '2026-11-01', so two nights are
      // aggregated into one session whose wake time is 24 hours after its
      // bedtime.
      final oct31 = SleepService.nightKeyFor(DateTime(2026, 10, 31, 23));
      final nov1 = SleepService.nightKeyFor(DateTime(2026, 11, 1, 23));
      expect(oct31, '2026-11-01');
      expect(nov1, '2026-11-02');
      expect(oct31, isNot(nov1), reason: 'two nights filed as one');
    });

    test('a fortnight of evenings yields 14 distinct consecutive keys', () {
      final keys = <String>[
        for (var i = 0; i < 14; i++)
          SleepService.nightKeyFor(DateTime(2026, 10, 26 + i, 23)),
      ];
      expect(keys.toSet(), hasLength(14), reason: 'a key collision loses a night');
      expect(keys, [
        for (var i = 0; i < 14; i++) _key(DateTime(2026, 10, 27 + i)),
      ]);
    });

    test('the 18:00 boundary holds on the transition days themselves', () {
      for (final day in [DateTime(2026, 3, 8), DateTime(2026, 11, 1)]) {
        final d = DateTime(day.year, day.month, day.day);
        expect(SleepService.nightKeyFor(DateTime(d.year, d.month, d.day, 17, 59)),
            _key(d),
            reason: '17:59 is still the same calendar day on $d');
        expect(SleepService.nightKeyFor(DateTime(d.year, d.month, d.day, 18)),
            _key(DateTime(d.year, d.month, d.day + 1)),
            reason: '18:00 rolls to the next morning on $d');
      }
    });

    test('a morning wake-up is never pushed forward', () {
      expect(SleepService.nightKeyFor(DateTime(2026, 11, 1, 6)), '2026-11-01');
      expect(SleepService.nightKeyFor(DateTime(2026, 3, 8, 6)), '2026-03-08');
    });
  });

  group('StepService.recentSyncDays across both transitions', () {
    void expectWindow(DateTime now, List<DateTime> expected) {
      final days = StepService.recentSyncDays(now, days: expected.length);
      expect(days, expected, reason: 'sync window from $now');
      for (final d in days) {
        expect(d.hour, 0, reason: '$d is not midnight-aligned');
        expect(d.minute, 0);
      }
      expect(days.map(_key).toSet(), hasLength(expected.length),
          reason: 'a repeated day means another day was never requested');
    }

    test('the morning after spring forward requests the DST Sunday', () {
      // `Mar 9 00:00 EDT - 24h` is Mar 7 23:00 EST: Mar 8 was skipped outright
      // and could never be backfilled.
      expectWindow(DateTime(2026, 3, 9, 10), [
        for (var i = 0; i < 7; i++) DateTime(2026, 3, 9 - i),
      ]);
    });

    test('the morning after fall back keeps every anchor at midnight', () {
      expectWindow(DateTime(2026, 11, 2, 10), [
        for (var i = 0; i < 7; i++) DateTime(2026, 11, 2 - i),
      ]);
    });

    test('a 30-day window spanning spring forward has 30 distinct days', () {
      final days = StepService.recentSyncDays(DateTime(2026, 3, 20, 9), days: 30);
      expect(days.map(_key).toSet(), hasLength(30));
      expect(days.first, DateTime(2026, 3, 20));
      expect(days.last, DateTime(2026, 2, 19));
    });
  });

  group('SleepService.logManualSession — the previous-evening shift', () {
    test('23:00 stays 23:00 when the night spans the 25-hour day', () async {
      // The sheet hands over same-day times; the service moves the bedtime back
      // one calendar day. Oct 31 23:00 EDT -> Nov 1 07:00 EST really is NINE
      // hours, because the clocks went back at 02:00.
      final s = await SleepService.logManualSession(
        bedtime: DateTime(2026, 11, 1, 23),
        wakeTime: DateTime(2026, 11, 1, 7),
      );
      expect(s.bedtime, DateTime(2026, 10, 31, 23),
          reason: 'Duration stepping lands on Nov 1 00:00 instead');
      expect(s.inBedMinutes, 9 * 60);
      expect(s.dateKey, '2026-11-01');
    });

    test('23:00 stays 23:00 when the night spans the 23-hour day', () async {
      final s = await SleepService.logManualSession(
        bedtime: DateTime(2026, 3, 8, 23),
        wakeTime: DateTime(2026, 3, 8, 7),
      );
      expect(s.bedtime, DateTime(2026, 3, 7, 23),
          reason: 'Duration stepping lands on Mar 7 22:00 instead');
      expect(s.inBedMinutes, 7 * 60);
      expect(s.dateKey, '2026-03-08');
    });
  });
}
