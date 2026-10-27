/// "Finished" or "Half" of your bottle; "2 bottles left".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/bottle_mode.dart';

void main() {
  group('the sizes', () {
    test('from 200 ml to 2 litres, in steps of 50', () {
      expect(BottleMode.isValid(200), isTrue);
      expect(BottleMode.isValid(750), isTrue);
      expect(BottleMode.isValid(2000), isTrue);
      expect(BottleMode.isValid(150), isFalse);
      expect(BottleMode.isValid(2050), isFalse);
      expect(BottleMode.isValid(725), isFalse);
      expect(BottleMode.isValid(0), isFalse);
      expect(BottleMode.isValid(-500), isFalse);
    });

    test('the starting size is itself a valid one', () {
      expect(BottleMode.isValid(BottleMode.defaultBottleMl), isTrue);
    });
  });

  group('half a bottle', () {
    test('is half, to the nearest 10 ml', () {
      expect(BottleMode.halfMl(500), 250);
      expect(BottleMode.halfMl(750), 380);
      expect(BottleMode.halfMl(600), 300);
      expect(BottleMode.halfMl(200), 100);
      expect(BottleMode.halfMl(2000), 1000);
    });

    test('two halves are never more than a bottle', () {
      for (var b = 200; b <= 2000; b += 50) {
        expect(BottleMode.halfMl(b) * 2, lessThanOrEqualTo(b + 10), reason: '$b');
      }
    });
  });

  group('how many bottles are left', () {
    String? left(int remaining, [int bottle = 750]) =>
        BottleMode.toGo(remainingMl: remaining, bottleMl: bottle);

    test('nothing left, nothing said', () {
      expect(left(0), isNull);
      expect(left(-300), isNull);
    });

    test('a few sips: a quarter of a bottle or less', () {
      expect(left(100), 'Just a few sips to go');
      expect(left(187), 'Just a few sips to go'); // 0.249
      expect(left(188), 'Half a bottle to go');
    });

    test('half a bottle', () {
      expect(left(300), 'Half a bottle to go');
      expect(left(562), 'Half a bottle to go'); // 0.749
      expect(left(563), 'One bottle to go');
    });

    test('one bottle, up to a bottle and a quarter', () {
      expect(left(750), 'One bottle to go');
      expect(left(937), 'One bottle to go'); // 1.249
      expect(left(938), 'About a bottle and a half to go');
    });

    test('a bottle and a half, up to a bottle and three quarters', () {
      expect(left(1125), 'About a bottle and a half to go');
      expect(left(1312), 'About a bottle and a half to go'); // 1.749
      expect(left(1313), 'About 2 bottles to go');
    });

    test('then whole bottles, rounded', () {
      expect(left(1500), 'About 2 bottles to go');
      expect(left(1700), 'About 2 bottles to go'); // 2.27
      expect(left(1874), 'About 2 bottles to go'); // 2.499
      expect(left(1875), 'About 3 bottles to go'); // 2.5
      expect(left(2250), 'About 3 bottles to go');
      expect(left(3000), 'About 4 bottles to go');
    });

    test('it is relative to the bottle, not to 750', () {
      expect(left(1000, 500), 'About 2 bottles to go');
      expect(left(750, 500), 'About a bottle and a half to go');
      expect(left(1000, 1000), 'One bottle to go');
      expect(left(1000, 2000), 'Half a bottle to go');
    });

    test('a bottle of no size says nothing', () {
      expect(left(1000, 0), isNull);
    });
  });
}
