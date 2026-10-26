/// What a person usually drinks around this time of day.
///
/// "Your usual, one tap": at 8am it is the 200 ml coffee, at 3pm the 500 ml
/// bottle of water. Worked out from the person's own past days — never a
/// guess, and never offered until a habit is real: the same drink in the same
/// amount on at least three separate days, and the most common of what they
/// have around this hour.
///
/// Alcoholic drinks are left out entirely. A hydration app should log a beer
/// when asked, but it should not put one a tap away because it was a habit.
library;

import 'package:flutter/foundation.dart';

/// The fields of a past drink this needs, so the rule does not depend on the
/// water feature's models.
@immutable
class PastDrink {
  final DateTime time;
  final String beverageId;
  final String name;
  final int amountMl;
  final bool isAlcoholic;
  const PastDrink({
    required this.time,
    required this.beverageId,
    required this.name,
    required this.amountMl,
    this.isAlcoholic = false,
  });
}

@immutable
class UsualDrink {
  final String beverageId;
  final String name;
  final int amountMl;

  /// Separate days this exact drink was logged in the window.
  final int days;

  const UsualDrink({
    required this.beverageId,
    required this.name,
    required this.amountMl,
    required this.days,
  });
}

class UsualDrinkCalc {
  const UsualDrinkCalc._();

  /// How far either side of the current time of day still counts as "this hour".
  static const int windowMinutes = 90;

  /// How far back habits are read from.
  static const int lookbackDays = 30;

  /// The same drink on this many separate days before it is called usual.
  static const int minDays = 3;

  /// ...and on at least this share of the days they drank anything in the window.
  /// A coffee on 3 of 20 days is not "your usual".
  static const double minShare = 0.4;

  /// The usual drink at [now], from [past] drinks, or null when there is none.
  ///
  /// Only days before today count, so logging a drink never makes it more
  /// "usual" on the day it happens, and only the last [lookbackDays].
  static UsualDrink? at(DateTime now, Iterable<PastDrink> past) {
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(now.year, now.month, now.day - lookbackDays);
    final nowMin = now.hour * 60 + now.minute;

    final windowDays = <DateTime>{};
    // (beverage, amount) -> separate days, plus a sample for the display fields.
    final days = <String, Set<DateTime>>{};
    final sample = <String, PastDrink>{};
    final latest = <String, DateTime>{};

    for (final d in past) {
      final day = DateTime(d.time.year, d.time.month, d.time.day);
      if (!day.isBefore(today) || day.isBefore(from)) continue;
      if (d.isAlcoholic || d.amountMl <= 0) continue;
      if (_gap(d.time.hour * 60 + d.time.minute, nowMin) > windowMinutes) continue;

      windowDays.add(day);
      final key = '${d.beverageId}|${d.amountMl}';
      (days[key] ??= <DateTime>{}).add(day);
      if (latest[key] == null || d.time.isAfter(latest[key]!)) {
        latest[key] = d.time;
        sample[key] = d;
      }
    }
    if (days.isEmpty) return null;

    String? best;
    for (final key in days.keys) {
      if (best == null) {
        best = key;
        continue;
      }
      final a = days[key]!.length, b = days[best]!.length;
      if (a > b || (a == b && latest[key]!.isAfter(latest[best]!))) best = key;
    }

    final n = days[best]!.length;
    if (n < minDays || n / windowDays.length < minShare) return null;
    final s = sample[best]!;
    return UsualDrink(
      beverageId: s.beverageId,
      name: s.name,
      amountMl: s.amountMl,
      days: n,
    );
  }

  /// Distance between two times of day in minutes, the short way round midnight.
  static int _gap(int a, int b) {
    final d = (a - b).abs();
    return d > 720 ? 1440 - d : d;
  }
}
