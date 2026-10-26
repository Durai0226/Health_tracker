/// The Adherence ring and the chart beneath it must cover the same days.
///
/// `getAdherenceStats(days: 7)` derived its window as
/// `now.subtract(Duration(days: 7))` — an exact 168-hour instant — while the
/// "Daily adherence" chart on the same screen builds its bars from
/// `dayOffset(now, -(7 - 1))`, seven whole calendar days.
///
/// So at 14:00 the ring's window opened at 14:00 EIGHT days ago, and a slot at
/// 20:00 that evening counted toward the headline while appearing on no bar at
/// all. `subtract(Duration(days:))` on a local DateTime is also the pattern
/// this project bans, for the DST reason in `calendar_day.dart`.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  /// Midday, so a 20:00 slot is still ahead of "now" today and behind it on
  /// every earlier day — which is exactly what separates the two windows.
  final now = DateTime(2026, 3, 18, 14, 0);

  Future<void> seedEveningDose() async {
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'm1',
      name: 'Levothyroxine',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime(2026, 1, 1),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 20, minute: 0)],
      ),
    ));
  }

  test('a 7-day window counts seven calendar days, not 168 hours', () async {
    await withClock(Clock.fixed(now), () async {
      await MedicineCleanStorageService.init();
      await seedEveningDose();

      final stats = await MedicineCleanStorageService.getAdherenceStats(days: 7);
      final scheduled = stats['scheduled'] as int;

      // The window is Mar 12–18. Its 20:00 slots on the 12th–17th have passed
      // (six); today's 20:00 has not. The elapsed-hours window reached back to
      // 14:00 on the 11th, so the 11th's 20:00 slot fell inside it too — a
      // seventh dose, on a day the chart does not draw.
      expect(scheduled, 6,
          reason: 'seven counts the 20:00 dose from the day BEFORE the chart '
              "starts, so the headline could report a miss that appears on no "
              'bar');
    });
  });

  test('the window starts where the chart starts', () async {
    await withClock(Clock.fixed(now), () async {
      await MedicineCleanStorageService.init();
      await seedEveningDose();

      // The chart's own first day, from the report screen.
      final chartStart = dayOffset(now, -(7 - 1));
      expect(chartStart, DateTime(2026, 3, 12),
          reason: 'premise: this is the first bar the chart draws');

      // A dose the evening before that day must not be counted.
      final beforeChart = DateTime(2026, 3, 11, 20, 0);
      expect(beforeChart.isBefore(chartStart), isTrue);

      final stats = await MedicineCleanStorageService.getAdherenceStats(days: 7);
      expect(stats['scheduled'], 6,
          reason: 'the ring counted $beforeChart, which the chart never shows');
    });
  });

  test('a 30-day window is thirty calendar days', () async {
    await withClock(Clock.fixed(now), () async {
      await MedicineCleanStorageService.init();
      await seedEveningDose();
      final stats =
          await MedicineCleanStorageService.getAdherenceStats(days: 30);
      expect(stats['scheduled'], 29,
          reason: 'Feb 17 – Mar 18 is thirty days; the last 20:00 has not '
              'come round yet');
    });
  });
}
