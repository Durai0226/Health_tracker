import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/percent_format.dart';

void main() {
  group('Pct.of pins the two endpoints a user reads as absolute', () {
    test('100% means complete, and nothing else does', () {
      expect(Pct.of(1.0), 100);
      expect(Pct.of(1.5), 100, reason: 'over-complete is still complete');
      // (0.996 * 100).round() == 100 — the old behaviour, captioning a visibly
      // open ring "100%".
      expect(Pct.of(0.996), 99);
      expect(Pct.of(0.9999), 99);
    });

    test('0% means nothing done, and nothing else does', () {
      expect(Pct.of(0), 0);
      expect(Pct.of(-0.2), 0);
      // (0.004 * 100).round() == 0 — "0%" on a day the user did take a dose.
      expect(Pct.of(0.004), 1);
      expect(Pct.of(0.0001), 1);
    });

    test('everything in between rounds normally', () {
      expect(Pct.of(0.5), 50);
      expect(Pct.of(0.333), 33);
      expect(Pct.of(0.335), 34);
      expect(Pct.of(0.985), 99);
    });

    test('a NaN reads as zero rather than crashing a label', () {
      expect(Pct.of(double.nan), 0);
    });

    test('text() formats what of() computed', () {
      expect(Pct.text(0.996), '99%');
      expect(Pct.text(1.0), '100%');
    });
  });

  group('Pct.ofCount', () {
    test('reaches 100 only when the count actually does', () {
      expect(Pct.ofCount(299, 300), 99);
      expect(Pct.ofCount(300, 300), 100);
      expect(Pct.ofCount(1, 2), 50);
      expect(Pct.ofCount(0, 3), 0);
    });

    test('nothing to do is complete, not undefined', () {
      expect(Pct.ofCount(0, 0), 100);
    });
  });
}
