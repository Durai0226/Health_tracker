import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/models/period_reminder_config.dart';
import 'package:tablet_remainder/features/period/models/period_settings.dart';
import 'package:tablet_remainder/features/period/services/period_reminder_service.dart';

/// QA — Period reminder planner + config (the new feature). Pure: no I/O.
void main() {
  final now = DateTime(2026, 6, 1, 8, 0);

  CyclePrediction pred({
    DateTime? start,
    DateTime? fertile,
    CycleState state = CycleState.ready,
  }) =>
      CyclePrediction(predictedStart: start, fertileStart: fertile, state: state);

  const allOn = PeriodReminderConfig(
    periodSoonEnabled: true,
    daysBefore: 2,
    pmsEnabled: true,
    pmsDaysBefore: 3,
    logReminderEnabled: true,
    fertileEnabled: true,
    reminderHour: 9,
    reminderMinute: 0,
  );

  List<PlannedReminder> plan(
    CyclePrediction p,
    TrackingMode mode, {
    PeriodReminderConfig config = allOn,
  }) =>
      PeriodReminderPlanner.plan(
          prediction: p, mode: mode, config: config, now: now);

  PlannedReminder? byTitle(List<PlannedReminder> xs, String t) {
    for (final r in xs) {
      if (r.title == t) return r;
    }
    return null;
  }

  group('PeriodReminderConfig JSON round-trip', () {
    test('fromJson(toJson()) preserves every field', () {
      final restored = PeriodReminderConfig.fromJson(allOn.toJson());
      expect(restored.periodSoonEnabled, isTrue);
      expect(restored.daysBefore, 2);
      expect(restored.pmsEnabled, isTrue);
      expect(restored.pmsDaysBefore, 3);
      expect(restored.logReminderEnabled, isTrue);
      expect(restored.fertileEnabled, isTrue);
      expect(restored.reminderHour, 9);
    });
    test('defaults are all off', () {
      expect(PeriodReminderConfig.defaults.anyEnabled, isFalse);
    });
  });

  group('planner — positive', () {
    test('tracking mode emits period-soon + pms + log (no fertile)', () {
      final out = plan(pred(start: DateTime(2026, 6, 20)), TrackingMode.tracking);
      expect(out.length, 3);
      expect(byTitle(out, 'Fertile window'), isNull);
    });

    test('period-soon fires daysBefore before the predicted start at the set time', () {
      final out = plan(pred(start: DateTime(2026, 6, 20)), TrackingMode.tracking);
      final soon = byTitle(out, 'Cycle check-in');
      expect(soon, isNotNull);
      expect(soon!.date, DateTime(2026, 6, 18, 9, 0)); // 20th − 2 days @ 09:00
    });

    test('TTC mode adds the fertile-window reminder', () {
      final out = plan(
        pred(start: DateTime(2026, 6, 20), fertile: DateTime(2026, 6, 6)),
        TrackingMode.ttc,
      );
      final fertile = byTitle(out, 'Fertile window');
      expect(fertile, isNotNull);
      expect(fertile!.date, DateTime(2026, 6, 5, 9, 0)); // fertileStart − 1
    });
  });

  group('planner — negative / guards', () {
    test('pregnancy mode never nudges', () {
      expect(plan(pred(start: DateTime(2026, 6, 20)), TrackingMode.pregnancy), isEmpty);
    });
    test('onboarding (no predicted start) → empty', () {
      expect(plan(pred(start: null, state: CycleState.onboarding), TrackingMode.tracking), isEmpty);
    });
    test('all reminders disabled → empty', () {
      expect(
          plan(pred(start: DateTime(2026, 6, 20)), TrackingMode.tracking,
              config: PeriodReminderConfig.defaults),
          isEmpty);
    });
    test('a predicted start already in the past → nothing armed', () {
      expect(plan(pred(start: DateTime(2026, 5, 1)), TrackingMode.tracking), isEmpty);
    });
    test('fertile not emitted outside TTC even when enabled', () {
      final out = plan(
        pred(start: DateTime(2026, 6, 20), fertile: DateTime(2026, 6, 6)),
        TrackingMode.tracking,
      );
      expect(byTitle(out, 'Fertile window'), isNull);
    });
  });
}
