import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import 'reminder_window_nudges.dart';

/// How long a critical medicine keeps asking: a first alarm, then a nudge at the
/// half-way point and one at the end — 0, 15 and 30 minutes.
const int criticalWindowMinutes = 30;

/// Whether [m]'s "critical" flag can be honoured by the follow-up machinery.
///
/// Follow-ups ride on the reminder-window nudges, which are built from the
/// weekday `schedule.times` alone. A schedule with a weekend override or an
/// every-X-hours fan-out is armed by the slot path with different times, so
/// moving those doses over would drop the ones the nudge builder cannot see. The
/// form says so rather than showing a switch that does nothing.
bool canFollowUp(EnhancedMedicine m) => canFollowUpSchedule(m.schedule);

bool canFollowUpSchedule(MedicineSchedule s) => canFollowUpWhen(
    weekendOverride: s.hasWeekendOverride, frequencyType: s.frequencyType);

/// The rule itself, for the add-medicine form, which has the two inputs but not
/// yet a [MedicineSchedule].
bool canFollowUpWhen({
  required bool weekendOverride,
  required FrequencyType frequencyType,
}) =>
    !weekendOverride && frequencyType != FrequencyType.everyXHours;

/// The window, in minutes, a dose at [time] nudges across — or null when it fires
/// exactly once at its minute.
///
/// A window the user chose always wins. Otherwise a critical medicine gets
/// [criticalWindowMinutes], so a must-take dose keeps ringing until it is taken
/// or skipped instead of arriving once and being swiped away. Every other
/// medicine is untouched.
int? effectiveWindowMinutes(EnhancedMedicine m, ScheduledTime time) {
  if (time.hasWindow) return time.windowMinutes;
  return m.criticalAlert && canFollowUp(m) ? criticalWindowMinutes : null;
}

/// The minutes-of-day the nudge chain for [m]'s dose at [time] fires at, or null
/// when that dose is not nudged.
///
/// [adaptiveSuggestedMinutes] only matters for a window the user chose: it moves
/// the middle nudge to their real take-time. A critical dose's implicit window
/// keeps even 0 / 15 / 30 spacing — it is a safety net, not a habit to learn.
List<int>? nudgeMinutesForDose(
  EnhancedMedicine m,
  ScheduledTime time, {
  int? adaptiveSuggestedMinutes,
}) {
  final window = effectiveWindowMinutes(m, time);
  if (window == null) return null;
  return windowNudgeMinutes(
    startMinuteOfDay: time.hour * 60 + time.minute,
    windowMinutes: window,
    adaptiveSuggestedMinutes: time.hasWindow ? adaptiveSuggestedMinutes : null,
  );
}
