/// Sleep history past the last five weeks, and editing a night.
///
/// The Sleep screen holds about the last 35 nights in memory; anything older was
/// in the database and nowhere on screen. And a night, once logged, could only be
/// deleted — a wrong bedtime meant deleting the night and typing it again.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_session.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final now = DateTime(2026, 6, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  String key(int daysAgo) {
    final d = DateTime(now.year, now.month, now.day - daysAgo);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// A night that ended [daysAgo] days ago at 07:00, 480 minutes in bed.
  Future<void> insertNight(int daysAgo,
      {SleepSource source = SleepSource.healthConnect, String? id, bool deleted = false}) async {
    final wake = DateTime(now.year, now.month, now.day - daysAgo, 7);
    await database.sleepDao.upsert(db.SleepSessionsCompanion(
      id: Value(id ?? 'n$daysAgo'),
      dateKey: Value(key(daysAgo)),
      bedtime: Value(wake.subtract(const Duration(minutes: 480))),
      wakeTime: Value(wake),
      inBedMinutes: const Value(480),
      asleepMinutes: const Value(450),
      sourceIndex: Value(source.index),
      createdAt: Value(wake),
      updatedAt: Value(wake),
      deletedAt: Value(deleted ? wake : null),
    ));
  }

  Future<T> pinned<T>(Future<T> Function() body) => withClock(Clock.fixed(now), body);

  group('earlier nights', () {
    test('the in-memory window stops at about five weeks; the rest is one call away',
        () async {
      await pinned(() async {
        for (var i = 0; i < 80; i++) {
          await insertNight(i);
        }
        await SleepService.reloadFromDb();
        final held = SleepService.getAllSessions();
        expect(held.length, lessThan(80), reason: 'the premise: not everything is held');
        final oldestHeld = held.last.wakeTime;

        final older = await SleepService.earlierNights(before: oldestHeld, limit: 30);

        expect(older, hasLength(30));
        expect(older.first.wakeTime.isBefore(oldestHeld), isTrue);
        expect(older.first.wakeTime.isAfter(older.last.wakeTime), isTrue,
            reason: 'newest first, like the list above it');
      });
    });

    test('and the next page picks up where the last stopped', () async {
      await pinned(() async {
        for (var i = 0; i < 100; i++) {
          await insertNight(i);
        }
        await SleepService.reloadFromDb();
        var cursor = SleepService.getAllSessions().last.wakeTime;
        final seen = <String>{};
        for (var page = 0; page < 10; page++) {
          final batch = await SleepService.earlierNights(before: cursor, limit: 30);
          if (batch.isEmpty) break;
          for (final s in batch) {
            expect(seen.add(s.id), isTrue, reason: '${s.id} appeared twice');
          }
          cursor = batch.last.wakeTime;
        }
        final held = SleepService.getAllSessions().map((s) => s.id).toSet();
        expect(seen.length + held.length, 100, reason: 'every night, once');
        expect(seen.intersection(held), isEmpty);
      });
    });

    test('nothing earlier: empty, and hasEarlier says so', () async {
      await pinned(() async {
        for (var i = 0; i < 10; i++) {
          await insertNight(i);
        }
        await SleepService.reloadFromDb();
        final oldest = SleepService.getAllSessions().last.wakeTime;
        expect(await SleepService.earlierNights(before: oldest), isEmpty);
        expect(await SleepService.hasEarlier(before: oldest), isFalse);
      });
    });

    test('hasEarlier is true when there is an older night', () async {
      await pinned(() async {
        for (var i = 0; i < 60; i++) {
          await insertNight(i);
        }
        await SleepService.reloadFromDb();
        final oldest = SleepService.getAllSessions().last.wakeTime;
        expect(await SleepService.hasEarlier(before: oldest), isTrue);
      });
    });

    test('a deleted night is not in it', () async {
      await pinned(() async {
        for (var i = 0; i < 60; i++) {
          await insertNight(i, deleted: i == 45);
        }
        await SleepService.reloadFromDb();
        final oldest = SleepService.getAllSessions().last.wakeTime;
        final older = await SleepService.earlierNights(before: oldest, limit: 100);
        expect(older.map((s) => s.id), isNot(contains('n45')));
      });
    });

    test('two rows for one date are one night, the winner', () async {
      await pinned(() async {
        for (var i = 0; i < 60; i++) {
          await insertNight(i);
        }
        // A hand-logged night and a device night for the same old date.
        await insertNight(50, source: SleepSource.manual, id: 'manual-50');
        await SleepService.reloadFromDb();
        final oldest = SleepService.getAllSessions().last.wakeTime;
        final older = await SleepService.earlierNights(before: oldest, limit: 100);
        expect(older.where((s) => s.dateKey == key(50)), hasLength(1));
      });
    });

    test('the limit is a limit', () async {
      await pinned(() async {
        for (var i = 0; i < 100; i++) {
          await insertNight(i);
        }
        await SleepService.reloadFromDb();
        final oldest = SleepService.getAllSessions().last.wakeTime;
        expect(await SleepService.earlierNights(before: oldest, limit: 5), hasLength(5));
      });
    });
  });

  group('editing a night you logged', () {
    Future<SleepSession> logged({int daysAgo = 1}) async {
      final wake = DateTime(now.year, now.month, now.day - daysAgo, 7);
      return SleepService.logManualSession(
        bedtime: wake.subtract(const Duration(hours: 8)),
        wakeTime: wake,
        quality: 3,
        note: 'warm room',
      );
    }

    test('changes the bedtime and keeps the night: same row, same creation', () async {
      // Logged two days before it is edited, so "kept" and "re-stamped" differ.
      final before = await withClock(
          Clock.fixed(now.subtract(const Duration(days: 2))), () => logged(daysAgo: 1));
      await pinned(() async {
        final wake = before.wakeTime;
        final r = await SleepService.editManualNight(
          before,
          bedtime: wake.subtract(const Duration(hours: 7)),
          wakeTime: wake,
          quality: 3,
          note: 'warm room',
        );
        expect(r.problem, isNull);
        final after = r.edit!.after;
        expect(after.id, before.id, reason: 'an edit of the night, not a second night');
        expect(after.createdAt, before.createdAt,
            reason: 'when it was first logged does not change when it is corrected');
        expect(after.updatedAt.isAfter(before.updatedAt), isTrue);
        expect(after.inBedMinutes, 7 * 60);
        expect(after.asleepMinutes, lessThan(before.asleepMinutes));
        expect(SleepService.getAllSessions(), hasLength(1));
      });
    });

    test('is on disk, once', () async {
      await pinned(() async {
        final before = await logged();
        await SleepService.editManualNight(before,
            bedtime: before.bedtime.add(const Duration(minutes: 30)),
            wakeTime: before.wakeTime,
            quality: 5);
        final rows = await database.sleepDao.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.inBedMinutes, 7 * 60 + 30);
      });
    });

    test('the rating and the note can change', () async {
      await pinned(() async {
        final before = await logged();
        final r = await SleepService.editManualNight(before,
            bedtime: before.bedtime,
            wakeTime: before.wakeTime,
            quality: 5,
            note: 'much better');
        expect(r.edit!.after.qualityIndex, 5);
        expect(r.edit!.after.note, 'much better');
      });
    });

    test('moving it to another date moves the night, leaving none behind', () async {
      await pinned(() async {
        final before = await logged(daysAgo: 2);
        final newWake = DateTime(now.year, now.month, now.day - 3, 7);
        final r = await SleepService.editManualNight(before,
            bedtime: newWake.subtract(const Duration(hours: 8)),
            wakeTime: newWake,
            quality: 3);
        expect(r.problem, isNull);
        expect(r.edit!.after.dateKey, key(3));
        final all = SleepService.getAllSessions();
        expect(all, hasLength(1));
        expect(all.single.dateKey, key(3));
        expect((await database.sleepDao.getAll()), hasLength(1));
      });
    });

    test('not onto a date that already has a night', () async {
      await pinned(() async {
        await insertNight(3);
        await SleepService.reloadFromDb();
        final before = await logged(daysAgo: 2);
        final newWake = DateTime(now.year, now.month, now.day - 3, 7);
        final r = await SleepService.editManualNight(before,
            bedtime: newWake.subtract(const Duration(hours: 8)),
            wakeTime: newWake,
            quality: 3);
        expect(r.edit, isNull);
        expect(r.problem, contains('already'));
        expect(SleepService.getAllSessions(), hasLength(2),
            reason: 'both nights are still there, untouched');
      });
    });

    test('a night a device recorded is not editable', () async {
      await pinned(() async {
        await insertNight(1);
        await SleepService.reloadFromDb();
        final measured = SleepService.getAllSessions().single;
        final r = await SleepService.editManualNight(measured,
            bedtime: measured.bedtime,
            wakeTime: measured.wakeTime,
            quality: 5);
        expect(r.edit, isNull);
        expect(r.problem, contains('health app'));
      });
    });

    test('an old night, outside what is held, is edited in place', () async {
      await pinned(() async {
        for (var i = 0; i < 80; i++) {
          await insertNight(i, source: i == 60 ? SleepSource.manual : SleepSource.healthConnect);
        }
        await SleepService.reloadFromDb();
        final oldest = SleepService.getAllSessions().last.wakeTime;
        final old = (await SleepService.earlierNights(before: oldest, limit: 100))
            .firstWhere((s) => s.dateKey == key(60));
        expect(old.source, SleepSource.manual);

        final r = await SleepService.editManualNight(old,
            bedtime: old.bedtime.add(const Duration(minutes: 60)),
            wakeTime: old.wakeTime,
            quality: 4);

        expect(r.problem, isNull);
        final rows = (await database.sleepDao.getAll()).where((x) => x.dateKey == key(60));
        expect(rows, hasLength(1), reason: 'edited in place, not copied');
        expect(rows.single.inBedMinutes, 7 * 60);
      });
    });

    test('Undo puts the night back as it was', () async {
      await pinned(() async {
        final before = await logged();
        final r = await SleepService.editManualNight(before,
            bedtime: before.bedtime.add(const Duration(hours: 1)),
            wakeTime: before.wakeTime,
            quality: 1,
            note: 'changed');
        await SleepService.undoEdit(r.edit!);

        final back = SleepService.getAllSessions().single;
        expect(back.inBedMinutes, before.inBedMinutes);
        expect(back.qualityIndex, before.qualityIndex);
        expect(back.note, before.note);
        final row = (await database.sleepDao.getAll()).single;
        expect(row.inBedMinutes, before.inBedMinutes);
      });
    });

    test('Undo of a move puts it on its old date and clears the new one', () async {
      await pinned(() async {
        final before = await logged(daysAgo: 2);
        final newWake = DateTime(now.year, now.month, now.day - 4, 7);
        final r = await SleepService.editManualNight(before,
            bedtime: newWake.subtract(const Duration(hours: 8)),
            wakeTime: newWake,
            quality: 3);
        await SleepService.undoEdit(r.edit!);

        final all = SleepService.getAllSessions();
        expect(all, hasLength(1));
        expect(all.single.dateKey, key(2));
        expect(all.single.id, before.id);
      });
    });
  });
}
