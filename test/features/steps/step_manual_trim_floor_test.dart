/// Trimming a day past zero must not leave the ledger in debt.
///
/// `StepService._recompute` floors the total it *derives* — "a net-negative
/// manual tally is a deliberate trim; it lowers the total but can never take
/// the day below zero steps". The entries behind it were not floored, though,
/// so a day trimmed past zero displayed 0 while still holding the full
/// over-subtraction. The next addition went into paying that off.
///
/// Found on a device, driving the manual-entry sheet: a 4,200-step day trimmed
/// by 7,500 read 0 (correct), and adding 4,000 to it produced 700 — 3,300 steps
/// silently absorbed, with nothing on screen to say so. The screen the user
/// sees and the number the app stores have to agree about what "0" means.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  /// Midday, so "today" is unambiguous and nothing rolls over mid-test.
  final now = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 12, 0);
  }();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await StepService.resetForTesting();
  });

  tearDown(() async {
    await StepService.resetForTesting();
    await database.close();
  });

  test('a trim past zero does not eat the next addition', () async {
    await withClock(Clock.fixed(now), () async {
      // The exact sequence driven on the device.
      var day = await StepService.addManualSteps(4200);
      expect(day.effectiveSteps, 4200, reason: 'premise: the day starts at 4,200');

      day = await StepService.addManualSteps(-7500);
      expect(day.effectiveSteps, 0,
          reason: 'a trim bottoms out at zero — this part always worked');

      day = await StepService.addManualSteps(4000);
      expect(day.effectiveSteps, 4000,
          reason: 'the day was showing 0, so adding 4,000 makes 4,000. It read '
              '700 when the 3,300 over-trim was still sitting in the ledger.');
    });
  });

  test('the stored entries agree with the displayed total', () async {
    await withClock(Clock.fixed(now), () async {
      await StepService.addManualSteps(4200);
      final day = await StepService.addManualSteps(-7500);

      final ledger =
          day.manualEntries.fold<int>(0, (sum, e) => sum + e.steps);
      expect(ledger, 0,
          reason: 'the entries are what the next addition is applied to, so '
              'they must sum to the 0 on screen and not to -3,300');
      expect(ledger, day.effectiveSteps);
    });
  });

  test('trimming an already-empty day records nothing', () async {
    await withClock(Clock.fixed(now), () async {
      final day = await StepService.addManualSteps(-1000);
      expect(day.effectiveSteps, 0);
      expect(day.manualEntries, isEmpty,
          reason: 'there is nothing to trim, so there is nothing to write — a '
              'stored -1,000 would be debt against tomorrow\'s first entry');
    });
  });

  test('a trim smaller than the day is applied in full', () async {
    await withClock(Clock.fixed(now), () async {
      await StepService.addManualSteps(4200);
      final day = await StepService.addManualSteps(-200);
      expect(day.effectiveSteps, 4000,
          reason: 'the floor must not clamp a trim that fits');

      final ledger =
          day.manualEntries.fold<int>(0, (sum, e) => sum + e.steps);
      expect(ledger, 4000);
    });
  });

  test('repeated trims stop at zero rather than accumulating debt', () async {
    await withClock(Clock.fixed(now), () async {
      await StepService.addManualSteps(1000);
      for (var i = 0; i < 5; i++) {
        await StepService.addManualSteps(-500);
      }
      final day = await StepService.addManualSteps(300);
      expect(day.effectiveSteps, 300,
          reason: 'five 500-step trims against a 1,000-step day stop at zero; '
              'the 300 that follows is the whole total');
    });
  });
}
