import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// Session history: the move off a capped preference blob, and what it fixed.
///
/// The blob was written with `_sessions.take(100)`, so the 101st session
/// destroyed the oldest on the next save — about fifty days at two sessions a
/// day, silently shrinking, and eroding the history `_checkAndUpdateStreak`
/// recomputes from. Worse, `importSessionsJson` merged a backup into memory and
/// THEN wrote 100 of them, so restoring a 300-session backup kept 100 and told
/// the user it had succeeded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final focus = FocusService();
  final t0 = DateTime(2026, 3, 15, 10, 0);

  /// A legacy preference-blob session, as written before v15.
  Map<String, dynamic> legacy(int i) => {
        'id': 'legacy_$i',
        'startedAt': t0.subtract(Duration(days: i)).toIso8601String(),
        'completedAt': t0
            .subtract(Duration(days: i))
            .add(const Duration(minutes: 25))
            .toIso8601String(),
        'targetMinutes': 25,
        'actualMinutes': 25,
        'wasCompleted': true,
        'wasAbandoned': false,
        'activityType': 0,
        'plantType': 0,
        'note': 'session $i',
        'tagIds': ['t1'],
      };

  Future<void> bootWith(List<Map<String, dynamic>> sessions) async {
    await CleanStorageService.setAppPreference('focusSessions', sessions);
    await focus.init();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    focus.resetForTesting();
    await db.close();
  });

  group('the v15 migration', () {
    test('moves every legacy session into the table', () async {
      await bootWith([for (var i = 0; i < 250; i++) legacy(i)]);

      expect(focus.sessions, hasLength(250),
          reason: 'all of them — the cap is the defect being fixed');
      expect(await db.focusDao.countAll(), 250);
    });

    test('preserves every field, including the newest two', () async {
      await bootWith([
        {
          ...legacy(0),
          'quality': 1,
          'distractions': [
            {'appId': 'instagram', 'atSecond': 120}
          ],
        }
      ]);

      final s = focus.sessions.single;
      expect(s.id, 'legacy_0');
      expect(s.note, 'session 0');
      expect(s.tagIds, ['t1']);
      expect(s.targetMinutes, 25);
      expect(s.actualMinutes, 25);
      expect(s.wasCompleted, isTrue);
      expect(s.quality, 1);
      expect(s.distractions.single.appId, 'instagram');
      expect(s.distractions.single.atSecond, 120);
      expect(s.completedAt, isNotNull);
    });

    test('drops the blob only AFTER recording that it succeeded', () async {
      await bootWith([legacy(0)]);
      expect(
          CleanStorageService.getAppPreference('focusSessionsMigratedToDrift'),
          isTrue);
      expect(CleanStorageService.getAppPreference('focusSessions'), isNull,
          reason: 'the blob is gone, so nothing can read a stale copy');
    });

    test('is idempotent — a second boot does not duplicate', () async {
      await bootWith([for (var i = 0; i < 5; i++) legacy(i)]);
      expect(await db.focusDao.countAll(), 5);

      focus.resetForTesting();
      await focus.init();
      expect(await db.focusDao.countAll(), 5,
          reason: 'upsert by primary key, so re-running is a no-op');
      expect(focus.sessions, hasLength(5));
    });

    test('one unreadable record does not cost the user the others', () async {
      await bootWith([
        legacy(0),
        {'id': 'broken', 'startedAt': 'not a date', 'activityType': 'nonsense'},
        legacy(2),
      ]);
      expect(focus.sessions.length, greaterThanOrEqualTo(2),
          reason: 'a single bad row must not take the history down');
      expect(focus.sessions.map((s) => s.id), contains('legacy_0'));
      expect(focus.sessions.map((s) => s.id), contains('legacy_2'));
    });

    test('a fresh install records itself as migrated and stays empty', () async {
      await focus.init();
      expect(focus.sessions, isEmpty);
      expect(
          CleanStorageService.getAppPreference('focusSessionsMigratedToDrift'),
          isTrue,
          reason: 'so it never looks for a blob again');
    });
  });

  group('there is no cap any more', () {
    test('history past 100 survives a restart', () async {
      await bootWith([for (var i = 0; i < 300; i++) legacy(i)]);

      // The restart: forget everything in memory, load from the table.
      focus.resetForTesting();
      await focus.init();
      expect(focus.sessions, hasLength(300),
          reason: 'this is the whole point of the table');
    });

    test('restoring a 300-session backup keeps 300', () async {
      // The defect that made the cap worse than the cap: import merged into
      // memory and then `_saveData()` wrote `.take(100)`, so a restore silently
      // discarded two thirds of the backup and reported success.
      await focus.init();
      await focus.importSessionsJson([for (var i = 0; i < 300; i++) legacy(i)]);
      expect(focus.sessions, hasLength(300));

      focus.resetForTesting();
      await focus.init();
      expect(focus.sessions, hasLength(300),
          reason: 'and it is still 300 after a restart, not 100');
    });

    test('a restore merges rather than replaces', () async {
      await bootWith([legacy(0)]);
      await focus.importSessionsJson([legacy(1), legacy(2)]);
      expect(focus.sessions.map((s) => s.id),
          containsAll(['legacy_0', 'legacy_1', 'legacy_2']));
    });

    test('a restore does not duplicate ids it already has', () async {
      await bootWith([legacy(0)]);
      await focus.importSessionsJson([legacy(0), legacy(1)]);
      expect(focus.sessions, hasLength(2));
      expect(await db.focusDao.countAll(), 2);
    });

    test('history stays newest-first', () async {
      await bootWith([for (var i = 0; i < 10; i++) legacy(i)]);
      for (var i = 0; i < focus.sessions.length - 1; i++) {
        expect(
            focus.sessions[i].startedAt.isAfter(focus.sessions[i + 1].startedAt),
            isTrue,
            reason: 'every consumer assumes this — the service prepends');
      }
    });
  });

  group('live sessions reach the table', () {
    test('a completed session is a row', () async {
      await focus.init();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1, seconds: 1))),
          () {
        focus.applyTickFromClockForTesting();
      });
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (await db.focusDao.countAll() == 0 &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(await db.focusDao.countAll(), 1);

      focus.resetForTesting();
      await focus.init();
      expect(focus.sessions.single.wasCompleted, isTrue,
          reason: 'and it comes back after a restart');
    });

    test('an abandoned session is a row too', () async {
      await focus.init();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(25);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 4))), () async {
        await focus.abandonSession();
      });
      expect(await db.focusDao.countAll(), 1);

      focus.resetForTesting();
      await focus.init();
      expect(focus.sessions.single.wasAbandoned, isTrue);
    });

    test('a review written after the fact is persisted', () async {
      await bootWith([legacy(0)]);
      await focus.setLastSessionQuality(2);

      focus.resetForTesting();
      await focus.init();
      expect(focus.sessions.single.quality, 2,
          reason: 'the review is applied to an already-saved row, so it has to '
              'update it rather than only the copy in memory');
    });
  });

  group('the legacy blob is never written again', () {
    test('completing a session does not recreate focusSessions', () async {
      await focus.init();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(1);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 1, seconds: 1))),
          () {
        focus.applyTickFromClockForTesting();
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(CleanStorageService.getAppPreference('focusSessions'), isNull,
          reason: 'two sources of truth for the same history is how the header '
              'and the Statistics screen came to disagree');
    });
  });
}
