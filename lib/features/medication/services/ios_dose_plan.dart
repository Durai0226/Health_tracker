import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';

/// How a planned dose reminder repeats once it is armed.
enum DoseRepeat {
  /// Fires at this time every day, until it is cancelled.
  daily,

  /// Fires at this time on this weekday, every week, until it is cancelled.
  weekly,

  /// Fires once, at exactly [PlannedDose.at].
  once,
}

/// One notification an iPhone should hold for a medicine's dose reminders.
class PlannedDose {
  const PlannedDose(this.repeat, this.at, {int? hour, int? minute})
      : _hour = hour,
        _minute = minute;

  final DoseRepeat repeat;

  /// The first (for a repeating one) or only (for [DoseRepeat.once]) moment it
  /// fires, in the phone's own time.
  ///
  /// For a repeating reminder this is a moment that exists on the clock, so it
  /// repeats at the dose's own time: the planner passes over a day on which the
  /// clocks skip the time, because a `DateTime` built for it is moved forward by
  /// Dart, and a reminder anchored there would repeat an hour late for good.
  final DateTime at;

  final int? _hour;
  final int? _minute;

  /// The dose's own clock time — the slot it is for, which a "Take" on it is logged
  /// against. Not always what [at] reads: a one-off for a time the clocks skip is
  /// armed for the moment it would have been (03:30) but is the 02:30 dose.
  int get hour => _hour ?? at.hour;
  int get minute => _minute ?? at.minute;

  /// 1 = Monday … 7 = Sunday, as [DateTime.weekday]. Meaningful for
  /// [DoseRepeat.weekly].
  int get weekday => at.weekday;

  @override
  String toString() => 'PlannedDose(${repeat.name}, $at)';
}

/// What to arm on an iPhone for a medicine, given its schedule.
///
/// Android arms one alarm per clock time and decides, when it fires, whether that
/// medicine is due today (the alarm carries the schedule). An iPhone cannot: a
/// notification is a fixed instruction to the OS, with nothing run at the moment it
/// fires. Every medicine was armed as "this time, every day" — so a weekly dose
/// reminded every day, an every-other-day dose every day, a three-weeks-on course
/// through its week off, and a course that had ended kept on reminding. For
/// something like a once-a-week tablet, a reminder on the six days it must NOT be
/// taken is not a nuisance.
///
/// So the plan is as exact as the OS allows:
///  * **Every day, for ever** — the repeating daily reminder it always was. Nothing
///    about a plain daily medicine changes.
///  * **Chosen weekdays, for ever** — one repeating weekly reminder per weekday and
///    time. They never lapse.
///  * **Anything else** — an end date or a length of course, a start in the future,
///    every X days, on-and-off cycles, a different time at weekends — one reminder
///    for each of the next doses that are actually due, as many as fit.
///
/// The third kind cannot repeat for ever, so it runs out: it is armed again at
/// every start of the app (and the app does so when it comes back to the
/// foreground), and a person who does not open it for as long as the doses armed
/// last will not be reminded after that. That is the price of a reminder that is
/// silent on the days it should be, and the only way an iPhone offers.
///
/// Pure: the schedule and the clock come in as arguments.
class IosDosePlan {
  IosDosePlan._();

  /// How far ahead a one-off plan looks for due days. Wide enough for a dose
  /// every month with room to spare; the count limit is what usually ends it.
  static const int horizonDays = 400;

