import 'package:flutter/foundation.dart';

import '../database/app_database.dart' as db;
import '../health/health_windows.dart';
import '../services/clean_storage_service.dart';
import '../../features/biometrics/models/biometric_day.dart';
import '../../features/biometrics/models/biometric_metric.dart';
import '../../features/biometrics/models/health_source.dart';
import '../../features/biometrics/models/workout_session.dart';
import '../../features/biometrics/services/biometrics_service.dart';
import '../../features/biometrics/services/health_source_registry.dart';
import '../../features/diary/models/diary_entry.dart';
import '../../features/diary/services/diary_storage_service.dart';
import '../../features/focus/models/focus_plant.dart';
import '../../features/focus/models/focus_session.dart';
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
import '../../features/reminders/models/reminder_model.dart';
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
}) {
  // Re-entrancy guard, separate from the persisted one below.
  //
  // Integration tests call `app.main()` once per TEST, in the same isolate and
  // against the same database. So a second launch can begin while the first
  // seed is still in flight — and it did: a test that timed out mid-seed was
  // followed by another launch, the two raced, and the second died on
  // `UNIQUE constraint failed: enhanced_medicines.id` (MedicationDao.addMedicine
  // is a plain insert, not an upsert). The persisted `_seedGuardKey` cannot
  // help, because it is only written once the first seed FINISHES.
  //
  // Sharing the in-flight future makes the second caller await the first
  // instead of racing it.
  return _inFlight ??=
      _seedQaData(profile: profile, force: force).whenComplete(() {
    _inFlight = null;
  });
}

Future<void>? _inFlight;

