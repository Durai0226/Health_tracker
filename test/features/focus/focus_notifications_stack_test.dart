/// Focus notifications that are not a phase of the session no longer replace each
/// other.
///
/// An OS notification id is last-write-wins. Every immediate Focus banner used
/// one id, so a long session that unlocked three plants and two achievements left
/// a single banner on screen — whichever was posted last — and the news of the
/// other four, and of "Session complete", was gone before anyone saw it.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_achievement.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;
  late RecordingFocusSessionAlarm alarm;
  final t0 = DateTime(2026, 3, 14, 13);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    alarm = RecordingFocusSessionAlarm();
    FocusService().alarmForTesting = alarm;
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    // Achievements only exist once the service has loaded them.
    await FocusService().init();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  /// What would be on screen: the last notification posted under each id.
  Map<int, RecordedShow> onScreen() => {for (final s in scheduler.shown) s.id: s};

  group('the ids', () {
    test('one per plant, one per achievement, each inside the reserved block', () {
      final unlocks = [
        for (final p in PlantType.values) NotificationService.focusUnlockId(p.index)
      ];
      final achievements = [
        for (final a in AchievementType.values)
          NotificationService.focusAchievementId(a.index)
      ];
      expect(unlocks.toSet(), hasLength(PlantType.values.length));
      expect(achievements.toSet(), hasLength(AchievementType.values.length));
      for (final id in [...unlocks, ...achievements]) {
        expect(id >= 918_400 && id < 918_500, isTrue, reason: '$id left the block');
      }
    });

    test('there is room for every plant and achievement there is', () {
      // Adding an eleventh... or a sixty-first: this fails before two of them
      // start sharing an id again.
      expect(PlantType.values.length, lessThanOrEqualTo(NotificationService.focusUnlockIdCount));
      expect(AchievementType.values.length,
          lessThanOrEqualTo(NotificationService.focusAchievementIdCount));
    });

    test('the groups do not overlap each other, the session end, or the reminders',
        () {
      final unlocks = {
        for (var i = 0; i < NotificationService.focusUnlockIdCount; i++)
          NotificationService.focusUnlockBaseId + i
      };
      final achievements = {
        for (var i = 0; i < NotificationService.focusAchievementIdCount; i++)
          NotificationService.focusAchievementBaseId + i
      };
      final others = {
        NotificationService.focusDailyReminderId,
        NotificationService.focusStreakReminderId,
        NotificationService.focusSessionEndId,
        NotificationService.focusRelaxationEndId,
      };
      expect(unlocks.intersection(achievements), isEmpty);
      expect(unlocks.intersection(others), isEmpty);
      expect(achievements.intersection(others), isEmpty);
      expect(others, hasLength(4));
    });

    test('an index past the room set aside stays inside the block', () {
      expect(NotificationService.focusUnlockId(-3), NotificationService.focusUnlockBaseId);
      expect(NotificationService.focusUnlockId(9999),
          NotificationService.focusUnlockBaseId + NotificationService.focusUnlockIdCount - 1);
      expect(NotificationService.focusAchievementId(9999),
          NotificationService.focusAchievementBaseId +
              NotificationService.focusAchievementIdCount -
              1);
    });
  });

  group('showing one', () {
    test('goes out under the session id unless it is given one', () async {
      await NotificationService().showFocusNotification(title: 'Break over', body: 'x');
      expect(scheduler.shown.single.id, NotificationService.focusSessionEndId);
    });

    test('and under the id it is given', () async {
      await NotificationService().showFocusNotification(
          title: 'Unlocked', body: 'x', id: NotificationService.focusUnlockId(3));
      expect(scheduler.shown.single.id, NotificationService.focusUnlockId(3));
    });

    test('phases of one session still replace each other, on purpose', () async {
      await NotificationService().showFocusNotification(title: 'Round 1 done', body: 'x');
      await NotificationService().showFocusNotification(title: 'Break over', body: 'x');
      expect(onScreen(), hasLength(1));
      expect(onScreen().values.single.title, 'Break over');
    });
  });

  group('a long session', () {
    test('every plant it unlocks and every achievement it earns is its own notification',
        () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(240);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 240, seconds: 1))),
          () async {
        focus.applyTickFromClockForTesting();
      });
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (focus.isRunning && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(focus.isRunning, isFalse);

      final unlocked =
          scheduler.shown.where((s) => s.title!.startsWith('New Plant Unlocked')).toList();
      final earned =
          scheduler.shown.where((s) => s.title!.startsWith('Achievement Unlocked')).toList();
      // 240 minutes in one go passes the thresholds of sprout (30), sapling (60),
      // tree (120), cactus (150), flowering tree (180) and sunflower (200).
      expect(unlocked.length, greaterThanOrEqualTo(5));
      expect(earned.length, greaterThanOrEqualTo(3));

      final screen = onScreen();
      for (final u in unlocked) {
        expect(screen[u.id], same(u),
            reason: '"${u.title}" was replaced by a later banner and never seen');
      }
      for (final a in earned) {
        expect(screen[a.id], same(a),
            reason: '"${a.title}" was replaced by a later banner and never seen');
      }
      expect({for (final u in unlocked) u.id}, hasLength(unlocked.length));
      expect({for (final a in earned) a.id}, hasLength(earned.length));
    });

    test('none of them takes the session id, so the armed "Session complete" is not wiped',
        () async {
      final focus = FocusService();
      await withClock(Clock.fixed(t0), () async {
        focus.setDuration(240);
        await focus.startSession();
      });
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 240, seconds: 1))),
          () async {
        focus.applyTickFromClockForTesting();
      });
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (focus.isRunning && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      // The completion the OS delivers at the end is armed under the session id.
      expect(alarm.armed.single.id, NotificationService.focusSessionEndId);
      // Everything posted at the same moment goes under another one.
      final others = scheduler.shown.where((s) =>
          s.title!.startsWith('New Plant') || s.title!.startsWith('Achievement'));
      expect(others, isNotEmpty);
      for (final s in others) {
        expect(s.id, isNot(NotificationService.focusSessionEndId),
            reason: '"${s.title}" would replace the session banner');
      }
    });
  });
}
