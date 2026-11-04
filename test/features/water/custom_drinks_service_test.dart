/// The drinks and cups a person makes: kept, changed, removed, ordered by use,
/// and carried through a backup.
///
/// `addCustomBeverage` and the table behind it existed long before anything could
/// reach them; these pin what happens once something can.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/custom_drink.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  }

  setUp(boot);
  tearDown(() async {
    await WaterService.resetForTesting();
    await database.close();
  });

  BeverageType shake({String name = 'Protein shake', int percent = 75, int caffeine = 0}) =>
      CustomDrink.build(
          id: 'custom_protein_shake',
          name: name,
          colorHex: '#4CAF50',
          countsAsPercent: percent,
          caffeineMg: caffeine);

  /// A cold start against the SAME database: what a restart does.
  Future<void> restart() async {
    await WaterService.resetForTesting();
    await WaterService.init();
  }

  group('making, changing and removing a drink', () {
    test('a drink made is in the list and survives a restart, whole', () async {
      await WaterService.addCustomBeverage(shake(caffeine: 40));
      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull);

      await restart();

      final back = WaterService.getBeverage('custom_protein_shake')!;
      expect(back.name, 'Protein shake');
      expect(back.hydrationPercent, 75);
      expect(back.hasCaffeine, isTrue);
      expect(back.caffeinePerMl, 40);
      expect(back.colorHex.toLowerCase(), '#4caf50');
      expect(WaterService.isCustomBeverage('custom_protein_shake'), isTrue);
    });

    test('editing changes it in place, keeps its place in the list, and persists',
        () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addCustomBeverage(CustomDrink.build(
          id: 'custom_later', name: 'Later', colorHex: '#2196F3'));

      await WaterService.updateCustomBeverage(shake(name: 'Whey shake', percent: 50));

      expect(WaterService.getCustomBeverages().map((b) => b.id),
          ['custom_protein_shake', 'custom_later'],
          reason: 'an edit is not a new drink and does not move');
      await restart();
      final back = WaterService.getBeverage('custom_protein_shake')!;
      expect((back.name, back.hydrationPercent), ('Whey shake', 50));
      expect(WaterService.getCustomBeverages().length, 2,
          reason: 'saving the edit replaced the row, it did not add another');
    });

    test('which drinks are theirs is what the list says, prefix or not', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addCustomBeverage(
          BeverageType(id: 'kombucha', name: 'Kombucha', emoji: '🫙'));

      expect(WaterService.isCustomBeverage('custom_protein_shake'), isTrue);
      expect(WaterService.isCustomBeverage('kombucha'), isTrue,
          reason: 'made before ids carried a prefix, and still theirs to edit');
      for (final b in BeverageType.defaultBeverages) {
        expect(WaterService.isCustomBeverage(b.id), isFalse, reason: b.id);
      }
      expect(WaterService.isCustomBeverage('nothing'), isFalse);
    });

    test('editing a drink that was deleted meanwhile throws, and writes nothing', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.deleteBeverage('custom_protein_shake');

      await expectLater(
          WaterService.updateCustomBeverage(shake(name: 'Too late')), throwsStateError,
          reason: 'saying "saved" would be a lie');

      expect(await database.waterDao.getAllBeverages(), isEmpty,
          reason: 'and the deleted drink does not come back in storage only');
    });

    test('a built-in drink\'s id cannot be added as a custom drink', () async {
      final id = BeverageType.defaultBeverages.first.id;
      await expectLater(
          WaterService.addCustomBeverage(BeverageType(id: id, name: 'Hijack', emoji: '🥤')),
          throwsArgumentError);
      expect(WaterService.getCustomBeverages(), isEmpty);
      expect(WaterService.isCustomBeverage(id), isFalse);
    });

    test('a delete the storage refused leaves the drink where it was', () async {
      await WaterService.addCustomBeverage(shake());
      await database.close();

      await expectLater(
          WaterService.deleteBeverage('custom_protein_shake'), throwsA(anything));

      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull,
          reason: 'it would otherwise show as deleted and come back at the next start');
    });

    test('editing a catalogue drink is refused, and does not make it a custom one', () async {
      final catalogue = BeverageType.defaultBeverages.first;
      await expectLater(
          WaterService.updateCustomBeverage(catalogue.copyWith(name: 'Hijacked')),
          throwsStateError);
      expect(WaterService.getBeverage(catalogue.id)!.name, catalogue.name);
      expect(WaterService.getCustomBeverages(), isEmpty);
    });

    test('deleting removes it from the list and from storage', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.deleteBeverage('custom_protein_shake');

      expect(WaterService.getBeverage('custom_protein_shake'), isNull);
      await restart();
      expect(WaterService.getBeverage('custom_protein_shake'), isNull);
      expect(await database.waterDao.getAllBeverages(), isEmpty);
    });

    test('adding the same drink twice lists it once (Undo can be tapped twice)', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addCustomBeverage(shake());
      expect(WaterService.getCustomBeverages().length, 1);

      await WaterService.addCustomBeverage(shake(name: 'Renamed'));
      expect(WaterService.getCustomBeverages().single.name, 'Renamed',
          reason: 'the later one is what is kept');
    });

    test('a drink that could not be written is not kept, and the caller is told',
        () async {
      await database.close();
      await expectLater(
          WaterService.addCustomBeverage(shake()), throwsA(anything));
      expect(WaterService.getCustomBeverages(), isEmpty,
          reason: 'a drink that is only in the list is gone at the next start, '
              'with logs that name it');
    });

    test('a change that could not be written leaves the drink as it was', () async {
      await WaterService.addCustomBeverage(shake());
      await database.close();

      await expectLater(
          WaterService.updateCustomBeverage(shake(name: 'Changed')), throwsA(anything));

      expect(WaterService.getBeverage('custom_protein_shake')!.name, 'Protein shake');
    });

    test('the ids the log remembers are known, so a new drink can avoid them',
        () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addWaterLog(
          amountMl: 200, beverage: WaterService.getBeverage('custom_protein_shake')!);
      await WaterService.deleteBeverage('custom_protein_shake');

      expect(WaterService.getBeverage('custom_protein_shake'), isNull);
      expect(WaterService.loggedBeverageIds(), contains('custom_protein_shake'),
          reason: 'the drink is gone, its logs are not');
    });

    test('a catalogue drink cannot be deleted, even if a row for it is stored', () async {
      final id = BeverageType.defaultBeverages.first.id;
      // Older installs could hold a row under a catalogue id.
      await database.waterDao.saveBeverage(db.BeverageTypesCompanion.insert(
          id: id, name: 'Stored', colorValue: 0xFF2196F3));

      await WaterService.deleteBeverage(id);

      expect(WaterService.getBeverage(id), isNotNull);
      expect((await database.waterDao.getAllBeverages()).map((r) => r.id), [id],
          reason: 'it is not the person\'s to remove, so the row is left alone');
    });

    test('drinks already logged keep what they were logged with', () async {
      await WaterService.addCustomBeverage(shake(caffeine: 40));
      await WaterService.addWaterLog(
          amountMl: 400, beverage: WaterService.getBeverage('custom_protein_shake')!);

      await WaterService.deleteBeverage('custom_protein_shake');

      final log = WaterService.getTodayData().logs.single;
      expect(log.beverageName, 'Protein shake');
      expect(log.hydrationPercent, 75);
      expect(log.effectiveHydrationMl, 300);
      expect(log.caffeineAmount, 160, reason: '40 mg per 100 ml of 400 ml');
    });

    test('an edit changes the next drink, not the ones already logged', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addWaterLog(
          amountMl: 400, beverage: WaterService.getBeverage('custom_protein_shake')!);

      await WaterService.updateCustomBeverage(shake(percent: 50));

      expect(WaterService.getTodayData().logs.single.effectiveHydrationMl, 300,
          reason: 'last month is not re-scored because a percentage changed today');
    });
  });

  group('the drinks list is in the order the person uses them', () {
    Future<void> log(String id, int times) async {
      for (var i = 0; i < times; i++) {
        await WaterService.addWaterLog(
            amountMl: 100, beverage: WaterService.getBeverage(id)!);
      }
    }

    test('most-logged first, then their own unused drinks, then the catalogue as it was',
        () async {
      final ids = BeverageType.defaultBeverages.map((b) => b.id).toList();
      await WaterService.addCustomBeverage(shake());
      await log(ids[2], 3);
      await log(ids[1], 1);

      final order = WaterService.getBeveragesByUse().map((b) => b.id).toList();

      expect(order.take(2), [ids[2], ids[1]]);
      expect(order[2], 'custom_protein_shake',
          reason: 'a drink made a minute ago is not buried behind the catalogue');
      expect(order.skip(3), [
        for (final id in ids)
          if (id != ids[2] && id != ids[1]) id
      ]);
      expect(order.length, ids.length + 1, reason: 'nothing is lost or repeated');
    });

    test('the favourites are the first of that order, as many as asked for', () async {
      await WaterService.addCustomBeverage(shake());
      final order = WaterService.getBeveragesByUse().map((b) => b.id).toList();

      expect(WaterService.getFavoriteBeverages(limit: 3).map((b) => b.id), order.take(3));
      expect(WaterService.getFavoriteBeverages().map((b) => b.id), order.take(6),
          reason: 'six unless told otherwise');
      expect(WaterService.getFavoriteBeverages(limit: 1000).length, order.length);
    });

    test('and the frequent cups are the first of the cups\' order', () async {
      final order = WaterService.getContainersByUse().map((c) => c.id).toList();
      expect(WaterService.getFrequentContainers().map((c) => c.id), order.take(4));
      expect(WaterService.getFrequentContainers(limit: 2).length, 2);
    });

    test('one they use a lot leads, custom or not', () async {
      await WaterService.addCustomBeverage(shake());
      await log('custom_protein_shake', 4);
      await log(BeverageType.defaultBeverages.first.id, 2);

      expect(WaterService.getBeveragesByUse().first.id, 'custom_protein_shake');
    });

    test('with nothing logged it is the catalogue in its own order, theirs first',
        () async {
      await WaterService.addCustomBeverage(shake());
      final order = WaterService.getBeveragesByUse().map((b) => b.id).toList();
      expect(order, [
        'custom_protein_shake',
        ...BeverageType.defaultBeverages.map((b) => b.id),
      ]);
    });

    test('cups: the most-used first, then their own before the built-in ones',
        () async {
      final builtIn = WaterContainer.defaultContainers;
      final teapot = WaterContainer(id: 'teapot', name: 'Teapot', emoji: '☕', capacityMl: 300);
      final flask = WaterContainer(id: 'flask', name: 'Flask', emoji: '🥛', capacityMl: 900);
      await WaterService.addCustomContainer(teapot);
      await WaterService.addCustomContainer(flask);
      final water = WaterService.getBeverage('water')!;
      for (var i = 0; i < 3; i++) {
        await WaterService.addWaterLog(
            amountMl: builtIn[1].capacityMl, beverage: water, container: builtIn[1]);
      }

      final order = WaterService.getContainersByUse().map((c) => c.id).toList();

      expect(order.first, builtIn[1].id, reason: 'used three times, so it leads');
      expect(order.skip(1).take(2), ['teapot', 'flask'],
          reason: 'of the cups nobody has used, theirs come before the built-in ones');
      expect(order.length, builtIn.length + 2);
    });
  });

  group('the backup', () {
    Future<Map<String, dynamic>> roundTripped() async => jsonDecode(
        jsonEncode(await CleanStorageService.exportAllData())) as Map<String, dynamic>;

    Future<void> wipeAndReload() async {
      await CleanStorageService.clearRestorableData();
      WaterService.clearInMemory();
      await WaterService.resetForTesting();
      await WaterService.init();
    }

    final mug = WaterContainer(id: 'travel_mug', name: 'Travel mug', emoji: '☕', capacityMl: 300);

    test('carries the drinks and cups the person made, in a section of its own',
        () async {
      await WaterService.addCustomBeverage(shake(caffeine: 40));
      await WaterService.addCustomContainer(mug);

      final backup = await roundTripped();

      expect(backup['version'], greaterThanOrEqualTo(9));
      final section = backup['waterSetup'] as Map;
      expect((section['beverages'] as List).single['name'], 'Protein shake');
      expect((section['containers'] as List).single['name'], 'Travel mug');
    });

    test('is written even when there are none, which is how it says "none"', () async {
      final backup = await roundTripped();
      final section = backup['waterSetup'] as Map;
      expect(section['beverages'], isEmpty);
      expect(section['containers'], isEmpty);
      expect(section['profile'], isA<Map>());
    });

    test('puts them back after a wipe', () async {
      await WaterService.addCustomBeverage(shake(caffeine: 40));
      await WaterService.addCustomContainer(mug);
      final backup = await roundTripped();

      await wipeAndReload();
      expect(WaterService.getCustomBeverages(), isEmpty, reason: 'premise: really gone');
      expect(await database.waterDao.getAllBeverages(), isEmpty);

      await CleanStorageService.importData(backup);

      final drink = WaterService.getBeverage('custom_protein_shake')!;
      expect((drink.name, drink.hydrationPercent, drink.caffeinePerMl), ('Protein shake', 75, 40));
      expect(WaterService.getContainer('travel_mug')?.capacityMl, 300);
      await restart();
      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull,
          reason: 'and they are in storage, not only in memory');
      expect(WaterService.getContainer('travel_mug'), isNotNull);
    });

    test('restoring the same file twice does not duplicate or fail', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addCustomContainer(mug);
      final backup = await roundTripped();

      await CleanStorageService.importData(backup);
      await CleanStorageService.importData(backup);

      expect(WaterService.getCustomBeverages().length, 1);
      expect(WaterService.getAllContainers().where((c) => c.id == 'travel_mug').length, 1);
    });

    test('a file made before there was a section leaves what is here alone', () async {
      await WaterService.addCustomBeverage(shake());
      final old = await roundTripped()
        ..remove('waterSetup')
        ..['version'] = 8;

      await CleanStorageService.importData(old);

      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull);
    });

    test('a file that says "none" replaces what is here with none', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addCustomContainer(mug);
      final empty = await roundTripped();
      empty['waterSetup'] = {'beverages': [], 'containers': []};

      await CleanStorageService.clearRestorableData(forBackup: empty);
      await CleanStorageService.importData(empty);

      expect(WaterService.getCustomBeverages(), isEmpty);
      expect(WaterService.getAllContainers().any((c) => c.id == 'travel_mug'), isFalse);
      expect(await database.waterDao.getAllBeverages(), isEmpty);
    });

    test('a damaged entry is skipped, the rest are restored, and a built-in id is refused',
        () async {
      final good = shake().toJson();
      final catalogueId = BeverageType.defaultBeverages.first.id;
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': [
            'not a map',
            {'id': 'custom_broken', 'name': 5, 'hydrationPercent': 'lots'},
            {'id': '', 'name': 'No id'},
            {'id': 'custom_nameless', 'name': ''},
            {'id': catalogueId, 'name': 'Hijacked', 'hydrationPercent': 1},
            good,
            good,
          ],
          'containers': [
            {'id': 'custom_zero', 'name': 'Zero', 'capacityMl': 0},
            mug.toJson(),
          ],
        },
      });

      expect(WaterService.getCustomBeverages().map((b) => b.id), ['custom_protein_shake'],
          reason: 'one valid drink, once');
      expect(WaterService.getBeverage(catalogueId)!.name, isNot('Hijacked'));
      expect(WaterService.getContainer('travel_mug'), isNotNull);
      expect(WaterService.getContainer('custom_zero'), isNull);
    });

    test('carries the hydration profile, and puts it back', () async {
      await WaterService.saveProfile(WaterService.getProfile()
          .copyWith(customGoalMl: 3100, useCustomGoal: true, weightKg: 71.5));
      final backup = await roundTripped();
      expect((backup['waterSetup'] as Map)['profile']['customGoalMl'], 3100);

      await wipeAndReload();
      expect(WaterService.getProfile().customGoalMl, isNot(3100), reason: 'premise: really gone');
      expect(await database.waterDao.getProfile(), isNull);

      await CleanStorageService.importData(backup);

      expect(WaterService.getProfile().customGoalMl, 3100);
      expect(WaterService.getProfile().weightKg, 71.5);
      await restart();
      expect(WaterService.getProfile().customGoalMl, 3100,
          reason: 'in storage, so it is still there after a restart');
    });

    test('an unreadable profile does not stop the drinks being restored', () async {
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': [shake().toJson()],
          'containers': const [],
          'profile': {'weightKg': 'heavy', 'customGoalMl': 'lots'},
        },
      });
      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull);
    });

    test('a restore that merges keeps the drinks and cups that are here', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addCustomContainer(mug);
      final other = CustomDrink.build(
          id: 'custom_oat_latte', name: 'Oat latte', colorHex: '#4CAF50');

      // No clearRestorableData: the file-based restore merges.
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': [other.toJson()],
          'containers': const [],
        },
      });

      expect(WaterService.getCustomBeverages().map((b) => b.id),
          containsAll(['custom_protein_shake', 'custom_oat_latte']),
          reason: 'a merge deletes nothing');
      expect(WaterService.getContainer('travel_mug'), isNotNull);
      await restart();
      expect(WaterService.getCustomBeverages().length, 2,
          reason: 'and memory and storage agree');
    });

    test('a merge does not overwrite a drink that is here with the file\'s version',
        () async {
      await WaterService.addCustomBeverage(shake(name: 'Mine', percent: 75));
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': [shake(name: 'Theirs', percent: 50).toJson()],
          'containers': const [],
        },
      });
      final b = WaterService.getBeverage('custom_protein_shake')!;
      expect((b.name, b.hydrationPercent), ('Mine', 75));
    });

    test('a profile that has been saved is not replaced by the file\'s', () async {
      await WaterService.saveProfile(WaterService.getProfile()
          .copyWith(customGoalMl: 3100, useCustomGoal: true, fluidCeilingMl: 1500));

      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': const [],
          'containers': const [],
          'profile': HydrationProfile(id: 'profile').toJson(),
        },
      });

      expect(WaterService.getProfile().fluidCeilingMl, 1500,
          reason: 'a prescribed fluid limit must not be lifted by an older or '
              'blank backup');
      expect(WaterService.getProfile().customGoalMl, 3100);
    });

    test('a section that is not the shape it should be changes nothing and throws nothing',
        () async {
      await WaterService.addCustomBeverage(shake());
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {'beverages': 'many', 'containers': 7, 'profile': 'none'},
      });
      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull);
    });

    test('an alcoholic drink in a file is left out', () async {
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': [
            {'id': 'custom_beer', 'name': 'Beer', 'hydrationPercent': -50, 'isAlcoholic': true},
          ],
          'containers': const [],
        },
      });
      expect(WaterService.getBeverage('custom_beer'), isNull);
    });

    test('a cup read from a file is held to what the cup creator allows', () async {
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': const [],
          'containers': [
            {
              'id': 'long_cup',
              'name': 'x' * 200,
              'capacityMl': 300,
              'emoji': '🥤' * 40,
              'colorHex': 'not a colour',
            },
          ],
        },
      });
      final c = WaterService.getContainer('long_cup')!;
      expect(c.name.runes.length, 50);
      expect(c.emoji.runes.length, 8);
      expect(c.colorHex, isNull, reason: 'an invalid colour is none, not kept');
    });

    test('a profile in a file has the figures outside a believable range dropped', () async {
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': const [],
          'containers': const [],
          'profile': {
            'id': 'profile',
            'weightKg': -5,
            'customGoalMl': 900000,
            'fluidCeilingMl': 3,
            'age': 400,
            'activityLevel': 99,
            'useCustomGoal': true,
          },
        },
      });
      final p = WaterService.getProfile();
      expect(p.weightKg, isNull);
      expect(p.customGoalMl, 2500, reason: 'back to the default, not 900,000');
      expect(p.fluidCeilingMl, isNull, reason: 'a limit of 3 ml is not a limit');
      expect(p.age, isNull);
    });

    test('an enum index outside its list does not stop the rest of the profile coming in',
        () async {
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': const [],
          'containers': const [],
          'profile': {
            'id': 'profile',
            'customGoalMl': 3100,
            'useCustomGoal': true,
            'activityLevel': 99,
            'climate': -3,
          },
        },
      });
      expect(WaterService.getProfile().customGoalMl, 3100,
          reason: 'an index that would throw on read is dropped, not the whole profile');
    });

    test('a believable profile comes through as it is', () async {
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': const [],
          'containers': const [],
          'profile': {
            'id': 'profile',
            'weightKg': 71.5,
            'customGoalMl': 3100,
            'useCustomGoal': true,
            'fluidCeilingMl': 1500,
          },
        },
      });
      final p = WaterService.getProfile();
      expect((p.weightKg, p.customGoalMl, p.fluidCeilingMl), (71.5, 3100, 1500));
    });

    test('a drink read from a file is held to the limits of one made on the screen',
        () async {
      await CleanStorageService.importData({
        'version': 9,
        'waterSetup': {
          'beverages': [
            {
              'id': 'custom_greedy',
              'name': 'Greedy',
              'hydrationPercent': 5000,
              'hasCaffeine': true,
              'caffeinePerMl': 99999,
            },
          ],
          'containers': [
            {'id': 'huge', 'name': 'Huge', 'capacityMl': 5000000},
          ],
        },
      });

      final b = WaterService.getBeverage('custom_greedy')!;
      expect(b.hydrationPercent, 100, reason: 'it would inflate every total it is logged against');
      expect(b.caffeinePerMl, CustomDrink.maxCaffeineMg);
      expect(WaterService.getContainer('huge'), isNull);
    });

    test('"Delete all data" removes them too, and the profile with them', () async {
      await WaterService.addCustomBeverage(shake());
      await WaterService.addCustomContainer(mug);
      await WaterService.saveProfile(WaterService.getProfile().copyWith(
          weightKg: 80, isPregnant: true, customGoalMl: 3000, useCustomGoal: true));

      await CleanStorageService.clearAllPersistentData();

      expect(WaterService.getCustomBeverages(), isEmpty);
      expect(WaterService.getAllContainers().any((c) => c.id == 'travel_mug'), isFalse);
      expect(await database.waterDao.getAllBeverages(), isEmpty);
      expect(await database.waterDao.getAllContainers(), isEmpty);
      expect(await database.waterDao.getProfile(), isNull,
          reason: 'weight and pregnancy are health data, and it came back on the '
              'next start because the service reads it from this table');
      await restart();
      expect(WaterService.getProfile().weightKg, isNull);
      expect(WaterService.getProfile().isPregnant, isFalse);
      expect(WaterService.getProfile().useCustomGoal, isFalse);
    });
  });
}
