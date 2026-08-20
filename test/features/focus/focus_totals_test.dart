import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/custom_tag.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';

/// The two screens have to agree about the same day.
///
/// `docs/ui-audit.md` recorded the symptom without the cause: *"focus header says
/// '1 day streak' while its own Statistics screen says '0 Day Streak'"*. The cause
/// is that two components computed "focus time" from the same session list using
/// different rules — `FocusService.todayMinutes` counted only completed sessions,
/// `StatsService.buildFromSessions` counted every session including abandoned
/// ones. Nothing forced them to agree, so they drifted, and the user saw both
/// numbers at once.
void main() {
  // SharedPreferences (used by the tag test) needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 3, 14, 13, 0);

  FocusSession session({
    required int minutes,
    required bool completed,
    DateTime? at,
  }) =>
      FocusSession(
        id: 'session-$minutes-$completed',
        startedAt: at ?? today,
        completedAt: completed ? (at ?? today).add(Duration(minutes: minutes)) : null,
        targetMinutes: 25,
        actualMinutes: minutes,
        wasCompleted: completed,
        wasAbandoned: !completed,
        activityType: FocusActivityType.work,
        plantType: PlantType.tree,
      );

  group('one definition of focus time', () {
    test('completed minutes only, and abandoned time is kept separately', () {
      // 25 minutes finished, 5 minutes abandoned.
      final sessions = [
        session(minutes: 25, completed: true),
        session(minutes: 5, completed: false),
      ];

      final stats = StatsService();
      stats.resetForTesting();
      stats.buildFromSessions(sessions);

      final day = stats.dailyStats.single;
      expect(day.totalMinutes, 25,
          reason: 'BEFORE THE FIX this was 30 — the abandoned 5 minutes were '
              'counted as focus time here but not on the Focus screen, so the '
              'same day showed two different totals');
      expect(day.abandonedMinutes, 5,
          reason: 'the abandoned time is not discarded, just not called focus');
      expect(day.sessionsCount, 2);
      expect(day.completedSessions, 1);
      expect(day.abandonedSessions, 1);
    });

    test('the activity breakdown sums to the day total', () {
      // If the breakdown counted abandoned minutes while the total did not, the
      // Statistics screen's own pie would not add up to its own headline.
      final sessions = [
        session(minutes: 25, completed: true),
        session(minutes: 5, completed: false),
      ];
      final stats = StatsService();
      stats.resetForTesting();
      stats.buildFromSessions(sessions);

      final day = stats.dailyStats.single;
      final breakdown =
          day.minutesByActivity.values.fold<int>(0, (a, b) => a + b);
      expect(breakdown, day.totalMinutes);
    });

    test('an all-abandoned day reports zero focus time, not zero sessions', () {
      final stats = StatsService();
      stats.resetForTesting();
      stats.buildFromSessions([session(minutes: 7, completed: false)]);

      final day = stats.dailyStats.single;
      expect(day.totalMinutes, 0);
      expect(day.abandonedMinutes, 7);
      expect(day.sessionsCount, 1, reason: 'the attempt still happened');
      expect(day.hasData, isTrue,
          reason: 'a day with an abandoned session is not an empty day');
    });
  });

  group('a deleted tag stops collecting minutes', () {
    test('the breakdown skips tags that no longer exist', () async {
      // `TagService.deleteTag` scrubs its own session→tag map, but the `tagIds`
      // copied onto each FocusSession is history and stays. Nothing filtered it, so
      // the Statistics tag breakdown rendered a deleted tag's raw id as a row and
      // kept attributing minutes to it.
      SharedPreferences.setMockInitialValues({});
      // TagService.createTag persists, and CleanStorageService writes through to
      // Drift — which needs the in-memory database, not path_provider.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      addTearDown(db.close);
      CleanStorageService.resetForTesting();
      final tags = TagService();
      tags.resetForTesting();
      await tags.createTag(
          name: 'Deep Work', colorValue: FocusTag.availableColors.first.toARGB32());
      final created = tags.tags.firstWhere((t) => t.name == 'Deep Work');

      final tagged = FocusSession(
        id: 's1',
        startedAt: today,
        completedAt: today.add(const Duration(minutes: 25)),
        targetMinutes: 25,
        actualMinutes: 25,
        wasCompleted: true,
        activityType: FocusActivityType.work,
        plantType: PlantType.tree,
        tagIds: [created.id],
      );

      final stats = StatsService();
      stats.resetForTesting();
      stats.buildFromSessions([tagged]);
      expect(stats.dailyStats.single.minutesByTag[created.id], 25,
          reason: 'sanity: a live tag is attributed');

      await tags.deleteTag(created.id);
      stats.resetForTesting();
      stats.buildFromSessions([tagged]);

      expect(stats.dailyStats.single.minutesByTag, isEmpty,
          reason: 'a tag the user deleted must not keep appearing in the '
              'breakdown, and the session history must not be rewritten to '
              'achieve that');
    });
  });

  group('session length bounds', () {
    tearDown(() => FocusService().resetForTesting());

    test('setDuration clamps instead of accepting anything', () {
      // The [1, 600] range lived only in the custom-duration sheet's text
      // validation, so every other caller — and any corrupt persisted value —
      // bypassed it. Zero is the dangerous one: `progress` divides by the phase
      // length.
      final focus = FocusService();
      focus.resetForTesting();

      focus.setDuration(0);
      expect(focus.selectedMinutes, kMinSessionMinutes);
      expect(focus.progress.isNaN, isFalse);

      focus.setDuration(-5);
      expect(focus.selectedMinutes, kMinSessionMinutes);

      focus.setDuration(100000);
      expect(focus.selectedMinutes, kMaxSessionMinutes);

      focus.setDuration(50);
      expect(focus.selectedMinutes, 50, reason: 'a valid value is untouched');
    });
  });
}
