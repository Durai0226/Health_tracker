import 'reminder_slot_grouping.dart' show maxSlotsPerMedicinePerDay;

/// Pure Dart, isolate-safe logic behind Phase 4's opt-in reminder windows: a
/// dose can nudge up to 3 times across a window (start/middle/end) instead of
/// firing once at an exact minute — Round Health's model. Structurally
/// separate from reminder_slot_grouping.dart's exact-time grouping: a
/// window's nudges are synthetic, per-medicine timestamps, not "medicines
/// sharing a clock time," so they can't collapse into a shared slot the way
/// exact-time reminders do.

/// Base offset for window-nudge notification/alarm ids on Android. Disjoint
/// from every other reserved range in this app: medicine slots
/// (100000-101439, +100000 again for their snoozes), the caregiver alert
/// (920000-920999), and the water/bedtime/wake block (900000-910002).
const int windowNudgeIdOffset = 930000;

/// Nudges reserved per dose-time: start, middle, end.
const int maxNudgesPerTime = 3;

/// Collision-free id for one nudge: `medicineIndex` is the SAME stable,
/// densely-allocated per-medicine index `MedicationReminderService` already
/// maintains (previously used only for the iOS legacy scheme); `timeIndex` is
/// this dose's position in the medicine's own `schedule.times`.
int windowNudgeId(int medicineIndex, int timeIndex, int nudgeIndex) =>
    windowNudgeIdOffset +
    medicineIndex * (maxSlotsPerMedicinePerDay * maxNudgesPerTime) +
    timeIndex * maxNudgesPerTime +
    nudgeIndex;

/// SharedPreferences key marking one dose (a medicine + its window's START
/// time, the same instant used as its `doseLogId`) as resolved
/// (taken/skipped). Checked by every nudge in the window before firing, and
/// before chaining the next one. Written from BOTH the background isolate
/// (the instant a notification Take/Skip is tapped — before the main isolate
/// ever drains the queue) and the main isolate (markMedicineTaken/
/// markMedicineSkipped, for a dose taken in-app) — the two MUST stay
/// byte-for-byte in agreement on this format.
String nudgeResolvedKey(String medicineId, DateTime scheduledTime) =>
    'nudge_resolved_${medicineId}_${scheduledTime.millisecondsSinceEpoch}';

/// The (up to 3, strictly increasing) minutes-of-day a window's nudges fire
/// at: start, an adaptive-or-geometric middle, and end.
///
/// [adaptiveSuggestedMinutes] is the user's real median take-time for this
/// dose (`AdaptiveTiming.suggest`, computed by the caller on the main isolate
/// — Drift isn't available where a fired alarm runs) — when it falls
/// strictly inside the window, it replaces the geometric midpoint so the
/// "middle" nudge lands where the user actually tends to take the dose, not
/// just halfway through the window. This is what turns `AdaptiveTiming`, a
/// previously display-only insight, into actual behavior.
///
/// Deduplicates by construction: a short window can make start/middle/end
/// round to the same minute, and a dose shouldn't nudge twice at once.
List<int> windowNudgeMinutes({
  required int startMinuteOfDay,
  required int windowMinutes,
  int? adaptiveSuggestedMinutes,
}) {
  final end = startMinuteOfDay + windowMinutes;
  final geometricMiddle = startMinuteOfDay + windowMinutes ~/ 2;
  final middle = (adaptiveSuggestedMinutes != null &&
          adaptiveSuggestedMinutes > startMinuteOfDay &&
          adaptiveSuggestedMinutes < end)
      ? adaptiveSuggestedMinutes
      : geometricMiddle;

  final minutes = <int>[startMinuteOfDay];
  if (middle > minutes.last) minutes.add(middle);
  if (end > minutes.last) minutes.add(end);
  return minutes;
}