  /// The reminders to hold for [schedule], soonest first, at most [maxCount].
  ///
  /// Empty for an as-needed medicine, one with no times, a course that is over, or
  /// a [maxCount] of nothing.
  static List<PlannedDose> plan(
    MedicineSchedule schedule, {
    required DateTime now,
    required int maxCount,
  }) {
    if (maxCount <= 0 || schedule.isPRN) return const [];
    if (schedule.frequencyType == FrequencyType.asNeeded) return const [];

    final today = DateTime(now.year, now.month, now.day);
    final startsToday = schedule.startDate == null ||
        !DateTime(schedule.startDate!.year, schedule.startDate!.month,
                schedule.startDate!.day)
            .isAfter(today);
    final open =
        schedule.isOngoing && startsToday && !schedule.hasWeekendOverride;

    if (open && _isDailyKind(schedule)) {
      final slots = _clockSlots(schedule, now);
      return [
        for (final s in slots.take(maxCount))
          PlannedDose(DoseRepeat.daily, _nextDaily(s.hour, s.minute, now)),
      ];
    }

    final days = schedule.specificDays;
    if (open &&
        schedule.frequencyType == FrequencyType.specificDays &&
        days != null &&
        days.isNotEmpty &&
        schedule.times.isNotEmpty) {
      final chosen = {...days}..removeWhere((d) => d < 1 || d > 7);
      if (chosen.isEmpty) return const [];
      // Every day of the week is just "every day".
      if (chosen.length == 7) {
        return [
          for (final t in schedule.times.take(maxCount))
            PlannedDose(DoseRepeat.daily, _nextDaily(t.hour, t.minute, now)),
        ];
      }
      // A repeating reminder that does not fit is not armed AT ALL — for ever — and
      // which ones were left out would change with the day the app was opened. So a
      // schedule with more weekday-and-time pairs than there is room for is armed as
      // the doses that are due next, like any other, and refreshed as they pass.
      if (chosen.length * schedule.times.length <= maxCount) {
        final due = <PlannedDose>[
          for (final t in schedule.times)
            for (final d in chosen)
              PlannedDose(DoseRepeat.weekly, _nextWeekly(d, t.hour, t.minute, now)),
        ]..sort((a, b) => a.at.compareTo(b.at));
        return due;
      }
    }

    // The next doses that are actually due, one reminder each.
    final upcoming = <PlannedDose>[];
    for (var i = 0; i <= horizonDays && upcoming.length < maxCount; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      // The dose's own clock time is kept beside the moment: on the day the clocks
      // skip a time they differ, and a "Take" is logged against the slot.
      final slots = [
        for (final t in schedule.clockTimesForDate(day))
          (
            at: DateTime(day.year, day.month, day.day, t.hour, t.minute),
            hour: t.hour,
            minute: t.minute,
          ),
      ]..sort((a, b) => a.at.compareTo(b.at));
      for (final slot in slots) {
        if (!slot.at.isAfter(now)) continue;
        upcoming.add(PlannedDose(DoseRepeat.once, slot.at,
            hour: slot.hour, minute: slot.minute));
        if (upcoming.length >= maxCount) break;
      }
    }
    return upcoming;
  }

  /// Whether the schedule is "some times, every day" — what repeating daily is for.
  static bool _isDailyKind(MedicineSchedule s) {
    switch (s.frequencyType) {
      case FrequencyType.onceDaily:
      case FrequencyType.twiceDaily:
      case FrequencyType.thriceDaily:
      case FrequencyType.fourTimesDaily:
        return s.times.isNotEmpty;
      case FrequencyType.everyXHours:
        // Even with no usable interval: it has no clock times then, so nothing is
        // armed — what it always did — rather than the fixed list being read as
        // a day-by-day schedule.
        return s.times.isNotEmpty;
      case FrequencyType.everyXDays:
      case FrequencyType.specificDays:
      case FrequencyType.asNeeded:
      case FrequencyType.cyclical:
        return false;
    }
  }

  /// The clock times a daily-kind schedule fires at: its own list, or — for "every
  /// X hours" — the anchor and every interval after it. On the schedule's own
  /// clock, not read back from today's DateTimes (see
  /// [MedicineSchedule.everyXHoursClockTimesOn]).
  static List<({int hour, int minute})> _clockSlots(
      MedicineSchedule s, DateTime now) {
    if (s.frequencyType == FrequencyType.everyXHours) {
      return s.everyXHoursClockTimesOn(now);
    }
    return [for (final t in s.times) (hour: t.hour, minute: t.minute)];
  }

  /// The next moment [hour]:[minute] comes round, today or after.
  ///
  /// A repeating reminder is anchored on this, and repeats at the anchor's own clock
  /// time, so the anchor must be a time that exists: a day on which the clocks skip
  /// it is passed over for the next day, not armed an hour late for good.
  static DateTime _nextDaily(int hour, int minute, DateTime now) {
    for (var d = 0; d < 4; d++) {
      final at = DateTime(now.year, now.month, now.day + d, hour, minute);
      if (_exists(at, hour, minute) && at.isAfter(now)) return at;
    }
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  static DateTime _nextWeekly(int weekday, int hour, int minute, DateTime now) {
    final ahead = (weekday - now.weekday) % 7;
    for (var w = 0; w < 4; w++) {
      final at = DateTime(now.year, now.month, now.day + ahead + 7 * w, hour, minute);
      if (_exists(at, hour, minute) && at.isAfter(now)) return at;
    }
    return DateTime(now.year, now.month, now.day + ahead + 7, hour, minute);
  }

  /// Whether [at], built from [hour]:[minute], is that time on the clock — it is
  /// not when the clocks skip it, and Dart has moved it forward.
  static bool _exists(DateTime at, int hour, int minute) =>
      at.hour == hour && at.minute == minute;
}
