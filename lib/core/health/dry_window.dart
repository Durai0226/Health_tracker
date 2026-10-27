/// "Rain from 6 pm — 4–5 pm looks dry."
///
/// Pure Dart over an hourly chance-of-rain forecast for today. It looks for the
/// first stretch of dry hours still ahead and, when rain is coming (or here),
/// says where it is. It says nothing on a day with no rain in the hours left:
/// a tip to walk in the dry is only worth giving when the weather is a reason.
///
/// A forecast is a guess. The words it feeds say "looks dry", never "will be".
library;

class DryWindow {
  const DryWindow({
    required this.fromHour,
    required this.toHour,
    required this.rainHour,
    required this.rainingNow,
  });

  /// The dry stretch worth walking in: [fromHour] up to, not including,
  /// [toHour] (hours, 0–24).
  final int fromHour;
  final int toHour;

  /// When it is [rainingNow], the hour the rain is expected to ease; otherwise
  /// the hour rain next arrives.
  final int rainHour;

  /// Whether the current hour is itself wet.
  final bool rainingNow;

  @override
  bool operator ==(Object other) =>
      other is DryWindow &&
      other.fromHour == fromHour &&
      other.toHour == toHour &&
      other.rainHour == rainHour &&
      other.rainingNow == rainingNow;

  @override
  int get hashCode => Object.hash(fromHour, toHour, rainHour, rainingNow);

  @override
  String toString() =>
      'DryWindow($fromHour–$toHour, rain: $rainHour, now: $rainingNow)';
}

class DryWindows {
  const DryWindows._();

  /// A chance of rain at or above this, in percent, counts as wet.
  static const int wetAt = 50;

  /// Below this counts as dry. Between the two is "maybe": neither wet enough to
  /// avoid nor dry enough to promise.
  static const int dryBelow = 30;

  /// The waking hours a walk can fall in.
  static const int firstHour = 7;
  static const int lastHour = 21;

  /// The most of a dry stretch that is suggested: a walk, not the whole afternoon.
  static const int maxWindowHours = 2;

  /// The earliest dry stretch left today, when rain makes it worth mentioning;
  /// null otherwise (no rain in the hours that are left, or no dry stretch to
  /// point at).
  ///
  /// [hourly] is the chance of rain (0–100) for each hour of today, index 0 being
  /// midnight; an hour with no forecast is null. [nowHour] and [nowMinute] say
  /// where in the day it is: from the half hour on, the current hour is as good
  /// as gone.
  static DryWindow? find(
    List<int?> hourly, {
    required int nowHour,
    required int nowMinute,
    int minHours = 1,
  }) {
    if (hourly.length < 24) return null;
    final start = nowMinute >= 30 ? nowHour + 1 : nowHour;
    final from = start < firstHour ? firstHour : start;
    if (from >= lastHour) return null;

    bool wet(int h) => (hourly[h] ?? 0) >= wetAt;
    bool dry(int h) {
      final v = hourly[h];
      return v != null && v < dryBelow;
    }

    // Rain only matters if it is in the hours that are left.
    int? firstWet;
    for (var h = from; h < lastHour; h++) {
      if (wet(h)) {
        firstWet = h;
        break;
      }
    }
    if (firstWet == null) return null;
    final rainingNow = firstWet == from;

    // When raining: the first hour it is no longer wet. Otherwise: when it starts.
    var rainHour = firstWet;
    if (rainingNow) {
      rainHour = from;
      while (rainHour < lastHour && wet(rainHour)) {
        rainHour++;
      }
    }

    // The earliest run of dry hours, once the rain has eased if it is raining.
    var h = rainingNow ? rainHour : from;
    while (h < lastHour) {
      if (!dry(h)) {
        h++;
        continue;
      }
      var end = h;
      while (end < lastHour && dry(end)) {
        end++;
      }
      if (end - h >= minHours) {
        return DryWindow(
          fromHour: h,
          toHour: end - h > maxWindowHours ? h + maxWindowHours : end,
          rainHour: rainHour,
          rainingNow: rainingNow,
        );
      }
      h = end;
    }
    return null;
  }
}
