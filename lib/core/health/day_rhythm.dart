/// The shape of a typical day, counted from when the person wakes.
///
/// "Groggy until about 7:30, best for focus 9–11:30, a dip after lunch, a second
/// wind around 5, wind down from 9:30." A general pattern — the hours after
/// waking at which most people are sharpest, flattest, brightest again — laid
/// against the person's own wake time and bedtime. It is NOT measured from them
/// and is never presented as if it were: people differ, and so do days. It says
/// "typically".
///
/// Pure Dart. Times are minutes since midnight and may run past 1440 (a late
/// bedtime lands after midnight); [DayRhythm.clock] turns one back into a time of
/// day.
library;

enum RhythmPhase {
  /// The first hour after waking: sleep inertia, the groggy stretch.
  waking,

  /// Alertness climbing.
  warmingUp,

  /// The mid-morning peak most people report for concentration.
  focus,

  /// The post-lunch lull.
  dip,

  /// The late-afternoon lift.
  secondWind,

  /// The hour or so before bed.
  windDown,
}

class RhythmSpan {
  const RhythmSpan(this.phase, this.start, this.end);

  final RhythmPhase phase;

  /// Minutes since midnight of the day the person woke; [end] may exceed 1440.
  final int start;
  final int end;

  int get minutes => end - start;

  @override
  bool operator ==(Object other) =>
      other is RhythmSpan &&
      other.phase == phase &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(phase, start, end);

  @override
  String toString() => 'RhythmSpan(${phase.name} $start–$end)';
}

class DayRhythm {
  const DayRhythm._();

  /// Where each phase sits, in minutes after waking.
  static const int wakingEnd = 60;
  static const int warmingUpEnd = 150;
  static const int focusEnd = 300;
  static const int dipStart = 420;
  static const int dipEnd = 540;
  static const int secondWindEnd = 720;

  /// How long before bed the wind-down begins, and the most it is given.
  static const int windDownMinutes = 90;

  /// A day shorter than this is not a rhythm: a wake time and a bedtime six
  /// hours apart say something has gone wrong with one of them.
  static const int minAwakeMinutes = 10 * 60;

  /// The phases of the day that starts at [wakeMinute], ending at [bedMinute]
  /// (minutes since midnight; at or before the wake time means after midnight).
  ///
  /// Null without a usable day: no wake time, or fewer than [minAwakeMinutes]
  /// awake. Phases that would begin at or after bedtime are left out and the last
  /// one is cut short at it.
  static List<RhythmSpan>? of({required int? wakeMinute, required int? bedMinute}) {
    if (wakeMinute == null || bedMinute == null) return null;
    final bed = bedMinute > wakeMinute ? bedMinute : bedMinute + 1440;
    if (bed - wakeMinute < minAwakeMinutes) return null;

    final windDownStart = bed - windDownMinutes;
    final raw = <RhythmSpan>[
      RhythmSpan(RhythmPhase.waking, wakeMinute, wakeMinute + wakingEnd),
      RhythmSpan(RhythmPhase.warmingUp, wakeMinute + wakingEnd, wakeMinute + warmingUpEnd),
      RhythmSpan(RhythmPhase.focus, wakeMinute + warmingUpEnd, wakeMinute + focusEnd),
      RhythmSpan(RhythmPhase.dip, wakeMinute + dipStart, wakeMinute + dipEnd),
      RhythmSpan(RhythmPhase.secondWind, wakeMinute + dipEnd, wakeMinute + secondWindEnd),
      RhythmSpan(RhythmPhase.windDown, windDownStart, bed),
    ];

    // Whatever runs into the wind-down is cut short at it, and whatever would
    // start inside it is lost to it (its end is then not after its start).
    final out = <RhythmSpan>[];
    for (final s in raw) {
      final end = s.phase == RhythmPhase.windDown || s.end <= windDownStart
          ? s.end
          : windDownStart;
      if (end > s.start) out.add(RhythmSpan(s.phase, s.start, end));
    }
    return out;
  }

  /// A time of day (minutes since midnight, possibly past 1440) as 0–1439.
  static int clock(int minutes) => minutes % 1440;

  /// The words for a phase, plain and tentative.
  static String label(RhythmPhase p) {
    switch (p) {
      case RhythmPhase.waking:
        return 'Waking up';
      case RhythmPhase.warmingUp:
        return 'Warming up';
      case RhythmPhase.focus:
        return 'Often best for focus';
      case RhythmPhase.dip:
        return 'Usual afternoon dip';
      case RhythmPhase.secondWind:
        return 'Second wind';
      case RhythmPhase.windDown:
        return 'Wind down';
    }
  }

  /// One short line of what the phase is, for under its label.
  static String note(RhythmPhase p) {
    switch (p) {
      case RhythmPhase.waking:
        return 'Groggy for a while is normal; light and water help.';
      case RhythmPhase.warmingUp:
        return 'Alertness is building. Good for easy tasks.';
      case RhythmPhase.focus:
        return 'A good time for the thing that needs thinking.';
      case RhythmPhase.dip:
        return 'Energy often sags after lunch. A short walk can help.';
      case RhythmPhase.secondWind:
        return 'Many people feel a lift late in the afternoon.';
      case RhythmPhase.windDown:
        return 'Dim the lights and slow down ahead of bed.';
    }
  }
}
