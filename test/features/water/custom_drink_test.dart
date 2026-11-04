/// The rules for a drink the person makes themselves — pure, no screen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/custom_drink.dart';

void main() {
  final catalogue = BeverageType.defaultBeverages;
  final shake = CustomDrink.build(
      id: 'custom_protein_shake', name: 'Protein shake', colorHex: '#2196F3');

  group('the name', () {
    test('is required, and spaces alone are not a name', () {
      expect(CustomDrink.nameError('', catalogue), isNotNull);
      expect(CustomDrink.nameError('   ', catalogue), isNotNull);
    });

    test('is counted in characters, not code units: 24 emoji are 24', () {
      expect(CustomDrink.nameError('🥤' * 24, catalogue), isNull);
      expect(CustomDrink.nameError('🥤' * 25, catalogue), isNotNull);
    });

    test('is at most 24 characters, counted after the spaces are tidied', () {
      expect(CustomDrink.nameError('a' * 24, catalogue), isNull);
      expect(CustomDrink.nameError('a' * 25, catalogue), isNotNull);
      // 24 letters with a doubled space inside: 25 characters typed, 24 kept.
      expect(CustomDrink.nameError('${'a' * 12}  ${'b' * 11}', catalogue), isNull);
    });

    test('cannot repeat a catalogue drink, whatever the case', () {
      final name = catalogue.first.name;
      expect(CustomDrink.nameError(name, catalogue), contains(name));
      expect(CustomDrink.nameError(name.toUpperCase(), catalogue), isNotNull);
      expect(CustomDrink.nameError('  ${name.toLowerCase()} ', catalogue), isNotNull);
    });

    test('cannot repeat one of the person\'s own', () {
      final all = [...catalogue, shake];
      expect(CustomDrink.nameError('protein  SHAKE', all), isNotNull);
    });

    test('may keep its own name when it is the one being edited', () {
      final all = [...catalogue, shake];
      expect(CustomDrink.nameError('Protein shake', all, editingId: shake.id), isNull);
      expect(CustomDrink.nameError('Protein shake', all, editingId: 'custom_other'),
          isNotNull,
          reason: 'but another drink may not take it');
    });
  });

  group('the id', () {
    test('is readable, and starts with the custom prefix', () {
      expect(CustomDrink.newId('Protein shake', const []), 'custom_protein_shake');
      expect(CustomDrink.newId("Gran's ginger tea!", const []), 'custom_gran_s_ginger_tea');
    });

    test('never repeats one that is taken', () {
      expect(CustomDrink.newId('Protein shake', const ['custom_protein_shake']),
          'custom_protein_shake_2');
      expect(
          CustomDrink.newId('Protein shake',
              const ['custom_protein_shake', 'custom_protein_shake_2']),
          'custom_protein_shake_3');
    });

    test('falls back to "drink" when the name has no letters or digits', () {
      expect(CustomDrink.newId('🥤🥤', const []), 'custom_drink');
      expect(CustomDrink.newId('🥤', const ['custom_drink']), 'custom_drink_2');
    });

    test('can never be a catalogue id, which are plain words', () {
      for (final b in catalogue) {
        expect(CustomDrink.newId(b.name, const []), isNot(b.id));
        expect(CustomDrink.newId(b.name, const []).startsWith(CustomDrink.idPrefix), isTrue);
      }
    });

    test('for the longest name allowed is not cut short', () {
      expect(CustomDrink.newId('x' * 24, const []), 'custom_${'x' * 24}');
    });
  });

  group('building the drink', () {
    test('a drink with no caffeine says so', () {
      expect(shake.hasCaffeine, isFalse);
      expect(shake.caffeinePerMl, 0);
      expect(shake.isAlcoholic, isFalse);
      expect(shake.hydrationPercent, 100);
    });

    test('caffeine turns the flag on, and is the figure given', () {
      final b = CustomDrink.build(
          id: 'custom_x', name: 'X', colorHex: '#2196F3', caffeineMg: 80);
      expect(b.hasCaffeine, isTrue);
      expect(b.caffeinePerMl, 80);
    });

    test('a figure outside the range is brought inside it, not refused', () {
      expect(
          CustomDrink.build(
                  id: 'a', name: 'A', colorHex: '#000000', caffeineMg: 9000)
              .caffeinePerMl,
          CustomDrink.maxCaffeineMg);
      final none = CustomDrink.build(
          id: 'a', name: 'A', colorHex: '#000000', caffeineMg: -5);
      expect(none.hasCaffeine, isFalse);
      expect(none.caffeinePerMl, 0);
      expect(
          CustomDrink.build(
                  id: 'a', name: 'A', colorHex: '#000000', countsAsPercent: 400)
              .hydrationPercent,
          100,
          reason: 'a drink can never count for more than it was');
      expect(
          CustomDrink.build(
                  id: 'a', name: 'A', colorHex: '#000000', countsAsPercent: -20)
              .hydrationPercent,
          greaterThan(0),
          reason: 'and a custom drink is never a deduction: alcohol is the one '
              'drink that is, and it is worked out from its strength');
    });

    test('the name is stored tidied', () {
      expect(CustomDrink.build(id: 'a', name: '  Oat   milk  latte ', colorHex: '#000000').name,
          'Oat milk latte');
    });

    test('the hydration it gives is the percentage of the amount', () {
      final half = CustomDrink.build(
          id: 'a', name: 'A', colorHex: '#000000', countsAsPercent: 50);
      expect(half.getEffectiveHydration(300), 150);
    });
  });

  group('a drink read from a file is held to the same limits as one made here', () {
    BeverageType raw({
      String id = 'custom_x',
      String name = 'X',
      int percent = 100,
      int caffeine = 0,
      bool caffeinated = false,
      bool alcoholic = false,
    }) =>
        BeverageType(
          id: id,
          name: name,
          emoji: '🥤',
          hydrationPercent: percent,
          hasCaffeine: caffeinated,
          caffeinePerMl: caffeine,
          isAlcoholic: alcoholic,
        );

    test('a percentage outside 1 to 100 is brought inside it', () {
      expect(CustomDrink.sanitized(raw(percent: 5000))!.hydrationPercent, 100);
      expect(CustomDrink.sanitized(raw(percent: -50))!.hydrationPercent, 1,
          reason: 'a custom drink is never a deduction');
    });

    test('caffeine is held to its range, and the flag follows the figure', () {
      final big = CustomDrink.sanitized(raw(caffeinated: true, caffeine: 99999))!;
      expect(big.caffeinePerMl, CustomDrink.maxCaffeineMg);
      final none = CustomDrink.sanitized(raw(caffeinated: true, caffeine: 0))!;
      expect(none.hasCaffeine, isFalse);
      final unflagged = CustomDrink.sanitized(raw(caffeinated: false, caffeine: 80))!;
      expect(unflagged.caffeinePerMl, 0, reason: 'no flag, no caffeine');
    });

    test('an alcoholic drink is left out, not re-scored as if it were water', () {
      expect(CustomDrink.sanitized(raw(alcoholic: true, percent: -20)), isNull,
          reason: 'its effect is worked out from its strength, not typed in');
    });

    test('a name is counted and cut in code points, so an emoji is not split', () {
      final long = 'Shake ${'🥤' * 30}';
      final cut = CustomDrink.sanitized(raw(name: long))!.name;
      expect(cut.runes.length, 24);
      expect(cut.runes.every((r) => r != 0xFFFD), isTrue);
      // Every code unit is paired: no lone surrogate.
      for (var i = 0; i < cut.length; i++) {
        final u = cut.codeUnitAt(i);
        if (u >= 0xD800 && u <= 0xDBFF) {
          expect(cut.codeUnitAt(i + 1), inInclusiveRange(0xDC00, 0xDFFF));
          i++;
        } else {
          expect(u, isNot(inInclusiveRange(0xDC00, 0xDFFF)));
        }
      }
    });

    test('the glyph and default amount are kept, inside their limits', () {
      final kept = CustomDrink.sanitized(BeverageType(
          id: 'custom_x', name: 'X', emoji: '🫖', defaultAmountMl: 500))!;
      expect((kept.emoji, kept.defaultAmountMl), ('🫖', 500));
      final wild = CustomDrink.sanitized(BeverageType(
          id: 'custom_x', name: 'X', emoji: '', defaultAmountMl: 900000))!;
      expect((wild.emoji, wild.defaultAmountMl), ('🥤', 5000));
    });

    test('the name is tidied and cut to length; none left is nothing', () {
      expect(CustomDrink.sanitized(raw(name: '  a   b '))!.name, 'a b');
      expect(CustomDrink.sanitized(raw(name: 'x' * 60))!.name, 'x' * 24);
      expect(CustomDrink.sanitized(raw(name: '   ')), isNull);
      expect(CustomDrink.sanitized(raw(id: '')), isNull);
    });

    test('a drink already in range is left as it is', () {
      final ok = CustomDrink.build(
          id: 'custom_ok', name: 'Ok', colorHex: '#4CAF50', countsAsPercent: 75, caffeineMg: 40);
      final back = CustomDrink.sanitized(ok)!;
      expect((back.name, back.hydrationPercent, back.caffeinePerMl, back.colorHex),
          (ok.name, ok.hydrationPercent, ok.caffeinePerMl, ok.colorHex));
    });
  });

  group('editing keeps what the form does not show', () {
    final legacy = BeverageType(
      id: 'kombucha',
      name: 'Kombucha',
      emoji: '🫙',
      hydrationPercent: 80,
      colorHex: '#123456',
      defaultAmountMl: 330,
    );

    test('the glyph, the default amount and the id are the drink\'s own', () {
      final e = CustomDrink.edited(legacy,
          name: 'Kombucha', colorHex: '#4CAF50', countsAsPercent: 80, caffeineMg: 0);
      expect((e.id, e.emoji, e.defaultAmountMl), ('kombucha', '🫙', 330));
      expect(e.colorHex, '#4CAF50');
    });

    test('a percentage the form was not used to change is kept exactly, even off the steps',
        () {
      final e = CustomDrink.edited(legacy,
          name: 'K', colorHex: '#000000', countsAsPercent: 80, caffeineMg: 0);
      expect(e.hydrationPercent, 80, reason: 'not rounded to 75 by being opened and saved');
    });

    test('a legacy value below the steps (a deduction) is kept exactly when untouched', () {
      final deduction = legacy.copyWith(hydrationPercent: -20);
      final e = CustomDrink.edited(deduction,
          name: 'K', colorHex: '#000000', countsAsPercent: -20, caffeineMg: 0);
      expect(e.hydrationPercent, -20,
          reason: 'not turned into a 1% drink by being opened and saved');
    });

    test('one that was changed is held to 1–100', () {
      expect(
          CustomDrink.edited(legacy,
                  name: 'K', colorHex: '#000000', countsAsPercent: 500, caffeineMg: 0)
              .hydrationPercent,
          100);
      expect(
          CustomDrink.edited(legacy,
                  name: 'K', colorHex: '#000000', countsAsPercent: 50, caffeineMg: 0)
              .hydrationPercent,
          50);
    });

    test('caffeine follows the form', () {
      final e = CustomDrink.edited(legacy,
          name: 'K', colorHex: '#000000', countsAsPercent: 80, caffeineMg: 80);
      expect((e.hasCaffeine, e.caffeinePerMl), (true, 80));
    });

    test('the name is tidied', () {
      expect(
          CustomDrink.edited(legacy,
                  name: '  a  b ', colorHex: '#000000', countsAsPercent: 80, caffeineMg: 0)
              .name,
          'a b');
    });
  });

  group('the one line under it', () {
    test('says what it counts for and what it carries', () {
      expect(CustomDrink.summary(shake), 'Counts in full · no caffeine');
      final latte = CustomDrink.build(
          id: 'custom_l',
          name: 'Latte',
          colorHex: '#000000',
          countsAsPercent: 75,
          caffeineMg: 40);
      expect(CustomDrink.summary(latte), 'Counts 75% · 40 mg caffeine per 100 ml');
    });
  });
}
