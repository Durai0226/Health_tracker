/// Sleep debt must only count nights that were actually logged.
///
/// `sleepDebtMinutes()` was `targetMinutes * 7 - slept`, summed over all seven
/// days of the weekly trend. A day with no session contributes
/// `asleepMinutes == 0`, so every un-logged night quietly added a full night's
/// target to the total — someone who logged three good nights was told they
/// were dozens of hours behind.
///
/// That is a fabricated clinical figure in a health app, the same class of
/// defect as reporting 100% adherence against zero doses.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.init();
  });

  tearDown(() async => db.close());

  /// Logs [nights] nights of [minutes] each, starting from TODAY and going
  /// back.
  ///
  /// `getWeeklyTrend()` spans `today-6 … today` INCLUSIVE, so counting from 1
  /// pushes the oldest night outside the window. Worth knowing: today is one of
  /// the seven, and it is a gap until tonight is logged — under the old formula
  /// that single gap charged a full night's target as debt, every day, to
  /// everyone. That is most of where a spurious "12h under" comes from.
  Future<void> logNights({required int nights, required int minutes}) async {
    final now = DateTime.now();
    for (var i = 0; i < nights; i++) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final wake = DateTime(day.year, day.month, day.day, 7, 0);
      await SleepService.logManualSession(
        bedtime: wake.subtract(Duration(minutes: minutes)),
        wakeTime: wake,
        quality: 4,
      );
    }
  }

  test('no logged nights means no debt, not a full week of it', () async {
    expect(SleepService.sleepDebtMinutes(), 0,
        reason: 'With nothing logged the old maths reported target x 7 — a '
            'fabricated ~56h deficit for a user who simply had not logged.');
  });

  /// The debt the honest formula would give, computed from the trend itself.
  ///
  /// Asserted as a RELATIONSHIP rather than a hand-computed number: logging
  /// N minutes in bed does not mean N minutes asleep (the session applies an
  /// efficiency deduction), so guessing the arithmetic here would only test my
  /// own assumption. The property that matters is the denominator.
  int expectedDebt() {
    final logged =
        SleepService.getWeeklyTrend().where((d) => d.hasData).toList();
    if (logged.isEmpty) return 0;
    final slept = logged.fold<int>(0, (a, d) => a + d.asleepMinutes);
    return SleepService.getSchedule().targetMinutes * logged.length - slept;
  }

  test('the deficit is measured only against logged nights', () async {
    final target = SleepService.getSchedule().targetMinutes;
    await logNights(nights: 2, minutes: target);

    expect(SleepService.loggedNightsThisWeek(), 2);
    expect(
      SleepService.sleepDebtMinutes(),
      expectedDebt(),
      reason: 'The debt must be target x LOGGED nights minus what was slept. '
          'The old formula used x 7 regardless, charging the five un-logged '
          'nights at full target each.',
    );

    // The decisive check: the old formula and the new one must differ here,
    // and by exactly the five un-logged nights. If they agree, this test is
    // not measuring anything.
    final oldFormula = target * 7 -
        SleepService.getWeeklyTrend()
            .fold<int>(0, (a, d) => a + d.asleepMinutes);
    expect(
      oldFormula - SleepService.sleepDebtMinutes(),
      target * 5,
      reason: 'Five un-logged nights x a full target is the phantom debt the '
          'old formula invented.',
    );
  });

  test('a full week uses all seven nights', () async {
    final target = SleepService.getSchedule().targetMinutes;
    await logNights(nights: 7, minutes: target - 15);

    expect(SleepService.loggedNightsThisWeek(), 7);
    expect(SleepService.sleepDebtMinutes(), expectedDebt());
    // With every night logged the two formulas agree — the fix changes only
    // the incomplete-week case, it does not move the complete-week number.
    final oldFormula = target * 7 -
        SleepService.getWeeklyTrend()
            .fold<int>(0, (a, d) => a + d.asleepMinutes);
    expect(SleepService.sleepDebtMinutes(), oldFormula);
  });
}
