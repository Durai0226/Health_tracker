/// SS-12 — one step sync makes 24 sequential platform round trips for today's
/// hourly chart.
///
/// `HealthDataService.readHourlySteps` loops the hours and awaits one
/// `getTotalStepsInInterval` per hour
/// (`lib/core/services/health_data_service.dart:888-903`), so the hourly bars
/// cost 24 Health Connect / HealthKit aggregate queries where the day total
/// beside them costs one. `StepService.syncFromHealth` calls it on every pass
/// for today (`lib/features/steps/services/step_service.dart:608`).
///
/// This file does not fix that, and the reason is worth recording. The obvious
/// workaround — read raw `STEPS` points once and bucket them by hour — is not
/// equivalent: `getTotalStepsInInterval` reaches Health Connect's
/// `aggregate(StepsRecord.COUNT_TOTAL)`, which de-duplicates records written by
/// several sources (phone and watch), and `readStepsForDay` uses the same
/// aggregate. Bucketing raw points would make the hourly bars disagree with the
/// day total the same sync writes. `package:health` 13.3.2 exposes no bucketed
/// aggregate — `getTotalStepsInInterval` is its only steps aggregate — so a
/// fix that keeps the semantics needs `aggregateGroupByDuration` (Android) /
/// `HKStatisticsCollectionQuery` (iOS) plumbed through the plugin, not a
/// rearrangement of this call site.
///
/// What this file does is put a NUMBER on it and stop it growing. Counted as
/// platform invocations through a mock handler on the plugin's own
/// `MethodChannel('flutter_health')` — the same channel the shipped code calls,
/// not a seam — because the failure mode to guard against is "work moved, not
/// removed": wrapping the 24 awaits in a `Future.wait` would finish sooner and
/// count exactly the same, and it is the query count, not the wall time, that
/// the health store is rate-limited on.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The plugin's channel, spelled as `package:health` declares it.
  const health = MethodChannel('flutter_health');

  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(health, (call) async {
      calls.add(call.method);
      // A non-null answer, so the loop cannot be shortened by an early return
      // on a null reading — `readHourlySteps` coalesces null to 0 and carries
      // on, but a mock that answered null would leave that untested.
      return call.method == 'getTotalStepsInInterval' ? 7 : null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(health, null);
  });

  final day = DateTime(2026, 3, 10);

  test('beacon: the day total costs exactly one aggregate query', () async {
    // First, because every assertion below is a call COUNT and a count of zero
    // is what a mock handler that intercepts nothing also reports. If this
    // fails, the channel name or the service's read path has changed and the
    // budget beneath it is measuring silence.
    final steps = await HealthDataService.instance.readStepsForDay(day);

    expect(calls, ['getTotalStepsInInterval'],
        reason: 'readStepsForDay is one aggregate call; if this list is empty '
            'the mock is not intercepting the shipped code path at all');
    expect(steps, 7, reason: 'and the answer has to come back through it');
  });

  test('readHourlySteps costs 24 platform round trips — a ceiling, not a target',
      () async {
    final hourly = await HealthDataService.instance.readHourlySteps(day);

    // The COUNT first, because it is the finding and everything after it is
    // corroboration. Exact on both sides, the way `_comfortBaseline` in the
    // touch-target audit is exact: a ceiling that only fails upwards lets a fix
    // land without anyone noticing the number it was fixed to, and this one is
    // meant to end at 1.
    expect(calls.length, lessThanOrEqualTo(24),
        reason: 'SS-12 got WORSE: ${calls.length} platform round trips for one '
            'day of hourly steps, against a recorded 24. The hourly chart is '
            'already the single most expensive thing a step sync does.');
    expect(calls.length, 24,
        reason: 'Good news, and an action: this is now ${calls.length} round '
            'trips, not 24 — SS-12 has been fixed or partly fixed. Lower the '
            'number here and rewrite the header, which still describes the '
            '24-call loop.');
    expect(calls.toSet(), {'getTotalStepsInInterval'},
        reason: 'all 24 are the aggregate query, so this is 24x the cost of '
            'the day total rather than a different kind of read');

    // And the buckets are one-per-query, which is what makes the count 24
    // rather than a retry storm on a smaller number of hours.
    expect(hourly, hasLength(24));
    expect(hourly.every((h) => h == 7), isTrue,
        reason: 'every bucket came from its own query — that is the defect');
  });
}
