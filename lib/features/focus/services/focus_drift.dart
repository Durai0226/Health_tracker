/// Noticing when someone leaves the app in the middle of a focus round — and when
/// they do it at about the same minute, day after day.
///
/// Everything here is pure: no clock, no storage, no Flutter. `FocusService` feeds
/// it the two facts the OS gives (the app went away, the app came back) and keeps
/// what it returns; the Focus screen shows the result.
///
/// ## What this can and cannot know
///
/// The OS says the app was backgrounded. It does not say why. Switching to a
/// messaging app, the screen timing out and the power button all arrive as the
/// same lifecycle change, and the app never holds the screen awake. So this is
/// **leaving the app**, not "got distracted", and the screens say so. Most of the
/// rules below exist to keep the other explanations out of the count:
///
///  * **Only a round that is still running when they come back counts.** Phone
///    face-down, screen off, back at the end — which is exactly what the app asks
///    of someone, with its notification at the end of the round — is not a
///    distraction, and leaving a round to come back after it is over is that.
///  * **Away between [minAway] and [maxAway].** Shorter is a permission dialog or
///    a system overlay; longer is a phone put in a pocket.
///  * **Not in the first [minMinutes] minutes.** Tap Start and switch to the thing
///    you are working on, or the screen timeout (30 seconds to 5 minutes on most
///    phones), would otherwise be the loudest "pattern" every person has. A round
///    shorter than ten minutes is also not one anybody needs to be told to cut.
///  * **Not in the last tenth of the round.** Checking in near the end is not
///    drifting away from it.
///
/// And a pattern needs several days of agreement ([minEvents] times on
/// [minDays] different days, most of them within [spread] minutes of each other).
/// One bad afternoon is not a habit.
library;

import '../../../core/utils/calendar_day.dart';

/// One time somebody left the app mid-round and came back before the round ended.
class DriftEvent {
  const DriftEvent({
    required this.at,
    required this.minute,
    required this.plannedMinutes,
  });

  /// When they left, local time.
  final DateTime at;

  /// Whole minutes of focus done when they left. Time spent paused is not counted.
  final int minute;

  /// How long the round was meant to be.
  final int plannedMinutes;

  Map<String, dynamic> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'minute': minute,
        'planned': plannedMinutes,
      };

  /// The event [json] describes, or null if it does not describe one.
  ///
  /// These come back from a preference row and from backup files, and neither is
  /// trustworthy: a damaged or hand-edited entry must be dropped, not throw from
  /// inside `FocusService.init()`, which the whole app waits for.
  static DriftEvent? tryParse(Object? json) {
    if (json is! Map) return null;
    final at = json['at'];
    final minute = json['minute'];
    final planned = json['planned'];
    if (at is! num || minute is! num || planned is! num) return null;
    final m = minute.toInt();
    final p = planned.toInt();
    if (m < 0 || p <= 0 || m > p) return null;
    return DriftEvent(
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      minute: m,
      plannedMinutes: p,
    );
  }
}

/// The moment the app went to the background mid-round, held until it is known
/// whether the person came back in time for it to count.
class DriftLeave {
  const DriftLeave({
    required this.at,
    required this.elapsedSeconds,
    required this.plannedMinutes,
    required this.phaseKey,
  });

  final DateTime at;

  /// Seconds of focus done when they left, pauses excluded.
  final int elapsedSeconds;

  final int plannedMinutes;

  /// Identifies the round that was running, so a return into a different one (a
  /// new round after the phase changed) is not matched to this.
  final int phaseKey;

  /// What this becomes if the app is back at [now] — or null when it does not
  /// count.
  ///
  /// [remainingSeconds] is the time left in the round at [now]; zero or less means
  /// it ended while they were away.
  DriftEvent? returnedAt(
    DateTime now, {
    required int phaseKey,
    required int remainingSeconds,
  }) {
    if (phaseKey != this.phaseKey) return null;
    if (remainingSeconds <= 0) return null;
    final away = now.difference(at);
    if (away < DriftRules.minAway || away > DriftRules.maxAway) return null;
    return DriftEvent(
      at: at,
      minute: elapsedSeconds ~/ 60,
      plannedMinutes: plannedMinutes,
    );
  }
}

/// What counts as leaving.
abstract final class DriftRules {
  /// Shorter than this is not leaving: a permission dialog, a system sheet.
  static const Duration minAway = Duration(seconds: 5);

  /// Longer than this is a phone put down, not a glance at another app. Missing
  /// the odd long scroll is the right way to be wrong here.
  static const Duration maxAway = Duration(minutes: 10);

