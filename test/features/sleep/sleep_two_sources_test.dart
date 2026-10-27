/// Two apps writing the same night are one night, not two.
///
/// A watch's own app and a phone tracker, both connected to Health Connect, each
/// write a full night. The import summed every segment, so the night read as
/// twice as long as it was: fourteen hours "asleep", an efficiency pinned at
/// 100%, a sleep score and a debt figure built on nonsense.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_session.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  final bed = DateTime(2026, 6, 19, 23);

  HealthDataPoint seg(
    HealthDataType type,
    DateTime from,
    int minutes, {
    String source = 'com.watch',
  }) =>
      HealthDataPoint(
        uuid: '$source-$type-${from.millisecondsSinceEpoch}',
        value: NumericHealthValue(numericValue: minutes),
        type: type,
        unit: HealthDataUnit.MINUTE,
        dateFrom: from,
        dateTo: from.add(Duration(minutes: minutes)),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: source,
        sourceName: source,
        recordingMethod: RecordingMethod.automatic,
      );

  /// A night of [light]/[deep]/[rem] minutes written by [source], back to back
  /// from [bed].
  List<HealthDataPoint> night(String source,
      {int light = 240, int deep = 90, int rem = 90, int awake = 20}) {
    var at = bed;
    final out = <HealthDataPoint>[];
    for (final (type, mins) in [
      (HealthDataType.SLEEP_LIGHT, light),
      (HealthDataType.SLEEP_DEEP, deep),
      (HealthDataType.SLEEP_REM, rem),
      (HealthDataType.SLEEP_AWAKE, awake),
    ]) {
      if (mins <= 0) continue;
      out.add(seg(type, at, mins, source: source));
      at = at.add(Duration(minutes: mins));
    }
    return out;
  }

  SleepSession? aggregate(List<HealthDataPoint> points) =>
      SleepService.aggregateForTesting('2026-06-20', points, SleepSource.healthConnect);

  test('one source: exactly as before', () {
    final s = aggregate(night('com.watch'))!;
    expect(s.asleepMinutes, 420);
    expect(s.lightMinutes, 240);
    expect(s.deepMinutes, 90);
    expect(s.remMinutes, 90);
    expect(s.awakeMinutes, 20);
  });

  test('two sources writing the same night count it once', () {
    final both = [...night('com.watch'), ...night('com.phone')];
    final s = aggregate(both)!;
    expect(s.asleepMinutes, 420,
        reason: 'not 840: the same night, written twice, is one night');
    expect(s.awakeMinutes, 20);
    expect(s.inBedMinutes, lessThan(480),
        reason: 'and the time in bed is the night, not the two stacked');
  });

  test('the source that saw more of the night is the one used', () {
    // The watch saw the whole night; the phone only its first two hours.
    final both = [
      ...night('com.watch'),
      ...night('com.phone', light: 100, deep: 20, rem: 0, awake: 0),
    ];
    final s = aggregate(both)!;
    expect(s.asleepMinutes, 420);
    expect(s.deepMinutes, 90, reason: 'the watch\'s stages, not the phone\'s');
  });

  test('whichever source it is, not the one that happened to come first', () {
    final both = [
      ...night('com.phone', light: 100, deep: 20, rem: 0, awake: 0),
      ...night('com.watch'),
    ];
    expect(aggregate(both)!.asleepMinutes, 420);
  });

  test('equal coverage prefers the one with stages over a bare total', () {
    final watch = night('com.watch'); // 420 asleep, in stages
    final phone = [seg(HealthDataType.SLEEP_ASLEEP, bed, 420, source: 'com.phone')];
    final s = aggregate([...phone, ...watch])!;
    expect(s.lightMinutes, isNotNull,
        reason: 'the staged night is the more informative of two equal ones');
    expect(s.asleepMinutes, 420);
  });

  test('segments that name no source are one source, as they always were', () {
    final points = [
      for (final p in night('x'))
        HealthDataPoint(
          uuid: p.uuid,
          value: p.value,
          type: p.type,
          unit: p.unit,
          dateFrom: p.dateFrom,
          dateTo: p.dateTo,
          sourcePlatform: p.sourcePlatform,
          sourceDeviceId: p.sourceDeviceId,
          sourceId: '',
          sourceName: '',
          recordingMethod: p.recordingMethod,
        )
    ];
    expect(aggregate(points)!.asleepMinutes, 420);
  });

  test('a session record and its stages from ONE source are still not double counted',
      () {
    final watch = [
      seg(HealthDataType.SLEEP_SESSION, bed, 440),
      ...night('com.watch'),
    ];
    expect(aggregate(watch)!.asleepMinutes, 420);
  });

  test('a nap from the chosen source is still left out of the night', () {
    final nap = seg(HealthDataType.SLEEP_ASLEEP, DateTime(2026, 6, 20, 14), 45);
    final s = aggregate([...night('com.watch'), nap])!;
    expect(s.asleepMinutes, 420);
    expect(s.note, contains('45 min'));
  });
}
