/// `BedtimeGuidance` reaches a screen.
///
/// The engine was fully written, fully tested and completely unreachable — its
/// only reference in `lib/` was its own private constructor. A tested engine
/// nobody calls is not a feature, and the test suite cannot tell the difference,
/// which is why this file asserts the WIRING rather than the arithmetic.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final fixed = DateTime(2026, 8, 12, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await SleepService.init();
  });
  tearDown(() async => db.close());

  /// One logged night, bedtime at [bedHour]:[bedMin], self-rated [quality].
  ///
  /// Goes through `logManualSession` rather than fabricating a row, so the score
  /// is the one the app would really compute — a wiring test that hand-writes
  /// its own `sleepScore` proves the engine works on numbers the app never
  /// produces.
  Future<void> logNight(int daysAgo, int bedHour, int bedMin, int quality) async {
    final wake = DateTime(2026, 8, 12, 7).subtract(Duration(days: daysAgo));
    final bed = DateTime(wake.year, wake.month, wake.day, bedHour, bedMin)
        .subtract(const Duration(days: 1));
    await SleepService.logManualSession(
      bedtime: bed,
      wakeTime: wake,
      quality: quality,
    );
  }

  test('with no history at all it says nothing', () async {
    await withClock(Clock.fixed(fixed), () async {
      expect(SleepService.bedtimeGuidance(), isNull);
    });
  });

  test('a clear pattern surfaces, with its denominator', () async {
    await withClock(Clock.fixed(fixed), () async {
      // Five good nights at 22:30, five poor ones at 00:20 — a 110-minute gap
      // that survives the midnight wraparound.
      for (var i = 0; i < 5; i++) {
        await logNight(i, 22, 30, 5);
      }
      for (var i = 5; i < 10; i++) {
        await logNight(i, 0, 20, 1);
      }

      final g = SleepService.bedtimeGuidance();
      expect(g, isNotNull, reason: 'the engine is not reaching the service');
      expect(g!.bedMinutes, 22 * 60 + 30);
      expect(g.isEarlier, isTrue);
      expect(g.sampleCount, 5,
          reason: 'the card states this as its denominator');
    });
  });

  // A test asserting "unscored nights are excluded, not scored zero" was here
  // and it PASSED — for the wrong reason. `logManualSession` always computes a
  // score, so there is no way to create an unscored night through the API the
  // app actually uses; the fixture it described could not exist, and the test
  // was really measuring some other rejection. `bedtime_guidance_test.dart`
  // covers that rule at the engine level, where a `BedtimeNight` can be
  // constructed directly. Deleted rather than left green and misleading.

  test('a week of identical nights produces no advice', () async {
    await withClock(Clock.fixed(fixed), () async {
      for (var i = 0; i < 10; i++) {
        await logNight(i, 23, 0, 3);
      }
      expect(SleepService.bedtimeGuidance(), isNull,
          reason: 'with no score gap the "best" nights are just the first five');
    });
  });
}
