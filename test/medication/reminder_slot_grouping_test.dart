import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/dose_action_queue.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';

/// Phase 1's grouping gate: N medicines sharing an exact reminder time collapse
/// onto ONE notification id instead of one each, "Take all" enqueues one dose
/// action per medicine, and a solo medicine's slot is unaffected. Pure Dart —
/// no DB/plugin dependencies, so this runs headlessly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EnhancedMedicine med(
    String id,
    String name, {
    int hour = 8,
    int minute = 0,
    String? label,
    FrequencyType frequencyType = FrequencyType.onceDaily,
    int? intervalHours,
    bool reminderEnabled = true,
    bool isPRN = false,
    bool isActive = true,
    bool isArchived = false,
    MealTiming mealTiming = MealTiming.anytime,
    int? windowMinutes,
  }) =>
      EnhancedMedicine(
        id: id,
        name: name,
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        reminderEnabled: reminderEnabled,
        isActive: isActive,
        isArchived: isArchived,
        schedule: MedicineSchedule(
          frequencyType: frequencyType,
          intervalHours: intervalHours,
          isPRN: isPRN,
          mealTiming: mealTiming,
          times: isPRN
              ? const []
              : [
                  ScheduledTime(
                    hour: hour,
                    minute: minute,
                    label: label,
                    windowMinutes: windowMinutes,
                  ),
                ],
        ),
      );

  group('slotNotificationId', () {
    test('is a pure, collision-free function of clock time', () {
      expect(slotNotificationId(0, 0), slotIdOffset);
      expect(slotNotificationId(8, 0), slotIdOffset + 8 * 60);
      expect(slotNotificationId(23, 59), slotIdOffset + 23 * 60 + 59);
      // Same clock time → same id, regardless of which medicine asks.
      expect(slotNotificationId(8, 0), slotNotificationId(8, 0));
      expect(slotNotificationId(8, 0), isNot(slotNotificationId(8, 1)));
    });
  });

  group('groupRemindersBySlot', () {
    final date = DateTime(2026, 1, 1);

    test('N medicines at the same time collapse onto one slot/id', () {
      final medicines = [
        med('m1', 'Aspirin', hour: 8, minute: 0),
        med('m2', 'Metformin', hour: 8, minute: 0),
        med('m3', 'Lisinopril', hour: 8, minute: 0),
      ];

      final slots = groupRemindersBySlot(medicines, date);

      expect(slots, hasLength(1));
      expect(slots.single.medicines, hasLength(3));
      expect(slots.single.notificationId, slotNotificationId(8, 0));
      expect(slots.single.isGroup, isTrue);
      expect(slots.single.medicines.map((m) => m.medicineId),
          containsAll(['m1', 'm2', 'm3']));
    });

    test('a solo medicine is unchanged: one slot, one medicine, not a group',
        () {
      final slots = groupRemindersBySlot([med('m1', 'Aspirin')], date);

      expect(slots, hasLength(1));
      expect(slots.single.medicines, hasLength(1));
      expect(slots.single.isGroup, isFalse);
      expect(slots.single.notificationId, slotNotificationId(8, 0));
    });

    test('medicines at different times never merge', () {
      final medicines = [
        med('m1', 'Aspirin', hour: 8, minute: 0),
        med('m2', 'Metformin', hour: 20, minute: 0),
      ];

      final slots = groupRemindersBySlot(medicines, date);

      expect(slots, hasLength(2));
      expect(slots.every((s) => s.medicines.length == 1), isTrue);
      expect(slots.map((s) => s.notificationId),
          containsAll([slotNotificationId(8, 0), slotNotificationId(20, 0)]));
    });

    test('slots are sorted by time of day', () {
      final medicines = [
        med('m1', 'Evening dose', hour: 20, minute: 0),
        med('m2', 'Morning dose', hour: 6, minute: 30),
      ];

      final slots = groupRemindersBySlot(medicines, date);

      expect(slots.first.hour, 6);
      expect(slots.last.hour, 20);
    });

    test('PRN medicines are never scheduled', () {
      final slots = groupRemindersBySlot([med('m1', 'PRN pain relief', isPRN: true)], date);
      expect(slots, isEmpty);
    });

    test('reminders disabled → excluded', () {
      final slots =
          groupRemindersBySlot([med('m1', 'Aspirin', reminderEnabled: false)], date);
      expect(slots, isEmpty);
    });

    test('archived or inactive medicines → excluded', () {
      expect(groupRemindersBySlot([med('m1', 'A', isArchived: true)], date), isEmpty);
      expect(groupRemindersBySlot([med('m1', 'A', isActive: false)], date), isEmpty);
    });

    test('a window-enabled dose is excluded from slot grouping entirely '
        '(Phase 4: windows are scheduled on a structurally separate path)',
        () {
      final windowed = med('m1', 'Windowed', hour: 8, minute: 0, windowMinutes: 60);
      expect(groupRemindersBySlot([windowed], date), isEmpty);
    });

    test('a window-enabled dose never merges into an exact-time medicine\'s '
        'slot even at the same clock time', () {
      final windowed = med('m1', 'Windowed', hour: 8, minute: 0, windowMinutes: 60);
      final exact = med('m2', 'Exact', hour: 8, minute: 0);
      final slots = groupRemindersBySlot([windowed, exact], date);
      expect(slots, hasLength(1));
      expect(slots.single.medicines, hasLength(1));
      expect(slots.single.medicines.single.medicineId, 'm2');
    });

    test('"every X hours" fan-out can still merge with a fixed-time medicine',
        () {
      // Anchor 8:00 every 6h → 8:00, 14:00, 20:00.
      final everyXHours = med('m1', 'Every-6h dose',
          hour: 8,
          minute: 0,
          frequencyType: FrequencyType.everyXHours,
          intervalHours: 6);
      final fixedAt2pm = med('m2', 'Afternoon dose', hour: 14, minute: 0);

      final slots = groupRemindersBySlot([everyXHours, fixedAt2pm], date);

      expect(slots, hasLength(3)); // 8:00, 14:00, 20:00
      final twoPm = slots.firstWhere((s) => s.hour == 14 && s.minute == 0);
      expect(twoPm.medicines, hasLength(2));
      expect(twoPm.isGroup, isTrue);
      final eightAm = slots.firstWhere((s) => s.hour == 8 && s.minute == 0);
      expect(eightAm.medicines, hasLength(1));
    });

    test('each medicine carries its own scheduleJson for the fire-time gate',
        () {
      final specificDays = med('m1', 'Mon/Wed only',
          hour: 9, minute: 0, frequencyType: FrequencyType.specificDays);
      final slots = groupRemindersBySlot([specificDays], date);

      final json = jsonDecode(slots.single.medicines.single.scheduleJson);
      expect(json['frequencyType'], FrequencyType.specificDays.index);
    });
  });

  group('buildMedicineReminderLine', () {
    test('formats name, strength, dosage, time label and meal tag', () {
      final m = med('m1', 'Metformin',
          hour: 8, minute: 0, label: 'Morning', mealTiming: MealTiming.withMeal);
      final line =
          buildMedicineReminderLine(m, m.schedule.times.single);
      expect(line, 'Metformin 500mg - 1 pill(s) (Morning) · with meals');
    });

    test('omits the meal tag when mealTiming is anytime', () {
      final m = med('m1', 'Metformin', label: 'Morning');
      final line = buildMedicineReminderLine(m, m.schedule.times.single);
      expect(line, isNot(contains('·')));
    });
  });

  group('medicineIdsFromAlarmPayload', () {
    test('a grouped payload returns every medicine id ("Take all")', () {
      final payload = 'alarm:${jsonEncode({
            'id': 100480,
            'medicines': [
              {'medicineId': 'm1', 'name': 'Aspirin'},
              {'medicineId': 'm2', 'name': 'Metformin'},
              {'medicineId': 'm3', 'name': 'Lisinopril'},
            ],
            'hour': 8,
            'minute': 0,
          })}';

      expect(medicineIdsFromAlarmPayload(payload), ['m1', 'm2', 'm3']);
    });

    test('a solo payload falls back to its flat medicineId', () {
      final payload = 'alarm:${jsonEncode({
            'id': 100480,
            'medicineId': 'm1',
            'hour': 8,
            'minute': 0,
          })}';

      expect(medicineIdsFromAlarmPayload(payload), ['m1']);
    });

    test('null, non-medicine, or malformed payloads yield nothing', () {
      expect(medicineIdsFromAlarmPayload(null), isEmpty);
      expect(medicineIdsFromAlarmPayload('alarm:1234'), isEmpty); // legacy id-only
      expect(medicineIdsFromAlarmPayload('alarm:{not json'), isEmpty);
      expect(
          medicineIdsFromAlarmPayload('alarm:${jsonEncode({'title': 'Water'})}'),
          isEmpty);
    });
  });

  group('"Take all" fans out to one queued dose action per medicine', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a 3-medicine group enqueues exactly 3 take actions', () async {
      final payload = 'alarm:${jsonEncode({
            'medicines': [
              {'medicineId': 'm1'},
              {'medicineId': 'm2'},
              {'medicineId': 'm3'},
            ],
            'hour': 8,
            'minute': 0,
          })}';
      final scheduled = DateTime.now();

      for (final id in medicineIdsFromAlarmPayload(payload)) {
        await DoseActionQueue.enqueue(
            medicineId: id,
            scheduledTime: scheduled,
            action: DoseActionQueue.actionTake);
      }

      final drained = await DoseActionQueue.drain();
      expect(drained, hasLength(3));
      expect(drained.every((a) => a.isTake), isTrue);
      expect(drained.map((a) => a.medicineId), ['m1', 'm2', 'm3']);
    });

    test('a solo medicine enqueues exactly one action', () async {
      final payload = 'alarm:${jsonEncode({'medicineId': 'm1', 'hour': 8, 'minute': 0})}';

      for (final id in medicineIdsFromAlarmPayload(payload)) {
        await DoseActionQueue.enqueue(
            medicineId: id,
            scheduledTime: DateTime.now(),
            action: DoseActionQueue.actionTake);
      }

      final drained = await DoseActionQueue.drain();
      expect(drained, hasLength(1));
      expect(drained.single.medicineId, 'm1');
    });
  });
}
