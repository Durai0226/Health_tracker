/// "Rain from 6 pm — 4–6 pm looks dry for a walk." Only when steps are behind.
///
/// A tip, not a nudge: it is shown on the Steps screen when the person is short
/// of where they would usually be by now AND the forecast has rain in the hours
/// left AND there is a dry stretch to point at. A day with no rain, or a person
/// on pace, gets nothing. It says "looks dry" — a forecast is a guess.
library;

import 'dry_window.dart';

class WalkWeatherTips {
  const WalkWeatherTips._();

  /// Behind means under this share of where an even pace through the waking day
  /// would have them by now. Generous: the tip is for someone clearly short, not
  /// for a minute behind.
  static const double behindFraction = 0.8;

  /// Whether [steps] is clearly short of an even spread of [goal] across the
  /// waking day ([DryWindows.firstHour] to [DryWindows.lastHour]) at [nowMinute].
  /// False with no goal, with the goal met (it is more than any share of itself),
  /// or before the day has started.
  static bool behindPace({
    required int steps,
    required int goal,
    required int nowMinute,
  }) {
    if (goal <= 0) return false;
    const start = DryWindows.firstHour * 60;
    const end = DryWindows.lastHour * 60;
    if (nowMinute <= start) return false;
    final elapsed = ((nowMinute - start) / (end - start)).clamp(0.0, 1.0);
    return steps < goal * elapsed * behindFraction;
  }

  /// "6 pm", "12 pm", "12 am" for an hour of the day (0–24).
  static String hourLabel(int hour) {
    final h = hour % 24;
    final n = h % 12 == 0 ? 12 : h % 12;
    return '$n ${h < 12 ? 'am' : 'pm'}';
  }

  /// "4–6 pm", or "11 am–1 pm" when the two ends are either side of noon.
  static String rangeLabel(int from, int to) {
    String meridiem(int h) => h % 24 < 12 ? 'am' : 'pm';
    int twelve(int h) => h % 12 == 0 ? 12 : h % 12;
    return meridiem(from) == meridiem(to)
        ? '${twelve(from)}–${twelve(to)} ${meridiem(to)}'
        : '${hourLabel(from)}–${hourLabel(to)}';
  }

  /// The tip in words.
  static String say(DryWindow w) {
    final range = rangeLabel(w.fromHour, w.toHour);
    return w.rainingNow
        ? 'Rain until ${hourLabel(w.rainHour)} — $range looks dry for a walk.'
        : 'Rain from ${hourLabel(w.rainHour)} — $range looks dry for a walk.';
  }
}
