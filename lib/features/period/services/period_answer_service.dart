import 'package:flutter/foundation.dart';

import '../../../core/services/nudge_answer_queues.dart';
import '../models/flow_intensity.dart';
import '../models/period_day.dart';
import 'period_service.dart';

/// A period start answered from the notification, now in the cycle log.
/// [previous] is the day as it was before, so Undo can put it back exactly.
typedef AppliedPeriodStart = ({DateTime date, PeriodDay? previous});

/// What a drain did.
class PeriodAnswerOutcome {
  const PeriodAnswerOutcome({this.applied = const [], this.tooSoon});

  final List<AppliedPeriodStart> applied;

  /// Set when a "Started today" was NOT written because it would begin a new
  /// period suspiciously soon after the last (the same check the Log sheet asks
  /// about): the number of days since that one began.
  final int? tooSoon;

  bool get isEmpty => applied.isEmpty && tooSoon == null;
}

/// Writes "Started today" answers from the period reminder.
class PeriodAnswers {
  const PeriodAnswers._();

  static bool _draining = false;

  /// The flow a start is logged with. Medium: it is a period starting, and the
  /// person can change it from the Period screen; spotting would not start one.
  static const FlowIntensity startFlow = FlowIntensity.medium;

  static Future<PeriodAnswerOutcome> drainPending() async {
    if (_draining) return const PeriodAnswerOutcome();
    _draining = true;
    try {
      final pending = await PeriodStartQueue.drain();
      final applied = <AppliedPeriodStart>[];
      int? tooSoon;
      for (final p in pending) {
        try {
          final date = DateTime(p.at.year, p.at.month, p.at.day);
          final existing = PeriodService.getDay(date);
          if (existing != null && existing.isBleeding) {
            // Already logged (by hand, or by an earlier tap): nothing to add.
            await PeriodStartQueue.ack([p]);
            continue;
          }
          final soon = PeriodService.newPeriodTooSoon(date, startFlow.flowIndex);
          if (soon != null) {
            // The Log sheet asks before starting a period this soon; a button
            // cannot ask, so it leaves it to the person and says so.
            tooSoon = soon;
            await PeriodStartQueue.ack([p]);
            continue;
          }
          await PeriodService.logDay(
              (existing ?? PeriodDay.empty(date)).copyWith(flowIndex: startFlow.flowIndex));
          applied.add((date: date, previous: existing));
          await PeriodStartQueue.ack([p]);
        } catch (e) {
          debugPrint('⚠️ applying a queued period start failed: $e');
        }
      }
      return PeriodAnswerOutcome(applied: applied, tooSoon: tooSoon);
    } finally {
      _draining = false;
    }
  }

  static Future<void> undo(Iterable<AppliedPeriodStart> applied) async {
    for (final a in applied) {
      final before = a.previous;
      if (before == null) {
        await PeriodService.deleteDay(PeriodDay.keyFor(a.date));
      } else {
        await PeriodService.logDay(before);
      }
    }
  }
}
