import 'package:clock/clock.dart';
import 'package:health/health.dart';

import '../models/flow_intensity.dart';
import '../models/period_day.dart';
import 'cycle_predictor.dart';
import 'period_service.dart';

/// One day of bleeding read from a health app.
class ImportedFlowDay {
  const ImportedFlowDay(this.day, this.flow);

  /// Local calendar day, at midnight.
  final DateTime day;
  final FlowIntensity flow;

  String get id => PeriodDay.keyFor(day);
}

/// What an import would do, worked out before anything is written.
class CycleImportPlan {
  const CycleImportPlan({
    required this.toAdd,
    required this.alreadyLogged,
    required this.periods,
  });

  /// Days with nothing logged for flow yet, oldest first.
  final List<ImportedFlowDay> toAdd;

  /// Days the health app has that this app already has a flow for. They are left
  /// exactly as the person logged them.
  final int alreadyLogged;

  /// How many separate periods [toAdd] makes up.
  final int periods;

  bool get isEmpty => toAdd.isEmpty;
}

/// Bringing a person's past periods in from Health Connect or Apple Health, so the
/// predictions start with history instead of learning from the first cycle.
///
/// Pure and testable: this works on the health plugin's data points and the days
/// already logged. Reading them (and the permission that needs) is the platform's
/// part, in `HealthDataService`.
class CycleHistoryImport {
  const CycleHistoryImport._();

  /// How far back to read: two years is the history the predictor can use, and
  /// what a person means by "my past periods".
  static const Duration lookback = Duration(days: 730);

  /// How a health app's flow level reads in this app.
  ///
  /// "Unspecified" is bleeding with no level recorded, imported as Medium: the
  /// middle, rather than a Light that would under-report it. `none` is not
  /// bleeding and is dropped by the caller.
  static FlowIntensity? flowFor(MenstrualFlow? flow) {
    switch (flow) {
      case null:
      case MenstrualFlow.none:
        return null;
      case MenstrualFlow.spotting:
        return FlowIntensity.spotting;
      case MenstrualFlow.light:
        return FlowIntensity.light;
      case MenstrualFlow.medium:
      case MenstrualFlow.unspecified:
        return FlowIntensity.medium;
      case MenstrualFlow.heavy:
        return FlowIntensity.heavy;
    }
  }

  /// The bleeding days in [samples], oldest first, one per local calendar day with
  /// the strongest level that day had.
  ///
  /// Samples that are not menstrual flow, record no bleeding, fall outside the
  /// [lookback] window or lie in the future are dropped — a day not yet lived
  /// cannot have bled.
  static List<ImportedFlowDay> daysFrom(
    Iterable<HealthDataPoint> samples, {
    DateTime? now,
  }) {
    final today = _day(now ?? clock.now());
    final first = today.subtract(lookback);
    final strongest = <DateTime, FlowIntensity>{};
    for (final p in samples) {
      final v = p.value;
      if (v is! MenstruationFlowHealthValue) continue;
      final flow = flowFor(v.flow);
      if (flow == null) continue;
      final day = _day(p.dateFrom);
      if (day.isBefore(first) || day.isAfter(today)) continue;
      final seen = strongest[day];
      if (seen == null || flow.index > seen.index) strongest[day] = flow;
    }
    return [
      for (final e in strongest.entries) ImportedFlowDay(e.key, e.value)
    ]..sort((a, b) => a.day.compareTo(b.day));
  }

  /// What importing [days] would add, given the days already logged by id.
  ///
  /// A day that already has a flow is the person's own record and is never
  /// replaced; a day logged for something else (a symptom, a note) with no flow
  /// gets the flow added and keeps the rest.
  static CycleImportPlan plan(
    List<ImportedFlowDay> days,
    Map<String, PeriodDay> existing,
  ) {
    final add = <ImportedFlowDay>[];
    var kept = 0;
    for (final d in days) {
      final have = existing[d.id];
      if (have != null && have.isBleeding) {
        kept++;
      } else {
        add.add(d);
      }
    }
    final runs = CyclePredictor.deriveCycles(
        [for (final d in add) FlowDay(d.day, d.flow.flowIndex)]);
    return CycleImportPlan(
      toAdd: add,
      alreadyLogged: kept,
      periods: runs.length,
    );
  }

  /// [plan]'s days as the days to write: each [PeriodDay] is whatever was logged
  /// for that date with the flow set.
  static List<PeriodDay> daysToWrite(
    CycleImportPlan plan,
    Map<String, PeriodDay> existing,
  ) =>
      [
        for (final d in plan.toAdd)
          (existing[d.id] ?? PeriodDay.empty(d.day))
              .copyWith(flowIndex: d.flow.flowIndex),
      ];

  /// Write [plan]: each day gets its flow, anything else logged for it kept. What
  /// each day was before is returned, so the import can be taken back.
  ///
  /// The plan is checked again against the days as they are NOW: the confirmation
  /// can sit open while the person logs a day, and a flow they typed in meanwhile
  /// is theirs, not the import's to replace.
  static Future<CycleImportResult> apply(CycleImportPlan plan) async {
    final before = PeriodService.days;
    final write = daysToWrite(CycleHistoryImport.plan(plan.toAdd, before), before);
    final prior = <String, PeriodDay?>{for (final w in write) w.id: before[w.id]};
    await PeriodService.setDays({for (final w in write) w.id: w});
    return CycleImportResult(prior);
  }

  /// Put every day [result] touched back as it was: a day that did not exist is
  /// removed, one that did is written back with its own data.
  static Future<void> undo(CycleImportResult result) =>
      PeriodService.setDays(result.prior);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// What an import changed, by day id: the day as it was before (null if there was
/// none). The Undo of an import.
class CycleImportResult {
  const CycleImportResult(this.prior);

  final Map<String, PeriodDay?> prior;

  int get days => prior.length;
}
