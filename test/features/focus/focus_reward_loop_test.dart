import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_achievement.dart';
import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// The reward loop: every achievement is earnable, and earning one pays.
///
/// Both halves were broken in the same way — code that exists and does nothing.
/// `perfectWeek` was rendered in the achievements grid with a 0/7 bar that
/// nothing could move, and `CoinsService.addAchievementBonus` had no caller at
/// all, so twenty-four achievements unlocked, fired a notification and paid
/// nothing while a method advertising a payout sat unused in the ledger.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  final focus = FocusService();
  final coins = CoinsService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    coins.resetForTesting();
    TagService().resetForTesting();
    // `resetForTesting` clears the achievement map; only `init()` repopulates it
    // (as `main.dart` does at startup). Without this every `_updateAchievement`
    // is a silent no-op and the assertions below would pass against nothing.
    await focus.init();
  });

  tearDown(() async {
    focus.resetForTesting();
    await db.close();
  });

  Future<void> waitUntil(bool Function() condition, {String? because}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: because ?? 'never became true');
  }

  /// Complete one real session ending at [at].
  Future<void> completeSessionAt(DateTime at) async {
    await withClock(Clock.fixed(at.subtract(const Duration(minutes: 1))),
        () async {
      focus.setDuration(1);
      await focus.startSession();
    });
    await withClock(Clock.fixed(at.add(const Duration(seconds: 1))), () async {
      focus.applyTickFromClockForTesting();
    });
    await waitUntil(() => !focus.isRunning);
  }

  group('every achievement is earnable', () {
    test('no achievement requires more than zero', () {
      // A guard against the class of defect both halves of this file exist for:
      // a requirement of 0 unlocks instantly and meaninglessly, and a negative
      // one is nonsense.
      for (final type in AchievementType.values) {
        expect(type.requiredValue, greaterThan(0), reason: '${type.name}');
      }
    });

    test('every achievement pays something on unlock', () {
      // Derived from the tier rather than a second twenty-four-case switch, so
      // this cannot silently miss a newly added type.
      for (final type in AchievementType.values) {
        expect(type.coinReward, greaterThan(0), reason: '${type.name}');
      }
    });

    test('the tier ordering is monotonic', () {
      expect(AchievementTier.bronze.coinReward,
          lessThan(AchievementTier.silver.coinReward));
      expect(AchievementTier.silver.coinReward,
          lessThan(AchievementTier.gold.coinReward));
      expect(AchievementTier.gold.coinReward,
          lessThan(AchievementTier.platinum.coinReward));
    });

    test('a platinum unlock is worth less than the cheapest tree', () {
      // The sessions are the product. An achievement that buys a tree outright
      // would make the focusing itself feel beside the point.
      expect(AchievementTier.platinum.coinReward, lessThan(200));
    });
  });

  group('perfectWeek', () {
    test('unlocks after seven distinct days with a completed session', () async {
      final sunday = DateTime(2026, 3, 15, 10, 0);
      for (var i = 6; i >= 0; i--) {
        await completeSessionAt(sunday.subtract(Duration(days: i)));
      }
      final earned = focus.achievements[AchievementType.perfectWeek];
      expect(earned, isNotNull);
      expect(earned!.isUnlocked, isTrue,
          reason: 'seven days, seven sessions — this is the definition');
      expect(earned.currentProgress, 7);
    });

    test('six days is not a perfect week', () async {
      final sunday = DateTime(2026, 3, 15, 10, 0);
      for (var i = 6; i >= 2; i--) {
        await completeSessionAt(sunday.subtract(Duration(days: i)));
      }
      final earned = focus.achievements[AchievementType.perfectWeek];
      expect(earned!.isUnlocked, isFalse);
      expect(earned.currentProgress, 5);
    });

    test('two sessions in one day still count as one day', () async {
      // Progress is DAYS, not sessions. Counting sessions would let a single
      // enthusiastic afternoon unlock a week.
      final day = DateTime(2026, 3, 15, 10, 0);
      await completeSessionAt(day);
      await completeSessionAt(day.add(const Duration(hours: 3)));
      expect(focus.achievements[AchievementType.perfectWeek]!.currentProgress, 1);
    });

    test('a forgiven streak day does not make the week perfect', () async {
      // `StreakEngine` forgives one miss per rolling week, so a 7-day STREAK can
      // contain a day with no session at all. Deriving this from the streak would
      // quietly contradict the forgiveness the rest of the feature is careful to
      // be honest about, and call a six-session week perfect.
      final sunday = DateTime(2026, 3, 15, 10, 0);
      for (var i = 6; i >= 0; i--) {
        if (i == 3) continue; // the forgiven day
        await completeSessionAt(sunday.subtract(Duration(days: i)));
      }
      expect(focus.stats.currentStreak, greaterThanOrEqualTo(6),
          reason: 'the streak survives one miss — that is the point of grace');
      expect(focus.achievements[AchievementType.perfectWeek]!.isUnlocked, isFalse,
          reason: 'six days of seven is not a perfect week, however forgiving '
              'the streak is');
    });
  });

  group('unlocking pays', () {
    test('the coin balance rises by the achievement reward', () async {
      // firstSession is bronze and unlocks on the very first completion, so this
      // isolates the achievement bonus from the streak bonus by arithmetic.
      final before = coins.totalCoins;
      await completeSessionAt(DateTime(2026, 3, 15, 10, 0));
      await waitUntil(() => coins.totalCoins > before);

      final unlocked = focus.achievements.values
          .where((a) => a.isUnlocked)
          .map((a) => a.type.coinReward)
          .fold<int>(0, (a, b) => a + b);
      expect(unlocked, greaterThan(0),
          reason: 'a completed session must unlock at least firstSession');

      final ledger = coins.transactions
          .where((t) => t.type == CoinTransactionType.achievementBonus)
          .toList();
      expect(ledger, isNotEmpty,
          reason: 'addAchievementBonus had no caller at all — achievements '
              'unlocked and paid nothing');
      expect(ledger.map((t) => t.amount).fold<int>(0, (a, b) => a + b), unlocked,
          reason: 'every unlock must appear in the ledger exactly once, at its '
              'tier value');
    });

    test('an achievement pays once, not on every later session', () async {
      await completeSessionAt(DateTime(2026, 3, 15, 10, 0));
      await waitUntil(() => coins.transactions.any(
          (t) => t.type == CoinTransactionType.achievementBonus));
      final firstCount = coins.transactions
          .where((t) => t.type == CoinTransactionType.achievementBonus)
          .length;

      await completeSessionAt(DateTime(2026, 3, 15, 14, 0));
      final laterCount = coins.transactions
          .where((t) => t.type == CoinTransactionType.achievementBonus)
          .length;

      final reUnlocked = laterCount - firstCount;
      for (final t in coins.transactions
          .where((t) => t.type == CoinTransactionType.achievementBonus)) {
        expect(t.description, contains('Achievement unlocked'));
      }
      expect(reUnlocked, lessThanOrEqualTo(2),
          reason: 'a second session may unlock genuinely new achievements, but '
              'it must not re-pay ones already earned');
    });
  });

  group('a single setting writes a single key', () {
    test('setSoundVolume(persist: false) writes nothing', () async {
      // Asserted as "unchanged" rather than "absent": `init()` performs a full
      // save of its own, so the key already exists before the drag starts. What
      // matters is that dragging does not touch it.
      final before = CleanStorageService.getAppPreference('focusSoundVolume');
      focus.setSoundVolume(0.9, persist: false);
      expect(focus.soundVolume, 0.9, reason: 'the audio still follows the thumb');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(CleanStorageService.getAppPreference('focusSoundVolume'), before,
          reason: 'the drag must not write — this ran eighteen Drift writes and '
              'a full-history JSON encode per frame');
    });

    test('setSoundVolume persists on commit', () async {
      focus.setSoundVolume(0.75);
      await waitUntil(
          () => CleanStorageService.getAppPreference('focusSoundVolume') != null);
      expect(CleanStorageService.getAppPreference('focusSoundVolume'), 0.75);
    });

    test('committing the volume does not rewrite the session history', () async {
      await completeSessionAt(DateTime(2026, 3, 15, 10, 0));
      // Corrupt the stored history behind the service's back. A single-key
      // preference write must leave it exactly as it is; `_saveData()` would
      // overwrite it from memory and this assertion would fail.
      await CleanStorageService.setAppPreference('focusSessions', const []);
      focus.setSoundVolume(0.4);
      await waitUntil(
          () => CleanStorageService.getAppPreference('focusSoundVolume') == 0.4);
      expect(CleanStorageService.getAppPreference('focusSessions'), isEmpty,
          reason: 'a volume change must touch one key, not eighteen');
    });
  });
}
