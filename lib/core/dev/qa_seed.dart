import 'package:flutter/foundation.dart';

import '../services/clean_storage_service.dart';
import '../../features/diary/models/diary_entry.dart';
import '../../features/diary/services/diary_storage_service.dart';
import '../../features/medication/models/enhanced_medicine.dart';
import '../../features/medication/models/medicine_enums.dart';
import '../../features/medication/models/medicine_log.dart';
import '../../features/medication/models/medicine_schedule.dart';
import '../../features/medication/models/blood_pressure_reading.dart';
import '../../features/medication/models/glucose_reading.dart';
import '../../features/medication/models/mood_entry.dart';
import '../../features/medication/models/weight_reading.dart';
import '../../features/medication/services/medicine_storage_service.dart';
import '../../features/medication/services/vitals_storage_service.dart';
import '../../features/period/models/flow_intensity.dart';
import '../../features/period/services/period_service.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/steps/services/step_service.dart';
import '../../features/water/models/beverage_type.dart';
import '../../features/water/services/water_service.dart';

/// How much history to plant.
enum SeedProfile {
  /// A month of realistic use — the shape most measurements should be taken
  /// against.
  typical,

  /// A year, to answer "does this feature's cost grow with data volume?".
  /// That question is what catches a whole class of bug, and it cannot be
  /// asked of an empty database.
  heavy,
}

/// Deterministic sample data for QA screenshots, perf measurement and ratings.
///
/// **Why this exists.** The previous seeder (`main_qa.dart`) populated three of
/// thirty tables — steps, sleep, and one preference. Medicines, water, period,
/// vitals, diary and reminders were all left empty, which happens to be every
/// table behind the app's heaviest screens. An empty database makes every
/// screen look both fast AND small, so element budgets and query counts
/// measured against it are understatements, and any rating derived from them
/// is measuring the empty state rather than the app.
///
/// Deterministic on purpose: no `Random`, so two runs produce identical
/// numbers and a budget can be compared across commits.
///
/// Guarded by a preference so relaunches do not double-count; pass
/// [force] in tests, where the database is fresh each time anyway.
Future<void> seedQaData({
  SeedProfile profile = SeedProfile.typical,
  bool force = false,
}) async {
  if (!force &&
      CleanStorageService.getAppPreference('qa_seeded', false) == true) {
    return;
  }

  final days = profile == SeedProfile.heavy ? 365 : 30;
  final now = DateTime.now();

  await _seedSteps(now, days);
  await _seedSleep(now, days);
  await _seedMedicines(now, days, profile);
  await _seedWater(now, days);
  await _seedVitals(now, days);
  await _seedPeriod(now, days);
  await _seedDiary(now, days);

  await CleanStorageService.setAppPreference('qa_seeded', true);
}

// ---------------------------------------------------------------------------

Future<void> _seedSteps(DateTime now, int days) async {
  // Mostly hitting the 8k default goal, with one dip a forgiving streak should
  // absorb and a 12,430 personal best.
  const pattern = [9200, 8600, 7000, 8100, 12430, 8300, 9000, 6500, 8800];
  try {
    for (var i = 1; i <= days; i++) {
      await StepService.addManualStepsForDate(
        now.subtract(Duration(days: i)),
        pattern[i % pattern.length],
        maxDaysBack: days + 1,
      );
    }
    await StepService.addManualSteps(4200); // today, in progress
  } catch (e) {
    debugPrint('seed steps failed: $e');
  }
}

Future<void> _seedSleep(DateTime now, int days) async {
  try {
    for (var i = 1; i <= days; i++) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final jitter = (i * 11) % 40 - 20; // -20..+19 min, "fairly regular"
      final wake = DateTime(day.year, day.month, day.day, 7, 0);
      await SleepService.logManualSession(
        bedtime: wake
            .subtract(const Duration(hours: 8, minutes: 15))
            .add(Duration(minutes: jitter)),
        wakeTime: wake,
        quality: i == 1 ? 5 : 4,
      );
    }
  } catch (e) {
    debugPrint('seed sleep failed: $e');
  }
}

