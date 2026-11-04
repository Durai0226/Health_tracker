import 'package:health/health.dart';

import '../../biometrics/models/health_source.dart';
import '../../biometrics/services/health_source_registry.dart';

/// One day's steps from the single source the user's choices point at.
///
/// [steps] is null when every source that wrote steps is switched off — the
/// day must then be left as it was, not zeroed.
class StepChoice {
  final int? steps;

  /// 24 buckets, hour 0 first. Empty when [steps] is null.
  final List<int> hourly;

  const StepChoice(this.steps, this.hourly);
}

/// Applies Connected devices' "ignore this source" and "prefer this device" to
/// steps, which the health stores otherwise total across every source.
///
/// Steps are read as the platform's own de-duplicated sum (phone and watch
/// counted once). That sum cannot leave a source out, so a choice is honoured
/// the one way that cannot double count: read the raw records and total ONE
/// source's — the same no-mixing rule heart data follows.
abstract final class StepSourceChoice {
  /// Whether any choice exists that could change a day's total. When false the
  /// platform total is used as before and no raw read is made.
  static bool mayApply(Map<String, HealthSource> known) =>
      known.values.any((s) => s.priority > 0 || !s.enabled);

  /// The day's steps from the chosen source, or null when no choice touches
  /// these [points] and the platform's own total should stand.
  ///
  /// [points] are the raw step records for [day] (nothing but steps — that is
  /// all `readStepSamples` asks the store for). A choice "touches" them when
  /// the pinned device wrote some, or a switched-off source did.
  static StepChoice? resolve(
    List<HealthDataPoint> points,
    Map<String, HealthSource> known,
    DateTime day,
  ) {
    final usable = HealthSourceRegistry.usable(points, known);
    final pinned = HealthSourceRegistry.pinnedKeyIn(usable, known);
    final droppedSome = usable.length != points.length;
    if (pinned == null && !droppedSome) return null;
    if (usable.isEmpty) return const StepChoice(null, []);

    final String key;
    if (pinned != null) {
      key = pinned;
    } else {
      final winner = HealthSourceRegistry.pickWinner(
          HealthSourceRegistry.candidatesFrom(usable, known: known).values);
      key = winner!.id;
    }
    final chosen =
        usable.where((p) => HealthSourceRegistry.keyFor(p) == key).toList();

    final base = DateTime(day.year, day.month, day.day);
    final buckets = List<double>.filled(24, 0);
    var total = 0.0;
    for (final p in chosen) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final count = v.numericValue.toDouble();
      total += count;
      _spread(buckets, base, p.dateFrom, p.dateTo, count);
    }
    return StepChoice(total.round(), [for (final b in buckets) b.round()]);
  }

  /// Share one record's [count] across the hours of [base]'s day its span
  /// covers, in proportion to the time in each. A record that is an instant
  /// (or ends before it starts) lands whole in the hour it starts in.
  static void _spread(List<double> buckets, DateTime base, DateTime from,
      DateTime to, double count) {
    final span = to.difference(from).inMilliseconds;
    if (span <= 0) {
      final h = from.difference(base).inHours;
      if (h >= 0 && h < 24) buckets[h] += count;
      return;
    }
    for (var h = 0; h < 24; h++) {
      final start = base.add(Duration(hours: h));
      final end = start.add(const Duration(hours: 1));
      final lo = from.isAfter(start) ? from : start;
      final hi = to.isBefore(end) ? to : end;
      final overlap = hi.difference(lo).inMilliseconds;
      if (overlap > 0) buckets[h] += count * overlap / span;
    }
  }
}
