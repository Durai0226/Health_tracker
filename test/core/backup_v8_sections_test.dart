/// What the v8 backup added — the heart dashboard, the reminder categories and
/// the haptic settings — and the rules that keep a restore from destroying them.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/haptic_service.dart';
import 'package:tablet_remainder/features/backup/services/health_backup_serializer.dart';
import 'package:tablet_remainder/features/backup/services/reminders_backup_serializer.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final at = DateTime(2026, 3, 1, 9);

  Future<void> boot([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await CleanStorageService.init();
  }

  tearDown(() async => database.close());

  Future<void> heartDay(String id, {int resting = 57}) =>
      database.into(database.biometricDailyData).insert(
            db.BiometricDailyDataCompanion.insert(
              id: id,
              date: DateTime.parse(id),
              restingHr: Value(resting),
              createdAt: at,
              updatedAt: at,
            ),
          );

  Future<void> category(String id, String name) =>
      database.into(database.reminderCategories).insert(
            db.ReminderCategoriesCompanion.insert(
              id: id,
              name: name,
              colorValue: 0xFF9C27B0,
              iconCodePoint: 0xe28d,
            ),
          );

  Future<List<String>> categoryIds() async => [
        for (final c in await database.select(database.reminderCategories).get())
          c.id,
      ]..sort();

  Future<List<String>> heartDayIds() async => [
        for (final r in await database.select(database.biometricDailyData).get())
          r.id,
      ]..sort();

  Map<String, dynamic> storedHaptics(SharedPreferences prefs) =>
      jsonDecode(prefs.getString('haptic_settings')!) as Map<String, dynamic>;

  group('haptic settings', () {
    final mine = {
      'enabled': false,
      'globalIntensity': 2,
      'features': {
        'water': {'enabled': false, 'intensity': 0},
        'focus': {'enabled': true, 'intensity': 2},
      },
    };

    test('are exported as stored', () async {
      await boot({'haptic_settings': jsonEncode(mine)});
      final backup = await CleanStorageService.exportAllData();
      expect(backup['haptics'], mine);
    });

    test('and not at all while they have never been changed', () async {
      await boot();
      final backup = await CleanStorageService.exportAllData();
      expect(backup.containsKey('haptics'), isFalse);
    });

    test('a restore brings them back and applies them now', () async {
      await boot({'haptic_settings': jsonEncode(mine)});
      final backup = await CleanStorageService.exportAllData();

      // Another phone's settings: everything on, at the middle intensity.
      SharedPreferences.setMockInitialValues({
        'haptic_settings': jsonEncode({
          'enabled': true,
          'globalIntensity': 1,
          'features': const {},
        }),
      });
      await HapticService().init();
      expect(HapticService().isEnabled, isTrue);

      await CleanStorageService.importData(backup);

      expect(HapticService().isEnabled, isFalse);
      expect(HapticService().globalIntensity, HapticIntensity.values[2]);
      expect(HapticService().featureEnabled[HapticFeature.water], isFalse);
      expect(HapticService().featureIntensity[HapticFeature.water],
          HapticIntensity.values[0]);
      final stored = storedHaptics(await SharedPreferences.getInstance());
      expect(stored['enabled'], false);
    });

    test('a file without them leaves the current ones alone', () async {
      await boot({'haptic_settings': jsonEncode(mine)});
      await CleanStorageService.importData(<String, dynamic>{'version': 7});
      final stored = storedHaptics(await SharedPreferences.getInstance());
      expect(stored, mine);
    });

    test('a value out of range, or a feature this build does not have, is dropped',
        () async {
      await boot();
      await HapticService.importJson({
        'enabled': 'yes',
        'globalIntensity': 99,
        'features': {
          'water': {'enabled': false, 'intensity': -1},
          'focus': {'enabled': true, 'intensity': 2},
          'teleport': {'enabled': true, 'intensity': 1},
        },
      });
      final stored = storedHaptics(await SharedPreferences.getInstance());
      expect(stored.containsKey('enabled'), isFalse);
      expect(stored.containsKey('globalIntensity'), isFalse);
      final features = stored['features'] as Map;
      expect(features.keys, unorderedEquals(['water', 'focus']));
      expect(features['water'], {'enabled': false},
          reason: 'its intensity was out of range, its switch was not');
      expect(features['focus'], {'enabled': true, 'intensity': 2});
      // And what is stored loads without complaint.
      await HapticService().init();
      expect(HapticService().featureEnabled[HapticFeature.water], isFalse);
    });

    test('a number where a switch should be is not a switch', () async {
      await boot();
      await HapticService.importJson({
        'features': {
          'water': {'enabled': 1, 'intensity': '2'},
        },
      });
      final stored = storedHaptics(await SharedPreferences.getInstance());
      expect((stored['features'] as Map)['water'], isEmpty);
    });
  });

  group('reminder categories', () {
    test('a clearing restore replaces yours and never touches the built-in three',
        () async {
      await boot(); // seeds the three built-in categories
      await category('gym', 'Gym');
      final backup = await CleanStorageService.exportAllData();

      // Made after the backup: nothing can put it back.
      await category('later', 'Added after the backup');
      await CleanStorageService.restoreBackup(backup, clearExisting: true);

      expect(await categoryIds(), ['gym', 'health', 'personal', 'work'],
          reason: 'an overwrite that keeps the newer row is a merge in disguise');
    });

    test('a built-in category survives even a file that lacks it', () async {
      await boot();
      await category('gym', 'Gym');
      final backup = await CleanStorageService.exportAllData();
      (backup[RemindersBackupSerializer.categoriesKey] as List)
          .removeWhere((c) => (c as Map)['id'] == 'personal');

      await CleanStorageService.restoreBackup(backup, clearExisting: true);

      expect(await categoryIds(), contains('personal'),
          reason: 'the built-in ones are only seeded into an empty table, so '
              'one lost here would not come back');
    });

    test('a file from before they were in backups keeps yours', () async {
      await boot();
      await category('gym', 'Gym');
      final backup = await CleanStorageService.exportAllData()
        ..remove(RemindersBackupSerializer.categoriesKey);
      backup['version'] = 7;

      await CleanStorageService.restoreBackup(backup, clearExisting: true);

      expect(await categoryIds(), contains('gym'),
          reason: 'an absent section means "unknown", never "delete"');
    });

    test('a restore merges by id: the file\'s name wins, the rest stay', () async {
      await boot();
      await category('gym', 'Gym');
      final backup = await CleanStorageService.exportAllData();
      await (database.update(database.reminderCategories)
            ..where((t) => t.id.equals('gym')))
          .write(const db.ReminderCategoriesCompanion(name: Value('Renamed')));
      await category('later', 'Later');

      await CleanStorageService.importData(backup);

      final rows = await database.select(database.reminderCategories).get();
      expect(rows.firstWhere((r) => r.id == 'gym').name, 'Gym');
      expect(rows.map((r) => r.id), contains('later'));
    });

    test('a row that cannot be read is skipped, the rest are restored', () async {
      await boot();
      await RemindersBackupSerializer.importJson({
        RemindersBackupSerializer.categoriesKey: [
          {'id': 12345, 'name': null},
          {'id': 'gym', 'name': 'Gym', 'colorValue': 1, 'iconCodePoint': 2, 'isDefault': false},
        ],
      });
      expect(await categoryIds(), ['gym', 'health', 'personal', 'work']);
    });

    test('Delete all data removes yours and keeps the built-in three', () async {
      await boot();
      await category('therapy', 'Therapy');
      await CleanStorageService.clearAllPersistentData();
      expect(await categoryIds(), ['health', 'personal', 'work']);
    });
  });

  group('the heart dashboard', () {
    test('a clearing restore replaces what is there with what the file carries',
        () async {
      await boot();
      await heartDay('2026-03-01');
      final backup = await CleanStorageService.exportAllData();
      await heartDay('2026-03-02');

      await CleanStorageService.restoreBackup(backup, clearExisting: true);

      expect(await heartDayIds(), ['2026-03-01']);
    });

    test('an older file, with none, keeps what is there', () async {
      await boot();
      await heartDay('2026-03-01');
      final backup = await CleanStorageService.exportAllData()
        ..remove(HealthBackupSerializer.biometricsKey);
      backup['version'] = 7;

      await CleanStorageService.restoreBackup(backup, clearExisting: true);

      expect(await heartDayIds(), ['2026-03-01'],
          reason: 'a file with no heart section says nothing about heart data');
    });

    test('a file that carries it empty really empties it', () async {
      await boot();
      await heartDay('2026-03-01');
      final backup = await CleanStorageService.exportAllData();
      await heartDay('2026-03-02');
      (backup[HealthBackupSerializer.biometricsKey] as Map)['days'] = [];

      await CleanStorageService.restoreBackup(backup, clearExisting: true);

      expect(await heartDayIds(), isEmpty,
          reason: 'present-but-empty is a statement; absent is not');
    });

    test('a day that cannot be read is skipped, the rest are restored', () async {
      await boot();
      await heartDay('2026-03-01');
      final backup = await CleanStorageService.exportAllData();
      final days = (backup[HealthBackupSerializer.biometricsKey] as Map)['days'] as List;
      days.insert(0, {'id': 7, 'date': 'not a date'});
      await database.delete(database.biometricDailyData).go();

      await CleanStorageService.importData(backup);

      expect(await heartDayIds(), ['2026-03-01']);
    });

    test('and the dashboard, which holds its days in memory, shows them at once',
        () async {
      await boot();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final today = '${now.year}-${two(now.month)}-${two(now.day)}';
      await heartDay(today);
      final backup = await CleanStorageService.exportAllData();
      await database.delete(database.biometricDailyData).go();
      BiometricsService.clearInMemory();
      expect(BiometricsService.getForDate(now), isNull);

      await CleanStorageService.importData(backup);

      expect(BiometricsService.getForDate(now)?.restingHr, 57,
          reason: 'without a reload the restored days wait for the next launch');
    });

    test('what a restore reads is what the device holds, in memory too', () async {
      await boot();
      await heartDay('2026-03-01', resting: 55);
      final backup = await CleanStorageService.exportAllData();
      await (database.update(database.biometricDailyData)
            ..where((t) => t.id.equals('2026-03-01')))
          .write(const db.BiometricDailyDataCompanion(restingHr: Value(80)));

      await CleanStorageService.importData(backup);

      final row = await (database.select(database.biometricDailyData)
            ..where((t) => t.id.equals('2026-03-01')))
          .getSingle();
      expect(row.restingHr, 55);
    });
  });
}