Future<void> _seedMedicines(
    DateTime now, int days, SeedProfile profile) async {
  // Four medicines at typical, eight at heavy — enough that an O(N^2) drug
  // interaction scan or a per-medicine query loop actually shows up.
  final count = profile == SeedProfile.heavy ? 8 : 4;
  const names = [
    'Metformin',
    'Lisinopril',
    'Atorvastatin',
    'Levothyroxine',
    'Amlodipine',
    'Omeprazole',
    'Sertraline',
    'Gabapentin',
  ];

  try {
    for (var m = 0; m < count; m++) {
      final id = 'seed-med-$m';
      // Alternate one- and two-a-day so the schedule maths has both shapes.
      final twice = m.isOdd;
      final med = EnhancedMedicine(
        id: id,
        name: names[m],
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        currentStock: 40 - m * 3,
        // Backdated deliberately: the adherence denominator correctly ignores
        // slots before a medicine existed, so a medicine created "now" has
        // zero scheduled doses in the window and adherence degenerates to
        // 100%. The seed has to look like the medicine has been taken for a
        // while, which is the whole point of seeding history.
        createdAt: now.subtract(Duration(days: days + 1)),
        lowStockThreshold: 10,
        schedule: MedicineSchedule(
          frequencyType:
              twice ? FrequencyType.twiceDaily : FrequencyType.onceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0, label: 'Morning'),
            if (twice)
              ScheduledTime(hour: 20, minute: 0, label: 'Evening'),
          ],
          startDate: now.subtract(Duration(days: days)),
        ),
      );
      await MedicineCleanStorageService.addMedicine(med);

      // Dose history: mostly taken, with a realistic scatter of missed and
      // skipped so adherence is not a flat 100%.
      for (var d = 1; d <= days; d++) {
        final day = now.subtract(Duration(days: d));
        for (final t in med.schedule.times) {
          final scheduled =
              DateTime(day.year, day.month, day.day, t.hour, t.minute);
          final roll = (d * 7 + m * 3) % 10;
          final status = roll == 0
              ? MedicineStatus.missed
              : (roll == 1 ? MedicineStatus.skipped : MedicineStatus.taken);
          await MedicineCleanStorageService.addLog(MedicineLog(
            id: 'seed-log-$m-$d-${t.hour}',
            medicineId: id,
            scheduledTime: scheduled,
            actionTime: status == MedicineStatus.taken
                ? scheduled.add(const Duration(minutes: 6))
                : null,
            status: status,
          ));
        }
      }
    }
  } catch (e) {
    debugPrint('seed medicines failed: $e');
  }
}

Future<void> _seedWater(DateTime now, int days) async {
  try {
    final beverage = BeverageType.defaultBeverages.first;
    for (var d = 0; d < days; d++) {
      final day = now.subtract(Duration(days: d));
      // 5-8 drinks a day, varying, so weekly/monthly stats have real spread.
      final drinks = 5 + (d % 4);
      for (var i = 0; i < drinks; i++) {
        await WaterService.addWaterLogForDate(
          date: day,
          amountMl: 250,
          beverage: beverage,
          time: DateTime(day.year, day.month, day.day, 8 + i * 2, 0),
        );
      }
    }
  } catch (e) {
    debugPrint('seed water failed: $e');
  }
}

Future<void> _seedVitals(DateTime now, int days) async {
  try {
    // Every third day, so the vitals lists and trend charts have points
    // without the tables dwarfing everything else.
    for (var d = 1; d <= days; d += 3) {
      final at = now.subtract(Duration(days: d));
      await VitalsStorageService.saveBp(
        BloodPressureReading(
          id: 'seed-bp-$d',
          systolic: 118 + (d % 14),
          diastolic: 76 + (d % 8),
          pulse: 68 + (d % 10),
          takenAt: at,
          createdAt: at,
        ),
        syncToHealthConnect: false,
      );
      await VitalsStorageService.saveGlucose(
        GlucoseReading(
          id: 'seed-gl-$d',
          valueMgdl: 92 + (d % 30),
          takenAt: at,
          createdAt: at,
        ),
        syncToHealthConnect: false,
      );
      await VitalsStorageService.saveWeight(
        WeightReading(
          id: 'seed-wt-$d',
          valueKg: 74.5 - (d * 0.02),
          takenAt: at,
          createdAt: at,
        ),
        syncToHealthConnect: false,
      );
      await VitalsStorageService.saveMood(
        MoodEntry(
          id: 'seed-mood-$d',
          moodIndex: 2 + (d % 3),
          takenAt: at,
          createdAt: at,
        ),
      );
    }
  } catch (e) {
    debugPrint('seed vitals failed: $e');
  }
}

Future<void> _seedPeriod(DateTime now, int days) async {
  try {
    // 28-day cycles, 5 bleeding days each — enough for cycle history and
    // prediction to have something to work from.
    for (var start = 28; start <= days; start += 28) {
      for (var d = 0; d < 5; d++) {
        await PeriodService.setFlow(
          now.subtract(Duration(days: start - d)),
          d < 2 ? FlowIntensity.heavy : FlowIntensity.medium,
        );
      }
    }
  } catch (e) {
    debugPrint('seed period failed: $e');
  }
}

Future<void> _seedDiary(DateTime now, int days) async {
  try {
    for (var d = 1; d <= days; d += 4) {
      final at = now.subtract(Duration(days: d));
      await DiaryStorageService.save(DiaryEntry(
        id: 'seed-diary-$d',
        entryAt: at,
        body: 'Felt steady today. Took everything on time.',
        createdAt: at,
      ));
    }
  } catch (e) {
    debugPrint('seed diary failed: $e');
  }
}
