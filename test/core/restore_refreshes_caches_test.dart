/// A restored backup shows at once: no restart.
///
/// Sleep, Period, Steps and Heart each keep their days in a static, in-memory
/// copy that is read once at start-up. A restore wrote the database and left
/// those copies alone, so the screens kept showing what was there before until
/// the app was restarted — which both restore screens had to tell the person to
/// do, and which looked exactly like a restore that had failed.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 6, 20, 12);
  final yesterday = DateTime(2026, 6, 19);

  Future<db.AppDatabase> freshDatabase() async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
    await SleepService.resetForTesting();
    await PeriodService.resetForTesting();
    return database;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('what was restored is there at once, in all three', () async {
    await withClock(Clock.fixed(now), () async {
      // ---- a phone with data on it -----------------------------------------
      final source = await freshDatabase();
      await StepService.addManualStepsForDate(yesterday, 4321);
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 18, 23),
        wakeTime: DateTime(2026, 6, 19, 7),
      );
      await PeriodService.logDay(
          PeriodDay(id: PeriodDay.keyFor(yesterday), date: yesterday, flowIndex: 2));
      final backup = await CleanStorageService.exportAllData();
      await source.close();

      // ---- a new phone, nothing on it ---------------------------------------
      final target = await freshDatabase();
      expect(StepService.getDataForDate(yesterday)?.effectiveSteps ?? 0, 0,
          reason: 'the premise: the new phone knows nothing');
      expect(SleepService.getAllSessions(), isEmpty);
      expect(PeriodService.days, isEmpty);

      await CleanStorageService.importData(backup);

      expect(StepService.getDataForDate(yesterday)!.effectiveSteps, 4321,
          reason: 'the steps screen reads this copy, not the database');
      expect(SleepService.getAllSessions(), hasLength(1),
          reason: 'and so does Sleep');
      expect(PeriodService.days.keys, contains(PeriodDay.keyFor(yesterday)),
          reason: 'and so does Period');
      await target.close();
    });
  });

  test('a backup with none of those sections leaves what is there alone', () async {
    await withClock(Clock.fixed(now), () async {
      final database = await freshDatabase();
      await StepService.addManualStepsForDate(yesterday, 4321);

      // An old, partial backup: no sleep, period or steps in it.
      await CleanStorageService.importData(<String, dynamic>{'version': 2});

      expect(StepService.getDataForDate(yesterday)!.effectiveSteps, 4321,
          reason: 'a reload from the database must not lose what is in it');
      await database.close();
    });
  });

  group('and nobody is told to restart', () {
    String code(String path) => File(path)
        .readAsStringSync()
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

    for (final path in const [
      'lib/features/settings/screens/backup_screen.dart',
      'lib/features/backup/presentation/screens/backup_settings_screen.dart',
    ]) {
      test('$path reports a restore without asking for a restart', () {
        final src = code(path);
        expect(RegExp(r'[Rr]estored').hasMatch(src), isTrue,
            reason: 'it must still say that it restored');
        expect(RegExp(r'[Rr]estart').hasMatch(src), isFalse,
            reason: 'the restore reloads what it wrote; there is nothing to restart');
      });
    }
  });
}
