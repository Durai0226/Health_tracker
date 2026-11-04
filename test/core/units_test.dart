/// Volume and weight units. Everything stored is millilitres and kilograms; a unit
/// is only how a number is shown and how typed text is read.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/utils/units.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  group('the choice', () {
    test('is millilitres and kilograms until someone chooses otherwise', () {
      expect(Units.volume, VolumeUnit.ml);
      expect(Units.weight, WeightUnit.kg);
    });

    test('is kept, and read back, per quantity', () async {
      await Units.setVolume(VolumeUnit.flOz);
      expect(Units.volume, VolumeUnit.flOz);
      expect(Units.weight, WeightUnit.kg, reason: 'one does not move the other');

      await Units.setWeight(WeightUnit.lb);
      expect(Units.weight, WeightUnit.lb);
      expect(Units.volume, VolumeUnit.flOz);
    });

    test('uses the key the Weight screen has always written', () async {
      await CleanStorageService.setAppPreference('weight_unit', 'lb');
      expect(Units.weight, WeightUnit.lb,
          reason: 'a person who chose pounds there must not be reset');
    });

    test('an unknown stored value means the default', () async {
      await CleanStorageService.setAppPreference('water_unit', 'pints');
      await CleanStorageService.setAppPreference('weight_unit', 'stone');
      expect(Units.volume, VolumeUnit.ml);
      expect(Units.weight, WeightUnit.kg);
    });

    test('changing either announces it, so an open screen can rebuild', () async {
      var heard = 0;
      void listener() => heard++;
      Units.changes.addListener(listener);
      addTearDown(() => Units.changes.removeListener(listener));

      await Units.setVolume(VolumeUnit.flOz);
      await Units.setWeight(WeightUnit.lb);

      expect(heard, 2);
    });

    test('before the preferences are loaded it answers the default, not an error',
        () {
      CleanStorageService.resetForTesting();
      expect(Units.volume, VolumeUnit.ml);
      expect(Units.weight, WeightUnit.kg);
    });

    test('with no storage wired at all it is millilitres and kilograms, and a set '
        'is quietly nowhere', () async {
      addTearDown(() => CleanStorageService.init()); // wire it again for the rest
      Units.resetForTesting();

      expect(Units.volume, VolumeUnit.ml);
      await Units.setVolume(VolumeUnit.flOz); // nowhere to keep it
      expect(Units.volume, VolumeUnit.ml);
    });
  });

  group('volume shown', () {
    test('millilitres are whole and unchanged', () {
      expect(Units.volumeText(250, unit: VolumeUnit.ml), '250 ml');
      expect(Units.volumeNumber(2500, VolumeUnit.ml), '2500');
      expect(Units.volumeText(0, unit: VolumeUnit.ml), '0 ml');
    });

    test('ounces are US fluid ounces to one decimal, with no trailing ".0"', () {
      expect(Units.volumeText(237, unit: VolumeUnit.flOz), '8 fl oz');
      expect(Units.volumeText(250, unit: VolumeUnit.flOz), '8.5 fl oz');
      expect(Units.volumeText(355, unit: VolumeUnit.flOz), '12 fl oz');
      expect(Units.volumeText(473, unit: VolumeUnit.flOz), '16 fl oz');
      expect(Units.volumeText(0, unit: VolumeUnit.flOz), '0 fl oz');
    });

    test('from a hundred ounces up the decimal is dropped', () {
      expect(Units.volumeNumber(3000, VolumeUnit.flOz), '101');
      expect(Units.volumeNumber(2956, VolumeUnit.flOz), '100');
      expect(Units.volumeNumber(2900, VolumeUnit.flOz), '98.1');
    });

    test('follows the chosen unit when none is given', () async {
      expect(Units.volumeText(250), '250 ml');
      await Units.setVolume(VolumeUnit.flOz);
      expect(Units.volumeText(250), '8.5 fl oz');
      expect(Units.volumeSymbol(), 'fl oz');
    });

    test('the older tight spelling is kept for millilitres only', () {
      expect(Units.volumeText(250, unit: VolumeUnit.ml, tight: true), '250ml');
      expect(Units.volumeText(250, unit: VolumeUnit.flOz, tight: true), '8.5 fl oz',
          reason: '"8.5floz" reads as a typo');
    });

    test('one US fluid ounce is 29.5735 ml', () {
      expect(Units.mlPerFlOz, closeTo(29.5735, 0.0001));
      expect(Units.volumeValue(Units.mlPerFlOz.round(), VolumeUnit.flOz),
          closeTo(1, 0.02));
    });
  });

  group('volume typed', () {
    test('millilitres are taken as typed', () {
      expect(Units.mlFromInput('250', VolumeUnit.ml), 250);
      expect(Units.mlFromInput(' 250 ', VolumeUnit.ml), 250);
      expect(Units.mlFromInput('250.4', VolumeUnit.ml), 250);
    });

    test('ounces become the nearest millilitre', () {
      expect(Units.mlFromInput('8', VolumeUnit.flOz), 237);
      expect(Units.mlFromInput('12', VolumeUnit.flOz), 355);
      expect(Units.mlFromInput('0.5', VolumeUnit.flOz), 15);
    });

    test('a comma is a decimal point', () {
      expect(Units.mlFromInput('8,5', VolumeUnit.flOz), 251);
    });

    test('what is not a positive number is nothing', () {
      for (final bad in ['', ' ', 'abc', '0', '-3', 'NaN', 'Infinity', '1e999']) {
        expect(Units.mlFromInput(bad, VolumeUnit.ml), isNull, reason: '"$bad"');
        expect(Units.mlFromInput(bad, VolumeUnit.flOz), isNull, reason: '"$bad"');
      }
    });

    test('a typed whole number of ounces reads back as that number', () {
      for (final oz in [1, 4, 6, 8, 12, 16, 20, 24, 32, 64, 80, 100]) {
        final ml = Units.mlFromInput('$oz', VolumeUnit.flOz)!;
        expect(Units.volumeInput(ml, VolumeUnit.flOz), '$oz', reason: '$oz oz -> $ml ml');
      }
    });

    test('a whole number of millilitres reads back as itself', () {
      for (final ml in [50, 250, 1000, 2500, 3152]) {
        expect(Units.volumeInput(ml, VolumeUnit.ml), '$ml');
        expect(Units.mlFromInput(Units.volumeInput(ml, VolumeUnit.ml), VolumeUnit.ml), ml);
      }
    });
  });

  group('spoken', () {
    test('millilitres', () {
      expect(Units.volumeSpoken(250, VolumeUnit.ml), '250 millilitres');
      expect(Units.volumeSpoken(1, VolumeUnit.ml), '1 millilitre');
    });

    test('ounces, with the singular', () {
      expect(Units.volumeSpoken(250, VolumeUnit.flOz), '8.5 fluid ounces');
      expect(Units.volumeSpoken(30, VolumeUnit.flOz), '1 fluid ounce');
    });
  });

  group('presets and steps', () {
    const mlSizes = [100, 250, 500];
    const ozSizes = [4, 8, 16];

    test('millilitre choices as given', () {
      expect(Units.presetsMl(mlSizes, ozSizes, VolumeUnit.ml), mlSizes);
    });

    test('ounce choices are round ounces, converted', () {
      expect(Units.presetsMl(mlSizes, ozSizes, VolumeUnit.flOz), [118, 237, 473]);
    });

    test('a step is the millilitre step or the ounces\' worth', () {
      expect(Units.stepMl(50, 1, VolumeUnit.ml), 50);
      expect(Units.stepMl(50, 1, VolumeUnit.flOz), 30);
      expect(Units.stepMl(250, 8, VolumeUnit.flOz), 237);
    });
  });

  group('weight', () {
    test('kilograms to one decimal, with no trailing ".0"', () {
      expect(Units.weightText(68.5, WeightUnit.kg), '68.5 kg');
      expect(Units.weightText(70, WeightUnit.kg), '70 kg');
    });

    test('pounds', () {
      expect(Units.weightText(70, WeightUnit.lb), '154.3 lb');
      expect(Units.weightNumber(68.0388555, WeightUnit.lb), '150');
    });

    test('typed kilograms and pounds', () {
      expect(Units.kgFromInput('70', WeightUnit.kg), 70);
      expect(Units.kgFromInput('154,3', WeightUnit.lb), closeTo(69.99, 0.01));
    });

    test('150 lb reads back as 150, not 149.9', () {
      final kg = Units.kgFromInput('150', WeightUnit.lb)!;
      expect(Units.weightNumber(kg, WeightUnit.lb), '150');
    });

    test('zero ounces is not a whole number of ounces', () {
      expect(Units.isWholeOunces(0), isFalse);
      expect(Units.isWholeOunces(10), isFalse);
      expect(Units.isWholeOunces(30), isTrue);
    });

    test('what is not a positive number is nothing', () {
      for (final bad in ['', 'abc', '0', '-1', 'NaN']) {
        expect(Units.kgFromInput(bad, WeightUnit.kg), isNull, reason: '"$bad"');
        expect(Units.kgFromInput(bad, WeightUnit.lb), isNull, reason: '"$bad"');
      }
    });

    test('follows the chosen unit when none is given', () async {
      expect(Units.weightText(70), '70 kg');
      await Units.setWeight(WeightUnit.lb);
      expect(Units.weightText(70), '154.3 lb');
    });
  });
}