Future<void> _seedQaData({
  required SeedProfile profile,
  required bool force,
}) async {
  if (!force &&
      CleanStorageService.getAppPreference(_seedGuardKey, false) == true) {
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
  await _seedReminders(now);
  await _seedFocus(now, days);
  await _seedBiometrics(now, days);

  await CleanStorageService.setAppPreference(_seedGuardKey, true);
}

/// Versioned and profile-scoped.
///
/// It used to be the bare string `qa_seeded` — the SAME key `main_qa.dart`
/// writes for its own three-table seed. Same bundle id means the same data
/// container, so whichever ran first blocked the other, and a measurement could
/// silently be taken against 9 days of steps and nothing else. Bumping the
/// version also re-seeds devices that carry the old flag.
const String _seedGuardKey = 'qa_seed_v2';

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

Future<void> _seedReminders(DateTime now) async {
  // Reminders are one of the four Today pillars and the seeder planted none,
  // so every reminders screen and the Today pulse row were measured, rated and
  // screenshotted in their empty state.
  //
  // Three deliberate shapes: one overdue (the state with the most UI —
  // highlight, relative time, an action), one later today, one repeating in the
  // future. Category ids are the defaults created by CleanStorageService.
  const specs = [
    ('seed-rem-0', 'Call the pharmacy', 'Refill is ready for collection',
        'health', -3, RepeatType.none, ReminderPriority.high),
    ('seed-rem-1', 'Evening walk', '20 minutes around the block', 'personal', 4,
        RepeatType.daily, ReminderPriority.medium),
    ('seed-rem-2', 'Blood test appointment', 'Fasting from midnight', 'health',
        26, RepeatType.none, ReminderPriority.high),
    ('seed-rem-3', 'Weekly report', 'Send before standup', 'work', 50,
        RepeatType.weekly, ReminderPriority.low),
  ];

  try {
    for (final (id, title, body, category, hourOffset, repeat, priority)
        in specs) {
      await CleanStorageService.saveReminder(Reminder(
        id: id,
        title: title,
        body: body,
        scheduledTime: now.add(Duration(hours: hourOffset)),
        repeatType: repeat,
        priority: priority,
        categoryId: category,
        createdAt: now.subtract(const Duration(days: 2)),
      ));
    }
  } catch (e) {
    debugPrint('seed reminders failed: $e');
  }
}

Future<void> _seedFocus(DateTime now, int days) async {
  // Focus has no Drift table — it persists through app preferences, the same
  // channel `FocusService._saveData` writes. Writing the preference directly is
  // therefore the supported path, not a back door; `FocusService._loadData`
  // reads it on first access, which happens when FocusScreen mounts, well after
  // seeding.
  //
  // Skips every 5th day so the streak has a real gap: a seed where the streak
  // is unbroken cannot exercise the "at risk" and grace-day branches of
  // StreakEngine, which is most of its logic.
  try {
    final sessions = <Map<String, dynamic>>[];
    final span = days > 60 ? 60 : days; // 100-entry persistence cap
    for (var d = 0; d < span; d++) {
      if (d % 5 == 4) continue;
      final day = now.subtract(Duration(days: d));
      final target = 25 + (d % 3) * 10; // 25 / 35 / 45
      final started = DateTime(day.year, day.month, day.day, 9 + (d % 6), 15);
      sessions.add(FocusSession(
        id: 'seed-focus-$d',
        startedAt: started,
        completedAt: started.add(Duration(minutes: target)),
        targetMinutes: target,
        actualMinutes: target,
        wasCompleted: true,
        activityType:
            FocusActivityType.values[d % FocusActivityType.values.length],
        plantType: PlantType.values[d % PlantType.values.length],
      ).toJson());
    }
    await CleanStorageService.setAppPreference('focusSessions', sessions);
  } catch (e) {
    debugPrint('seed focus failed: $e');
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

/// Wearable biometrics + a few workouts.
///
/// Written straight through the DAO rather than through `syncFromHealth`,
/// because there is no health platform in a QA/E2E run — the same reason
/// `_seedSteps` uses manual entries.
///
/// This exists so the Heart and Workouts screens are measured POPULATED. The
/// perf harness's own header warns that budgeting a screen at its empty size
/// is a defect, and without a seeder these two would be budgeted at their
/// loading spinner.
Future<void> _seedBiometrics(DateTime now, int days) async {
  try {
    final dao = db.AppDatabase.instance.biometricsDao;
    final today = DateTime(now.year, now.month, now.day);

    // A plausible resting-HR drift plus one poor night, so the trend has shape
    // instead of being a flat line.
    const resting = [58, 57, 59, 62, 58, 56, 57, 61, 58];
    const hrv = [46.0, 52.0, 44.0, 38.0, 55.0, 58.0, 49.0, 41.0, 51.0];

    for (var i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      final key = dateKeyOf(day);
      final r = resting[i % resting.length];
      await dao.upsertDay(BiometricDay(
        id: key,
        date: day,
        restingHr: r,
        // Every few days is estimated, so the "(est.)" label and the
        // "some days are estimated" note both get exercised.
        restingHrDerived: i % 4 == 3,
        hrMin: r - 4,
        hrAvg: r + 14,
        hrMax: r + 62,
        hrSampleCount: 900,
        hourlyHr: [
          for (var h = 0; h < 24; h++)
            // Night hours dip; two gaps so the null-not-zero path is covered.
            (h == 3 || h == 16) ? null : (h < 7 ? r + 2 : r + 12 + (h % 5) * 4)
        ],
        hrvNightlyMs: hrv[i % hrv.length],
        hrvMetric: HrvMetric.rmssd,
        hrvSampleCount: 1,
        spo2Min: 94 + (i % 3),
        spo2Avg: 96 + (i % 2),
        spo2SampleCount: 40,
        respiratoryRateMin: 12.0,
        respiratoryRateAvg: 14.5,
        respiratoryRateMax: 18.0,
        respiratoryRateSampleCount: 60,
        source: BiometricSource.healthConnect,
        lastSyncedAt: now,
        createdAt: now,
        updatedAt: now,
      ).toCompanion());
    }

    // Three sessions across the last week.
    const workouts = [
      (1, 'RUNNING', 32, 5200.0, 320),
      (3, 'WALKING', 48, 3900.0, 180),
      (5, 'STRENGTH_TRAINING', 41, null, 240),
    ];
    for (final (daysAgo, type, mins, dist, kcal) in workouts) {
      final start = DateTime(today.year, today.month, today.day - daysAgo, 7, 15);
      await dao.upsertWorkout(WorkoutSession(
        id: 'hw_${start.millisecondsSinceEpoch}_$type',
        dateKey: dateKeyOf(start),
        startedAt: start,
        endedAt: start.add(Duration(minutes: mins)),
        durationMinutes: mins,
        activityType: type,
        energyKcal: kcal,
        distanceMeters: dist,
        avgHr: 132,
        maxHr: 168,
        source: BiometricSource.healthConnect,
        createdAt: now,
        updatedAt: now,
      ).toCompanion());
    }

    // One contributing device, so Connected devices is measured with a row
    // rather than its empty state.
    final srcId = HealthSourceRegistry.keyForParts(
        'googleHealthConnect', 'com.samsung.health', 'Galaxy Watch5');
    await dao.upsertSource(HealthSource(
      id: srcId,
      sourceId: 'com.samsung.health',
      sourceName: 'Galaxy Watch5',
      platformIndex: 0,
      metrics: {
        BiometricMetricKey.hr:
            SourceMetricStat(lastSeenAt: now, points: 900 * days),
        BiometricMetricKey.hrv: SourceMetricStat(lastSeenAt: now, points: days),
        BiometricMetricKey.spo2:
            SourceMetricStat(lastSeenAt: now, points: 40 * days),
        BiometricMetricKey.workout:
            SourceMetricStat(lastSeenAt: now, points: 3),
      },
      firstSeenAt: today.subtract(Duration(days: days)),
      lastSeenAt: now,
      createdAt: now,
      updatedAt: now,
    ).toCompanion());
    // The seeder writes straight through the DAO, so the service's in-memory
    // notifiers — which every biometrics screen renders from — are still
    // empty. Without this the screens measure and screenshot as blank.
    await BiometricsService.reloadFromDb();
  } catch (e) {
    debugPrint('seed biometrics failed: $e');
  }
}
