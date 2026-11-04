import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/vacation_mode.dart';
import '../../steps/models/step_daily_data.dart';
import '../../steps/services/step_service.dart';
import '../models/reminder_model.dart';
import '../models/reminder_step_targets.dart';
import '../utils/reminder_occurrence.dart';
import 'reminder_alarm.dart';
import 'reminder_completion.dart';

/// "Walk 20 min" ticks itself off when the steps show up.
///
/// A reminder can be set to wait for a number of steps; once today's steps
/// reach it, and the reminder has come due today, it is marked done exactly as
/// if its Done had been tapped — through [ReminderCompletion], so the occurrence
/// log, the next time and what is armed all follow the one rule.
///
/// What it deliberately does not do:
///  * It never ticks a reminder that has not come due yet. A person who has
///    already walked still gets the reminder at its time; ticking early would
///    mean withdrawing an alarm they set, and is not what "ticks itself off
///    when the steps show up" promises.
///  * It never ticks a reminder from an earlier day because of today's steps: an
///    "overdue since yesterday" walk was not done by walking today.
///  * Nothing on vacation: the Reminders feature is paused then.
///  * Only reminders that opted in.
class ReminderAutoComplete {
  const ReminderAutoComplete._();

  /// What the occurrence log records as having ticked it, beside 'app' and
  /// 'notification'.
  static const String source = 'steps';

  /// Whether [reminder] should be ticked off now by [steps] taken today.
  static bool isDue(Reminder reminder,
      {required int steps, required DateTime now}) {
    final need = ReminderStepTargets.clean(reminder.autoCompleteSteps);
    if (need == null || reminder.isCompleted || reminder.isPaused) return false;
    if (steps < need) return false;

    final occurrence = resolveReminderOccurrence(reminder, now: now);
    if (occurrence.isAfter(now)) return false;
    return occurrence.year == now.year &&
        occurrence.month == now.month &&
        occurrence.day == now.day;
  }

  /// Tick off every reminder [isDue] says is done. Returns how many.
  ///
  /// [steps] defaults to today's total on the Steps screen. One reminder that
  /// fails does not stop the others.
  static Future<int> run({
    DateTime? now,
    int? steps,
    List<Reminder>? reminders,
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    final t = now ?? clock.now();
    if (VacationMode.isActive(now: t)) return 0;
    final taken = steps ?? StepService.getTodayData().effectiveSteps;

    var ticked = 0;
    for (final r in reminders ?? CleanStorageService.getReminders()) {
      if (!isDue(r, steps: taken, now: t)) continue;
      try {
        final done = await ReminderCompletion.markDone(r,
            now: t, source: source, alarm: alarm);
        if (done != null) ticked++;
      } catch (e) {
        debugPrint('⚠️ Auto-completing "${r.title}" from steps failed: $e');
      }
    }
    return ticked;
  }
}

/// Runs [ReminderAutoComplete] whenever the day's steps change.
///
/// Steps land from the sensor, from a health-app sync and by hand; all of them
/// move the same notifier, so one listener covers them. A burst of changes is
/// folded into one pass a few seconds after the last.
class ReminderAutoCompleteWatcher {
  const ReminderAutoCompleteWatcher._();

  static ValueListenable<Map<String, StepDailyData>>? _days;
  static Timer? _timer;

  @visibleForTesting
  static Duration quietFor = const Duration(seconds: 3);

  @visibleForTesting
  static Future<int> Function() runPass = ReminderAutoComplete.run;

  static void start() {
    stop();
    _days = StepService.listenToDailyData()?..addListener(_changed);
    // A pass now, for steps that landed before the listener did.
    _changed();
  }

  static void stop() {
    _days?.removeListener(_changed);
    _days = null;
    _timer?.cancel();
    _timer = null;
  }

  static void _changed() {
    _timer?.cancel();
    _timer = Timer(quietFor, () => unawaited(_pass()));
  }

  static Future<void> _pass() async {
    try {
      await runPass();
    } catch (e) {
      debugPrint('⚠️ Reminder auto-complete pass failed: $e');
    }
  }
}
