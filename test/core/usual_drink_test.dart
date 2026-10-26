import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/usual_drink.dart';

void main() {
  final now = DateTime(2026, 3, 20, 8, 10);

  /// A drink [daysAgo] days before [now], at [hour]:[minute].
  PastDrink drink(
    int daysAgo, {
    int hour = 8,
    int minute = 0,
    String id = 'coffee',
    String name = 'Coffee',
    int ml = 200,
    bool alcoholic = false,
  }) =>
      PastDrink(
        time: DateTime(2026, 3, 20 - daysAgo, hour, minute),
        beverageId: id,
        name: name,
        amountMl: ml,
        isAlcoholic: alcoholic,
      );

  List<PastDrink> coffeeOn(Iterable<int> daysAgo) =>
      [for (final d in daysAgo) drink(d)];

  group('a habit', () {
    test('the same drink on three separate mornings is the usual', () {
      final u = UsualDrinkCalc.at(now, coffeeOn([1, 2, 3]))!;
      expect(u.beverageId, 'coffee');
      expect(u.amountMl, 200);
      expect(u.days, 3);
    });

    test('two mornings is not enough', () {
      expect(UsualDrinkCalc.at(now, coffeeOn([1, 2])), isNull);
    });

    test('three drinks on ONE day is not a habit', () {
      expect(
          UsualDrinkCalc.at(now, [
            drink(1, minute: 0),
            drink(1, minute: 20),
            drink(1, minute: 40),
          ]),
          isNull);
    });

    test('nothing logged is nothing to offer', () {
      expect(UsualDrinkCalc.at(now, const []), isNull);
    });
  });

  group('this time of day', () {
    test('90 minutes either side counts; 91 does not', () {
      final edgeLate = [for (final d in [1, 2, 3]) drink(d, hour: 9, minute: 40)];
      final tooLate = [for (final d in [1, 2, 3]) drink(d, hour: 9, minute: 41)];
      final edgeEarly = [for (final d in [1, 2, 3]) drink(d, hour: 6, minute: 40)];
      expect(UsualDrinkCalc.at(now, edgeLate), isNotNull);
      expect(UsualDrinkCalc.at(now, tooLate), isNull);
      expect(UsualDrinkCalc.at(now, edgeEarly), isNotNull);
    });

    test('a 3pm drink is not the 8am usual', () {
      expect(
          UsualDrinkCalc.at(now, [for (final d in [1, 2, 3, 4]) drink(d, hour: 15)]),
          isNull);
    });

    test('the window wraps round midnight', () {
      final lateNight = DateTime(2026, 3, 20, 23, 50);
      final past = [
        for (final d in [1, 2, 3]) drink(d, hour: 0, minute: 20),
      ];
      // 00:20 is 30 minutes after 23:50, the short way round.
      expect(UsualDrinkCalc.at(lateNight, past), isNotNull);
    });

    test('morning habits do not show in the evening', () {
      final evening = DateTime(2026, 3, 20, 19);
      expect(UsualDrinkCalc.at(evening, coffeeOn([1, 2, 3, 4, 5])), isNull);
    });
  });

  group('which drink', () {
    test('the most frequent wins', () {
      final past = [
        ...coffeeOn([1, 2, 3, 4]),
        for (final d in [5, 6]) drink(d, id: 'tea', name: 'Tea', ml: 250),
      ];
      expect(UsualDrinkCalc.at(now, past)!.beverageId, 'coffee');
    });

    test('the same drink in a different size is a different drink', () {
      final past = [
        for (final d in [1, 2]) drink(d, ml: 200),
        for (final d in [3, 4]) drink(d, ml: 300),
      ];
      // Two days each: neither reaches three.
      expect(UsualDrinkCalc.at(now, past), isNull);
    });

    test('a tie goes to the more recent', () {
      final past = [
        for (final d in [2, 4, 6]) drink(d, id: 'tea', name: 'Tea', ml: 250),
        for (final d in [1, 3, 5]) drink(d),
      ];
      expect(UsualDrinkCalc.at(now, past)!.beverageId, 'coffee');
    });

    test('a habit must be a real share of the mornings, not three in twenty', () {
      final past = [
        ...coffeeOn([1, 2, 3]),
        for (var d = 4; d <= 20; d++)
          drink(d, id: 'water', name: 'Water', ml: 100 + d), // all different
      ];
      expect(UsualDrinkCalc.at(now, past), isNull,
          reason: '3 of 20 mornings is under 40%');
    });

    test('three of seven mornings is enough', () {
      final past = [
        ...coffeeOn([1, 2, 3]),
        for (var d = 4; d <= 7; d++)
          drink(d, id: 'water', name: 'Water', ml: 100 + d),
      ];
      expect(UsualDrinkCalc.at(now, past)!.beverageId, 'coffee');
    });
  });

  group('what is left out', () {
    test('alcohol is never offered, however regular', () {
      final past = [
        for (final d in [1, 2, 3, 4, 5])
          drink(d, id: 'beer', name: 'Beer', ml: 330, alcoholic: true),
      ];
      expect(UsualDrinkCalc.at(now, past), isNull);
    });

    test('alcohol does not crowd out a real habit either', () {
      final past = [
        ...coffeeOn([1, 2, 3]),
        for (final d in [4, 5, 6, 7, 8])
          drink(d, id: 'beer', name: 'Beer', ml: 330, alcoholic: true),
      ];
      expect(UsualDrinkCalc.at(now, past)!.beverageId, 'coffee');
    });

    test('today does not count, so logging cannot make a drink more "usual"',
        () {
      final past = [...coffeeOn([1, 2]), drink(0, minute: 5)];
      expect(UsualDrinkCalc.at(now, past), isNull);
    });

    test('anything older than 30 days is ignored', () {
      expect(UsualDrinkCalc.at(now, coffeeOn([31, 32, 33])), isNull);
      expect(UsualDrinkCalc.at(now, coffeeOn([28, 29, 30])), isNotNull);
    });

    test('zero-volume entries are ignored', () {
      expect(
          UsualDrinkCalc.at(now, [for (final d in [1, 2, 3]) drink(d, ml: 0)]),
          isNull);
    });
  });
}
