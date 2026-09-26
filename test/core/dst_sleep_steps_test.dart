/// Midnight-rollover and DST-night coverage for the sleep and step day keys.
///
/// Both features hang off a single "which calendar day does this belong to"
/// decision, and both expose it `@visibleForTesting` *for a DST run* —
/// `SleepService.nightKeyFor` and `StepService.recentSyncDays` each say so in
/// their doc comment. Until this file existed neither had a caller in `test/`,
/// so the arithmetic those comments describe was documented and unguarded.
///
/// Two layers, the same shape as `dst_date_arithmetic_test.dart`:
///
///  1. The `group`s below assert the calendar semantics that hold in EVERY
///     zone — the 18:00 night boundary, a rollover at midnight, a sync window
///     of distinct consecutive days. They run wherever the suite runs.
///  2. `dst_sleep_steps_probe.dart` re-runs the day-key seams in a child
///     process pinned to `TZ=America/New_York`. A Dart process reads its
///     timezone once at startup, so a real 23-/25-hour civil day can only be
///     exercised out of process — and that is the only run in which the
///     unfixed code fails (nine failures across the three seams at the time of
///     writing).
///
/// The child is spawned with `flutter test`, not `dart run`, because
/// SleepService and StepService reach package:flutter, drift and the health
/// plugin: the standalone Dart VM cannot compile them at all.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

import 'dst_sleep_steps_probe.dart' show noDstSentinel;

void main() {
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  group('SleepService.nightKeyFor — a night is named after the morning', () {
    test('an evening segment belongs to the next calendar day', () {
      expect(SleepService.nightKeyFor(DateTime(2026, 5, 12, 23, 30)),
          '2026-05-13');
      expect(SleepService.nightKeyFor(DateTime(2026, 5, 12, 18)), '2026-05-13');
    });

    test('17:59 is still the day it started on, 18:00 is not', () {
      expect(
          SleepService.nightKeyFor(DateTime(2026, 5, 12, 17, 59)), '2026-05-12');
      expect(SleepService.nightKeyFor(DateTime(2026, 5, 12, 18)), '2026-05-13');
    });

    test('a segment after midnight stays on the morning it woke into', () {
      // 02:10 belongs to the night that is ENDING, not the one about to start.
      expect(SleepService.nightKeyFor(DateTime(2026, 5, 13, 2, 10)),
          '2026-05-13');
      expect(SleepService.nightKeyFor(DateTime(2026, 5, 13, 6)), '2026-05-13');
    });

    test('an evening rolls the month and the year over', () {
      expect(SleepService.nightKeyFor(DateTime(2026, 4, 30, 23)), '2026-05-01');
      expect(SleepService.nightKeyFor(DateTime(2026, 12, 31, 23)), '2027-01-01');
      expect(SleepService.nightKeyFor(DateTime(2028, 2, 28, 23)), '2028-02-29');
    });

    test('a run of evenings never files two nights under one key', () {
      final keys = <String>[
        for (var i = 0; i < 10; i++)
          SleepService.nightKeyFor(DateTime(2026, 4, 26 + i, 23)),
      ];
      expect(keys.toSet(), hasLength(10));
      expect(keys.first, '2026-04-27');
      expect(keys.last, '2026-05-06');
    });
  });

  group('StepService.recentSyncDays — the window pulled from the health store',
      () {
    test('it is today plus the six days before it, at midnight, newest first',
        () {
      final days = StepService.recentSyncDays(DateTime(2026, 5, 13, 14, 37));
      expect(days, [for (var i = 0; i < 7; i++) DateTime(2026, 5, 13 - i)]);
      for (final d in days) {
        expect(d.hour, 0);
        expect(d.minute, 0);
        expect(d.second, 0);
      }
    });

    test('every day in the window is distinct — a repeat skips a real day', () {
      final days = StepService.recentSyncDays(DateTime(2026, 3, 2, 9), days: 45);
      expect(days.map(key).toSet(), hasLength(45));
      expect(days.first, DateTime(2026, 3, 2));
      expect(days.last, DateTime(2026, 1, 17), reason: 'crosses two months');
    });
  });

  // The one test that can actually observe a DST transition. Everything above
  // passes in a no-DST zone even on the unfixed code; this does not.
  test(
    'the sleep and step day keys still hold under TZ=America/New_York '
    '(out of process)',
    () async {
      if (Platform.isWindows) {
        markTestSkipped('TZ env var is not honoured on Windows');
        return;
      }
      // NOT a skip. This suite is a `flutter_test` suite, so the only thing
      // that can run it is `flutter test` — which injects FLUTTER_ROOT into
      // the child itself (it is not inherited from the developer's shell, and
      // is set even when the shell has no Flutter on PATH). A null here
      // therefore means the runner is broken, not that the machine lacks a
      // capability, and skipping would convert "could not run" into "passed":
      // on a no-DST machine this spawn is the ONLY thing in the file that can
      // observe a 23-/25-hour day, so every DST assertion would vanish in
      // silence while the suite still reported green.
      final flutter = _flutterExecutable();
      expect(flutter, isNotNull,
          reason: 'FLUTTER_ROOT is unset, so the DST probe could not be '
              'spawned and NONE of the DST coverage in this file ran. '
              'Run this suite with `flutter test`.');
      final probe = File('test/core/dst_sleep_steps_probe.dart');
      expect(probe.existsSync(), isTrue,
          reason: 'probe missing at ${probe.absolute.path}');

      final r = await Process.run(
        flutter!,
        ['test', '--no-pub', '--reporter', 'expanded', probe.path],
        environment: const {'TZ': 'America/New_York'},
        workingDirectory: Directory.current.path,
      );
      final out = '${r.stdout}\n${r.stderr}';
      // The child printing this means it did NOT get a DST zone, so its
      // assertions were trivially true. Skip rather than record a false pass.
      if (out.contains(noDstSentinel)) {
        markTestSkipped('DST probe could not obtain a DST zone');
        return;
      }
      expect(r.exitCode, 0, reason: out);
      // A probe that ran zero tests would also exit 0. Pin that it really ran.
      expect(out, contains('All tests passed!'), reason: out);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// The `flutter` launcher, for re-running the probe with a different `TZ`.
/// `flutter test` runs suites inside `flutter_tester`, so
/// [Platform.resolvedExecutable] is the tester, not a usable CLI.
///
/// Returns null only when FLUTTER_ROOT is missing, which the caller treats as
/// a failure rather than a skip — see the comment at its use site.
String? _flutterExecutable() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final candidate = File('$root/bin/flutter');
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}