  /// Earliest minute that counts. See the library note.
  static const int minMinutes = 10;

  /// Past this share of the round, leaving is not drifting away from it.
  static const double maxProgress = 0.9;

  /// The hold for a departure at [now], or null when it could not count however
  /// it ends — so nothing is kept for a leave that will be thrown away.
  static DriftLeave? leaving({
    required DateTime now,
    required int phaseKey,
    required int elapsedSeconds,
    required int plannedMinutes,
  }) {
    if (plannedMinutes <= 0) return null;
    if (elapsedSeconds < minMinutes * 60) return null;
    if (elapsedSeconds >= plannedMinutes * 60 * maxProgress) return null;
    return DriftLeave(
      at: now,
      elapsedSeconds: elapsedSeconds,
      plannedMinutes: plannedMinutes,
      phaseKey: phaseKey,
    );
  }
}

/// The minute someone keeps leaving at.
class DriftPattern {
  const DriftPattern({
    required this.minute,
    required this.times,
    required this.days,
    required this.total,
  });

  /// The usual minute: the middle of those that agree.
  final int minute;

  /// How many departures agree on it.
  final int times;

  /// How many different days those were on.
  final int days;

  /// How many departures were looked at in all.
  final int total;

  /// A round that ends BEFORE the usual minute, in steps of five.
  ///
  /// Strictly before: rounding [minute] down put a person who usually leaves at
  /// minute 25 in front of a 25-minute round, which ends at the very minute they
  /// leave — about half the time, a round they would still be walking out of.
  ///
  /// Never under ten: [DriftRules.minMinutes] keeps [minute] at ten or more, and
  /// a block of focus shorter than that is not a suggestion.
  int get suggestedWorkMinutes {
    final w = ((minute - 1) ~/ 5) * 5;
    return w < 10 ? 10 : w;
  }

  /// The ordinary short break.
  int get suggestedBreakMinutes => 5;
}

/// Looks for a pattern in the departures.
abstract final class DriftAnalysis {
  /// Fewest departures that make a pattern.
  static const int minEvents = 5;

  /// Fewest different days they must be spread over.
  static const int minDays = 4;

  /// How many minutes either side of the usual one still count as agreeing.
  static const int spread = 3;

  /// The share of all departures that must agree.
  static const double minShare = 0.6;

  /// How far back is still how this person focuses.
  static const int windowDays = 45;

  /// The most departures kept. Oldest go first.
  static const int cap = 200;

  /// The pattern in [events] as of [now], or null when there is none yet.
  ///
  /// Silence is the right answer to too little: "you usually leave at minute 22"
  /// said from three afternoons is a guess in the voice of a fact.
  static DriftPattern? find(Iterable<DriftEvent> events, {required DateTime now}) {
    final since = dayOffset(now, -windowDays);
    final recent = [
      for (final e in events)
        if (!e.at.isBefore(since) && !e.at.isAfter(now)) e
    ];
    if (recent.length < minEvents) return null;

    // The densest stretch of `2 * spread + 1` minutes, centred on a departure.
    // Taking the overall median instead would land BETWEEN two habits (leaving at
    // 12 and at 22 gives a median of 17, where nobody ever leaves).
    List<DriftEvent>? best;
    for (final c in recent) {
      final inside = [
        for (final e in recent)
          if ((e.minute - c.minute).abs() <= spread) e
      ];
      if (best == null ||
          inside.length > best.length ||
          // Same size: the earlier minute, so a tie does not depend on the order
          // the events happen to be stored in.
          (inside.length == best.length &&
              _middle(inside) < _middle(best))) {
        best = inside;
      }
    }
    final found = best;
    if (found == null) return null;
    if (found.length < minEvents) return null;
    if (found.length < recent.length * minShare) return null;
    final days = {
      for (final e in found) (e.at.year, e.at.month, e.at.day),
    }.length;
    if (days < minDays) return null;

    return DriftPattern(
      minute: _middle(found),
      times: found.length,
      days: days,
      total: recent.length,
    );
  }

  /// The middle minute of [events], rounded to a whole one.
  static int _middle(List<DriftEvent> events) {
    final minutes = [for (final e in events) e.minute]..sort();
    final mid = minutes.length ~/ 2;
    return minutes.length.isOdd
        ? minutes[mid]
        : ((minutes[mid - 1] + minutes[mid]) / 2).round();
  }

  /// [events] with only the newest [cap] kept.
  static List<DriftEvent> capped(List<DriftEvent> events) =>
      events.length <= cap ? events : events.sublist(events.length - cap);
}
