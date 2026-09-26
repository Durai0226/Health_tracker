import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/insights/services/insight_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// `InsightService.gatherAll` must never turn an ABSENCE of data into a
/// finding about the user.
///
/// Every screen this feeds — the Insights hub, the proactive nudge on Home —
/// presents what it renders as something the app noticed about *you*. That
/// makes a fabricated statistic worse than a missing one: "You've taken about
/// 0% of scheduled doses lately" is a false accusation on the day someone adds
/// their first medicine, and "You're about 8000 steps from today's goal" is a
/// claim about a day the app has no step data for at all.
///
/// The guards that prevent this are scattered and individually easy to delete,
/// because each is a small condition inside a branch that looks like it is
/// about formatting:
///
///   * `InsightService.gatherAll` — `history.isEmpty ? null : adherence(...)`.
///     Without it `AdherenceAnalyzer.adherence` returns its documented `0` for
///     an empty history, `InsightEngine.medicine` reads `0 < 0.7`, and the hub
///     leads with "Adherence slipping".
///   * `InsightEngine.steps` — the `steps > 0` clause on the "short walk"
///     branch. Without it a goal alone is enough to generate a shortfall.
///   * `InsightEngine.sleep` — `loggedNights >= 4` on the weekly branches, so
///     an unlogged week cannot be read as a multi-hour rest deficit.
///
/// Until now `InsightService` had no correctness cover of any kind: the only
/// test naming it counted SELECT statements.
///
/// ## Why every case here carries a positive control
///
/// `gatherAll` wraps each feature in `try { ... } catch (_) {}`. So "the empty
/// database produced no insight" is EXACTLY what you would also see if every
/// block threw on the first line — which is how an assertion like this becomes
/// one that cannot fail. Each test therefore seeds the minimum data that makes
/// its own block speak and asserts that it does, so the silence asserted just
/// above is a decision the code made rather than an exception it swallowed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await StepService.resetForTesting();
    await SleepService.resetForTesting();
    await WaterService.init();
    // Deliberately initialised: this gives the profile a real 8000-step goal
    // with zero steps recorded against it, which is the state the "short walk"
    // branch has to decline. An uninitialised service would have no goal, and
    // the case would pass for the wrong reason.
    await StepService.init();
  });

  tearDown(() async => database.close());

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Insight? byId(List<Insight> all, String id) {
    for (final i in all) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Everything an insight puts in front of a reader.
  Iterable<String> visibleText(Insight i) sync* {
    yield i.title;
    yield i.detail;
    yield i.why;
    if (i.metric != null) yield i.metric!;
    if (i.actionLabel != null) yield i.actionLabel!;
  }

  String describe(List<Insight> all) =>
      all.map((i) => '${i.id}: "${i.title}" / metric=${i.metric}').join(' | ');

  group('an empty database', () {
    test('produces no insight at all', () async {
      final all = await InsightService.gatherAll();
      expect(
        all,
        isEmpty,
        reason: 'nothing has been logged, so every insight here would be a '
            'statement about data that does not exist. Got: ${describe(all)}',
      );
    });

    test(
        'POSITIVE CONTROL — the same harness does produce insights once there '
        'is something to say', () async {
      // Without this, the assertion above would pass just as happily if every
      // feature block in gatherAll threw into its `catch (_)`.
      expect(await InsightService.gatherAll(), isEmpty);

      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day - 1, 23, 0),
        wakeTime: DateTime(today.year, today.month, today.day, 5, 0),
      );

      final all = await InsightService.gatherAll();
      expect(byId(all, 'sleep_short'), isNotNull,
          reason: 'six hours against an eight-hour target is a real finding, '
              'and gatherAll must reach it — proving the pipeline above was '
              'silent by decision, not by exception. Got: ${describe(all)}');
    });
  });

  group('an absence is never reported as a statistic', () {
    test('a step goal with nothing walked is not "8000 steps to go"', () async {
      expect(StepService.getTodayData().goalSteps, greaterThan(0),
          reason: 'the goal must exist for this case to mean anything');
      expect(StepService.getTodayData().effectiveSteps, 0);

      final empty = await InsightService.gatherAll();
      expect(
        empty.where((i) => i.feature == InsightFeature.steps),
        isEmpty,
        reason: 'a goal is not a measurement. With no steps recorded the app '
            'cannot know the user has walked none — only that it has not been '
            'told. Got: ${describe(empty)}',
      );

      // POSITIVE CONTROL: once steps exist, the shortfall IS reported.
      await StepService.addManualSteps(3000);
      final seeded = byId(await InsightService.gatherAll(), 'steps_short');
      expect(seeded, isNotNull,
          reason: 'the branch must still fire on real data — otherwise the '
              'assertion above is satisfied by a dead code path');
      expect(seeded!.metric, '5000 to go');
    });

    test('a medicine that has never been logged has no adherence percentage',
        () async {
      await MedicineCleanStorageService.addMedicine(
        EnhancedMedicine(
          id: 'm1',
          name: 'Amlodipine',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          // Stock with no consumption history: the refill forecast must also
          // decline rather than divide by a zero daily rate and announce a
          // run-out date.
          currentStock: 30,
          createdAt: today.subtract(const Duration(days: 20)),
          schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
          ),
        ),
        stampActiveProfile: false,
      );

      final unlogged = await InsightService.gatherAll();
      expect(
        unlogged.where((i) => i.feature == InsightFeature.medicine),
        isEmpty,
        reason: 'the medicine exists but no dose has ever been recorded. '
            '"0% of scheduled doses" is the single most damaging thing this '
            'service could say to someone on their first day. '
            'Got: ${describe(unlogged)}',
      );
      for (final i in unlogged) {
        expect(i.metric, isNot('0%'),
            reason: 'no percentage may be derived from an empty history');
      }

      // POSITIVE CONTROL: with a real, genuinely poor history the percentage
      // IS reported — including a legitimate low figure. The rule is "no
      // statistic without data", not "never say a low number".
      for (var i = 1; i <= 10; i++) {
        final slot = DateTime(today.year, today.month, today.day - i, 8, 0);
        final id = MedicineCleanStorageService.doseLogId('m1', slot);
        await MedicineCleanStorageService.addLog(
          i <= 8
              ? MedicineLog.missed(
                  id: id, medicineId: 'm1', scheduledTime: slot)
              : MedicineLog.taken(
                  id: id, medicineId: 'm1', scheduledTime: slot),
        );
      }

      final logged = byId(await InsightService.gatherAll(), 'med_adherence');
      expect(logged, isNotNull,
          reason: 'two of ten doses taken is a real finding and must surface');
      expect(logged!.metric, '20%');
      expect(logged.progress, closeTo(0.2, 0.001));
    });
  });

  group('no insight carries a malformed number', () {
    /// Applies to both the empty and the populated set, because a NaN that only
    /// appears once there is data is the same defect.
    void assertWellFormed(List<Insight> all, String label) {
      for (final i in all) {
        for (final text in visibleText(i)) {
          expect(text, isNot(contains('NaN')),
              reason: '$label: ${i.id} rendered a NaN — "$text"');
          expect(text, isNot(contains('Infinity')),
              reason: '$label: ${i.id} rendered an Infinity — "$text"');
          expect(text, isNot(contains('null')),
              reason: '$label: ${i.id} rendered an unfilled value — "$text"');
        }
        final p = i.progress;
        if (p != null) {
          expect(p.isFinite, isTrue,
              reason: '$label: ${i.id} has a non-finite progress ($p), which '
                  'the hub hero feeds straight into a ProgressRing');
          expect(p, greaterThanOrEqualTo(0),
              reason: '$label: ${i.id} has a negative progress ($p)');
          // No upper bound is asserted on purpose. `steps_goal` and
          // `water_goal` both divide the actual by the goal AFTER establishing
          // the goal was beaten, so 200% of a step goal is a progress of 2.0 by
          // design. Pinning `<= 1` here would fail on correct code, and a guard
          // that fails on correct code is one someone deletes.
        }
      }
    }

    test('not on an empty database, and not on a populated one', () async {
      assertWellFormed(await InsightService.gatherAll(), 'empty');

      // Populate several features at once so the scan has something to scan —
      // otherwise it is a loop over an empty list and cannot fail.
      final water = WaterService.getBeverage('water')!;
      await WaterService.saveProfile(WaterService.getProfile()
          .copyWith(customGoalMl: 2000, useCustomGoal: true));
      await WaterService.addWaterLog(amountMl: 2400, beverage: water);
      await StepService.addManualSteps(16000);
      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day - 1, 23, 0),
        wakeTime: DateTime(today.year, today.month, today.day, 5, 0),
      );

      final populated = await InsightService.gatherAll();
      expect(populated, isNotEmpty,
          reason: 'the scan below is vacuous over an empty list');
      assertWellFormed(populated, 'populated');
    });
  });
}
