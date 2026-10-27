/// Two quiet notes worked out from today's log: a glass of water after alcohol,
/// and late caffeine against tonight's bedtime.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/services/drink_notes.dart';

void main() {
  DateTime at(int h, [int m = 0, int d = 14]) => DateTime(2026, 3, d, h, m);
  const tenThirty = 22 * 60 + 30;

  var n = 0;
  EnhancedWaterLog log(
    String name,
    DateTime time, {
    int ml = 250,
    int caffeine = 0,
    bool alcohol = false,
  }) =>
      EnhancedWaterLog(
        id: 'l${n++}',
        time: time,
        amountMl: ml,
        effectiveHydrationMl: ml,
        beverageId: name.toLowerCase(),
        beverageName: name,
        beverageEmoji: '',
        caffeineAmount: caffeine,
        isAlcoholic: alcohol,
      );

  group('a glass of water after alcohol', () {
    test('no alcohol, no note', () {
      expect(DrinkNotes.chaserDue([log('Water', at(18))], at(19)), isFalse);
      expect(DrinkNotes.chaserDue(const [], at(19)), isFalse);
    });

    test('a drink with nothing since is owed a glass', () {
      final logs = [log('Beer', at(18), ml: 330, alcohol: true)];
      expect(DrinkNotes.chaserDue(logs, at(18, 5)), isTrue);
      expect(DrinkNotes.chaserDue(logs, at(20, 59)), isTrue);
    });

    test('a glass of water since settles it', () {
      final logs = [
        log('Beer', at(18), ml: 330, alcohol: true),
        log('Water', at(18, 20), ml: 250),
      ];
      expect(DrinkNotes.chaserDue(logs, at(18, 30)), isFalse);
    });

    test('less than a glass does not', () {
      final logs = [
        log('Beer', at(18), ml: 330, alcohol: true),
        log('Water', at(18, 20), ml: 249),
      ];
      expect(DrinkNotes.chaserDue(logs, at(18, 30)), isTrue);
    });

    test('and smaller sips add up', () {
      final logs = [
        log('Beer', at(18), ml: 330, alcohol: true),
        log('Water', at(18, 10), ml: 100),
        log('Water', at(18, 25), ml: 150),
      ];
      expect(DrinkNotes.chaserDue(logs, at(18, 30)), isFalse);
    });

    test('a tea beside a beer is the same thing the note asks for', () {
      final logs = [
        log('Beer', at(18), ml: 330, alcohol: true),
        log('Tea', at(18, 20), ml: 300, caffeine: 60),
      ];
      expect(DrinkNotes.chaserDue(logs, at(18, 30)), isFalse);
    });

    test('another alcoholic drink is not a chaser', () {
      final logs = [
        log('Beer', at(18), ml: 330, alcohol: true),
        log('Wine', at(18, 40), ml: 300, alcohol: true),
      ];
      expect(DrinkNotes.chaserDue(logs, at(18, 50)), isTrue);
    });

    test('it is measured from the LATEST alcoholic drink', () {
      final logs = [
        log('Beer', at(18), ml: 330, alcohol: true),
        log('Water', at(18, 20), ml: 300),
        log('Wine', at(19), ml: 150, alcohol: true),
      ];
      expect(DrinkNotes.chaserDue(logs, at(19, 10)), isTrue,
          reason: 'the water was before the second drink');
    });

    test('water drunk BEFORE the drink does not count for it', () {
      final logs = [
        log('Water', at(17, 30), ml: 500),
        log('Beer', at(18), ml: 330, alcohol: true),
      ];
      expect(DrinkNotes.chaserDue(logs, at(18, 10)), isTrue);
    });

    test('three hours on, it is no longer about that drink', () {
      final logs = [log('Beer', at(18), ml: 330, alcohol: true)];
      expect(DrinkNotes.chaserDue(logs, at(21)), isTrue);
      expect(DrinkNotes.chaserDue(logs, at(21, 1)), isFalse);
    });

    test('a drink dated in the future is not yet', () {
      final logs = [log('Beer', at(20), ml: 330, alcohol: true)];
      expect(DrinkNotes.chaserDue(logs, at(19)), isFalse);
    });
  });

  group('late caffeine', () {
    LateCaffeine? late(List<EnhancedWaterLog> logs, DateTime now,
            {int bed = tenThirty}) =>
        DrinkNotes.lateCaffeine(logs, now, bedtimeMinutes: bed);

    test('a coffee after the cut-off names the drink and both times', () {
      final w = late([log('Coffee', at(16), caffeine: 80)], at(17))!;
      expect(w.drink, 'Coffee');
      expect(w.cutoff, at(14, 30));
      expect(w.bedtime, at(22, 30));
    });

    test('a morning coffee is nothing', () {
      expect(late([log('Coffee', at(10), caffeine: 80)], at(17)), isNull);
    });

    test('decaf and a trace are nothing', () {
      expect(late([log('Decaf', at(16), caffeine: 3)], at(17)), isNull);
    });

    test('a drink with no caffeine is nothing, whatever the hour', () {
      expect(late([log('Water', at(20))], at(20, 5)), isNull);
    });

    test('once bedtime has come it is over', () {
      final logs = [log('Coffee', at(16), caffeine: 80)];
      expect(late(logs, at(22, 29)), isNotNull);
      expect(late(logs, at(22, 30)), isNull);
    });

    test('with several, the latest is the one named', () {
      final w = late([
        log('Tea', at(15), caffeine: 50),
        log('Energy drink', at(18), caffeine: 160),
        log('Coffee', at(16), caffeine: 80),
      ], at(19))!;
      expect(w.drink, 'Energy drink');
    });

    test('a bedtime after midnight is tonight\'s, from the afternoon', () {
      final w = late([log('Coffee', at(19), caffeine: 80)], at(20), bed: 30)!;
      expect(w.bedtime, at(0, 30, 15));
      expect(w.cutoff, at(16, 30));
    });

    test('a drink dated in the future is not yet', () {
      expect(late([log('Coffee', at(18), caffeine: 80)], at(16)), isNull);
    });
  });
}
