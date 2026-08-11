import 'dart:convert';

import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';

/// Pure grouping logic behind Phase 1's "one reminder per time slot": no
/// Flutter/platform/plugin imports, so it is usable from both the scheduling
/// service (main isolate) and plain unit tests. The background alarm isolate
/// does NOT import this file — by the time an alarm fires, the slot's medicine
/// list already lives in the persisted alarm data (built here at schedule time).

/// Base offset for medicine-slot notification ids on Android. Deliberately
/// tight: `offset + hour*60 + minute` spans only 100000-101439, one id per
/// exact clock-time-of-day — so "4 medicines at 8am" collapse onto one id
/// instead of the old per-medicine scheme's one id per (medicine, slot).
const int slotIdOffset = 100000;

int slotNotificationId(int hour, int minute) => slotIdOffset + hour * 60 + minute;

/// Dose slots scheduled/cancelled per medicine per day. "Every X hours" can't
/// exceed 24 slots/day by construction, but this bound guards against a
/// corrupt/extreme interval value.
const int maxSlotsPerMedicinePerDay = 24;

/// One medicine's occupancy of a [ReminderSlot]: enough to build a display
/// line and to re-gate "is this medicine actually due today" at fire time.
class SlotMedicine {
  final String medicineId;
  final String name;
  final String scheduleJson;

  const SlotMedicine({
    required this.medicineId,
    required this.name,
    required this.scheduleJson,
  });

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'name': name,
        'scheduleJson': scheduleJson,
      };

  factory SlotMedicine.fromJson(Map<String, dynamic> json) => SlotMedicine(
        medicineId: json['medicineId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        scheduleJson: json['scheduleJson']?.toString() ?? '',
      );
}

/// All medicines sharing one exact (hour, minute) reminder time on a given day.
class ReminderSlot {
  final int hour;
  final int minute;
  final List<SlotMedicine> medicines;

  const ReminderSlot({
    required this.hour,
    required this.minute,
    required this.medicines,
  });

  int get notificationId => slotNotificationId(hour, minute);

  bool get isGroup => medicines.length > 1;
}

/// The line shown for one medicine inside a reminder (InboxStyle line, or the
/// single-medicine notification body). Mirrors the old per-medicine reminder
/// title: name + strength + dosage + time label + meal-timing tag.
String buildMedicineReminderLine(EnhancedMedicine medicine, ScheduledTime time) {
  final buffer = StringBuffer(medicine.name);

  if (medicine.strength != null && medicine.strength!.isNotEmpty) {
    buffer.write(' ${medicine.strength}');
  }

  buffer.write(' - ${medicine.displayDosage}');

  if (time.label != null && time.label!.isNotEmpty) {
    buffer.write(' (${time.label})');
  }

  final meal = medicine.schedule.mealTiming;
  if (meal != MealTiming.anytime) {
    buffer.write(' · ${meal.displayName.toLowerCase()}');
  }

  return buffer.toString();
}

/// Groups every active, reminder-enabled, non-PRN medicine's dose slots for
/// [date] by exact (hour, minute) across ALL of [medicines] — so medicines
/// due at the same clock time collapse into one [ReminderSlot] instead of one
/// notification each. Slots are returned sorted by time of day.
List<ReminderSlot> groupRemindersBySlot(
  List<EnhancedMedicine> medicines,
  DateTime date,
) {
  final byKey = <String, List<SlotMedicine>>{};
  final hourMinuteOf = <String, List<int>>{};

  for (final medicine in medicines) {
    if (!medicine.reminderEnabled || medicine.schedule.isPRN) continue;
    if (medicine.isArchived || !medicine.isActive) continue;
    if (medicine.schedule.times.isEmpty) continue;

    final List<ScheduledTime> slots;
    if (medicine.schedule.frequencyType == FrequencyType.everyXHours) {
      slots = medicine.schedule
          .getScheduledTimesForDate(date)
          .map((d) => ScheduledTime(hour: d.hour, minute: d.minute))
          .toList();
    } else {
      slots = medicine.schedule.times;
    }

    final scheduleJson = jsonEncode(medicine.schedule.toJson());

    for (int i = 0; i < slots.length && i < maxSlotsPerMedicinePerDay; i++) {
      final time = slots[i];
      // A windowed dose nudges up to 3x across a span instead of firing once
      // at an exact minute — structurally incompatible with "collapse every
      // medicine due at this exact clock time into one slot." It's scheduled
      // separately; see reminder_window_nudges.dart.
      if (time.hasWindow) continue;
      final key = '${time.hour}:${time.minute}';
      hourMinuteOf[key] = [time.hour, time.minute];
      (byKey[key] ??= <SlotMedicine>[]).add(SlotMedicine(
        medicineId: medicine.id,
        name: buildMedicineReminderLine(medicine, time),
        scheduleJson: scheduleJson,
      ));
    }
  }

  final out = byKey.entries.map((entry) {
    final hm = hourMinuteOf[entry.key]!;
    return ReminderSlot(hour: hm[0], minute: hm[1], medicines: entry.value);
  }).toList();

  out.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  return out;
}

/// Extracts the medicine id(s) a Take/Skip notification action applies to
/// from an `alarm:{...}` payload string. A grouped slot's payload carries a
/// `medicines` list — this is what makes "Take all" fan out to every medicine
/// in the group; a solo reminder falls back to its flat `medicineId`. Pure
/// JSON parsing, so it's safe to call from the background alarm isolate
/// (no Drift access there) and to unit test directly.
List<String> medicineIdsFromAlarmPayload(String? payload) {
  if (payload == null || !payload.startsWith('alarm:')) return const [];
  try {
    final data = jsonDecode(payload.substring('alarm:'.length));
    if (data is! Map) return const [];
    final medicines = data['medicines'];
    if (medicines is List && medicines.isNotEmpty) {
      return medicines
          .map((m) => (m as Map)['medicineId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    }
    final medId = data['medicineId']?.toString();
    return (medId != null && medId.isNotEmpty) ? [medId] : const [];
  } catch (_) {
    return const [];
  }
}
