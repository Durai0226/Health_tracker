import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_consistency.dart';

void main() {
  group('SleepConsistency.fromIndex', () {
    test('below 3 nights is always "building", regardless of index', () {
      expect(SleepConsistency.fromIndex(1.0, sampleSize: 0),
          SleepConsistency.building);
      expect(SleepConsistency.fromIndex(0.95, sampleSize: 2),
          SleepConsistency.building);
      expect(SleepConsistency.fromIndex(0.10, sampleSize: 2),
          SleepConsistency.building);
    });

    test('classifies once there are enough nights', () {
      expect(SleepConsistency.fromIndex(0.90, sampleSize: 5),
          SleepConsistency.veryRegular);
      expect(SleepConsistency.fromIndex(0.80, sampleSize: 5),
          SleepConsistency.veryRegular); // inclusive boundary
      expect(SleepConsistency.fromIndex(0.70, sampleSize: 5),
          SleepConsistency.fairlyRegular);
      expect(SleepConsistency.fromIndex(0.55, sampleSize: 5),
          SleepConsistency.fairlyRegular); // inclusive boundary
      expect(SleepConsistency.fromIndex(0.40, sampleSize: 5),
          SleepConsistency.variable);
      expect(SleepConsistency.fromIndex(0.0, sampleSize: 14),
          SleepConsistency.variable);
    });

    test('never yields a "poor"-style label; downside caps at "Variable"', () {
      // The worst reading a user can ever see is the gentle "Variable".
      final worst = SleepConsistency.fromIndex(0.0, sampleSize: 14);
      expect(worst.label, 'Variable');
      expect(worst.label.toLowerCase().contains('poor'), isFalse);
      for (final c in SleepConsistency.values) {
        expect(c.label.toLowerCase().contains('poor'), isFalse);
        expect(c.why, isNotEmpty);
      }
    });

    test('hasEnoughData is false only for building', () {
      expect(SleepConsistency.building.hasEnoughData, isFalse);
      expect(SleepConsistency.variable.hasEnoughData, isTrue);
      expect(SleepConsistency.fairlyRegular.hasEnoughData, isTrue);
      expect(SleepConsistency.veryRegular.hasEnoughData, isTrue);
    });
  });
}
