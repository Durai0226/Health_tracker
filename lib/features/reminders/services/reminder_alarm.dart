import 'package:flutter/foundation.dart';

import '../../../core/database/daos/reminders_dao.dart'
    show genericReminderFollowUpOffset;
import '../../../core/services/background_alarm_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/reminder_model.dart';
import 'package:clock/clock.dart';
import '../utils/reminder_helper.dart';
import '../../../core/services/vacation_mode.dart';

/// What to arm. A value type rather than a long parameter list, so adding a
/// field later does not break every implementation and every call site.
@immutable
class ReminderArmRequest {
  const ReminderArmRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    required this.repeatType,
    this.priority = ReminderPriority.medium,
    this.customDays,
    this.snoozeDuration,
    this.sound,
    this.escalation = ReminderEscalation.standard,
    this.reminderId,
    this.recurrenceRule,
    this.endsAt,
    this.isPaused = false,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final RepeatType repeatType;
  final ReminderPriority priority;
  final List<int>? customDays;
  final int? snoozeDuration;
  final String? sound;

  /// How insistent this reminder is. Drives whether a follow-up is armed
  /// alongside the reminder itself.
  final ReminderEscalation escalation;

  /// The owning reminder's id, needed to key the follow-up's resolved flag.
  /// Null for callers that do not want a follow-up.
  final String? reminderId;

  /// RFC 5545 rule, when the reminder has one. Smart Add produces these
  /// ("every 3 days" → `RRULE:FREQ=DAILY;INTERVAL=3`) with `repeatType` left
  /// at `none`.
  final String? recurrenceRule;

  /// Hard stop. `RepeatType.daily` + an `endsAt` used to be armed as a
  /// self-rescheduling native daily alarm, which has no notion of an end.
  final DateTime? endsAt;

  /// Paused reminders must not be armed at all.
  final bool isPaused;

  /// Whether this reminder's schedule is something the native repeating
  /// registration can express.
  ///
  /// It cannot express an RRULE, and it cannot express an end — a daily
  /// AlarmManager alarm reschedules itself forever. Anything with a rule or a
  /// bound is therefore armed as a ONE-SHOT at its next occurrence, and the
  /// app-start / resume re-arm pass (and the roll-forward after a manual tick)
  /// advances it. Everything else keeps the cheaper native repeat.
  bool get needsPerOccurrenceArming =>
      recurrenceRule != null || endsAt != null;

  /// The request that arms [reminder]'s NEXT occurrence, or null when there is
  /// nothing left to arm (paused, past its `endsAt`, or a rule that has run
  /// out).
  ///
  /// This is the decision `scheduleGenericReminder` could never make: it
  /// understood only the six-value `RepeatType` and had no parameter for
  /// `recurrenceRule`, `endsAt` or `isPaused`, so Smart Add's
  /// `RRULE:FREQ=DAILY;INTERVAL=3` (written with `repeat` left at `none`) was
  /// armed as a one-shot and then retired, while `daily` + `endsAt` was armed
  /// as a native daily alarm that outlived its own end date.
  ///
  /// Deliberately here rather than inside [ReminderAlarm.arm]: choosing WHEN a
  /// reminder fires is scheduling policy, and the alarm is the OS adapter that
  /// arms what it is told. Keeping the two apart is also what lets a recording
  /// alarm assert the decision in a headless test.
  static ReminderArmRequest? forNextOccurrence(Reminder reminder) {
    if (reminder.isPaused) return null;
    // On vacation nothing in the Reminders feature fires. Null is the same
    // answer a paused reminder gets — "nothing to arm right now" — which every
    // caller already handles by disarming. They are armed again by the re-arm
    // pass once the vacation is over. (Medicine reminders do not come through
    // here, and are deliberately never paused.)
    if (VacationMode.isActive()) return null;

    final needsPerOccurrence =
        reminder.recurrenceRule != null || reminder.endsAt != null;

    var fireTime = reminder.scheduledTime;
    if (needsPerOccurrence) {
      if (reminder.scheduledTime.isAfter(clock.now())) {
        // Its own time has not come yet, so THAT is the next occurrence.
        //
        // `nextOccurrenceFrom` answers "the first occurrence strictly AFTER the
        // one that is current" — right for rolling forward from a tick or from
        // a stale anchor, wrong here. Asked about a reminder due at 18:00 today
        // it said tomorrow, so a daily-until reminder never fired on its first
        // day, a Smart Add "every 3 days" was armed three days late, and after
        // every tick the next occurrence was skipped in the same way.
        final end = reminder.endsAt;
        if (end != null && reminder.scheduledTime.isAfter(end)) return null;
      } else {
        final next = ReminderHelper.nextOccurrenceFrom(
          scheduledTime: reminder.scheduledTime,
          repeatType: reminder.repeatType,
          customDays: reminder.customDays,
          recurrenceRule: reminder.recurrenceRule,
          endsAt: reminder.endsAt,
          isPaused: reminder.isPaused,
        );
        if (next == null) return null;
        fireTime = next;
      }
    }

    return ReminderArmRequest(
      reminderId: reminder.id,
      escalation: reminder.escalation,
      id: reminder.notificationSlot,
      title: reminder.title,
      body: reminder.body,
      scheduledTime: fireTime,
      // A rule or a bound cannot be expressed as a native repeat.
      repeatType:
          needsPerOccurrence ? RepeatType.none : reminder.repeatType,
      customDays: reminder.customDays,
      snoozeDuration: reminder.snoozeDuration,
      sound: reminder.sound,
      priority: reminder.priority,
      recurrenceRule: reminder.recurrenceRule,
      endsAt: reminder.endsAt,
      isPaused: reminder.isPaused,
    );
  }

  @override
  String toString() =>
      'ReminderArmRequest(id: $id, at: $scheduledTime, repeat: ${repeatType.name})';
}

/// The seam between reminder logic and the OS notification scheduler.
///
/// Modelled on [FocusSessionAlarm], whose docstring makes the case: the
/// objection "scheduled delivery cannot be verified headlessly" is true but too
/// broad. *Delivery* is an OS behaviour and is not where the defects live. The
/// defects live in the decision of **when to arm and when to disarm** — which
/// reminder is skipped, whether the old id is cancelled before a new one is
/// allocated, whether a completed one-off is re-armed — and that is ordinary
/// logic this makes directly assertable.
///
/// Reminders had no such seam, which is why `water_reminder_pacing_test`
/// documents its own subject as untestable: *"The pruning itself is private to
/// ReminderRescheduleService (it needs NotificationService, which has no
/// headless implementation)."*
///
/// Deliberately narrow: two methods, no state, no notion of what a reminder is
/// beyond the request above.
abstract interface class ReminderAlarm {
  /// Arm [request]. Arming the same id twice replaces. Returns whether the OS
  /// accepted it — `false` is a real outcome, not an error, and callers must not
  /// count a refusal as armed.
  Future<bool> arm(ReminderArmRequest request);

  /// Withdraw a pending reminder, including the per-weekday sub-notifications a
  /// repeating one fans out to. Must be safe to call when nothing is armed.
  Future<void> disarm({
    required int id,
    required RepeatType repeatType,
    List<int>? customDays,
  });
}

/// The production implementation.
class NotificationReminderAlarm implements ReminderAlarm {
  const NotificationReminderAlarm();

  @override
  Future<bool> arm(ReminderArmRequest r) async {
    // `r` already names the exact instant to arm — see
    // ReminderArmRequest.forNextOccurrence, which resolves the recurrence rule,
    // the end date and the paused flag. This adapter arms what it is told.
    final ok = await NotificationService().scheduleGenericReminder(
      id: r.id,
      title: r.title,
      body: r.body,
      scheduledTime: r.scheduledTime,
      repeatType: r.repeatType,
      priority: r.priority,
      customDays: r.customDays,
      snoozeDuration: r.snoozeDuration,
      sound: r.sound,
      // No `payload:` override, deliberately. The one caller that passed one
      // sent `note:<noteId>` for a reminder linked to a note, which REPLACED
      // the whole `alarm:{json}` blob `scheduleGenericReminder` builds — and
      // every consumer of a fired reminder gates on that prefix (`main.dart`,
      // `BackgroundAlarmService`, `reminderSlotsIn`). Nothing has ever parsed
      // `note:`, so the deep link was write-only while the cost was real: a
      // reminder with a note reached a heads-up banner instead of AlarmScreen
      // and lost its snooze duration and chosen sound. The note link itself is
      // not lost — it lives on the reminder row (`Reminder.noteId`).

      // The tier the user picked. This request has carried it all along; not
      // forwarding it is why every reminder — "Quiet" included — was armed
      // alarm-grade and full-screen.
      escalation: r.escalation,
      // Which reminder this is, so its notification can carry Done and Later.
      reminderId: r.reminderId,
    );

    // The Apple Health Medications pattern: a second notification if nothing is
    // logged within the window. Armed alongside the reminder rather than by a
    // background sweep, because it has to work while the app is dead — a user
    // who is in the app does not need a follow-up.
    //
    // Always cancel first: a re-arm of an already-armed reminder would
    // otherwise leave the previous follow-up pointing at a stale occurrence.
    final followUpId = r.id + genericReminderFollowUpOffset;
    await NotificationService().cancelNotification(followUpId);
    if (ok && r.escalation.hasFollowUp && r.reminderId != null) {
      // Anchor the follow-up to the occurrence that is actually NEXT, not to
      // the stored `scheduledTime`.
      //
      // For a repeating reminder that field is the creation instant (or the
      // last manual roll-forward) and is never advanced when the AlarmManager
      // alarm fires. So `scheduledTime + 30min` was an instant in the PAST on
      // every app start, and `oneShotAt` with a past time fires at once: an
      // Insistent daily "Insulin" popped "Still pending: Insulin" within
      // seconds of every launch, and for the critical tier that started the
      // 5-minute auto-snooze chain.
      // For a per-occurrence request `scheduledTime` IS the next occurrence;
      // for a native repeat it is the stale stored anchor, so resolve forward.
      final occurrenceDue = r.needsPerOccurrenceArming
          ? r.scheduledTime
          : (ReminderHelper.nextOccurrenceFrom(
                scheduledTime: r.scheduledTime,
                repeatType: r.repeatType,
                customDays: r.customDays,
              ) ??
              r.scheduledTime);
      final fireAt = occurrenceDue.add(r.escalation.followUpAfter);
      // A follow-up whose time has already passed is not a follow-up.
      if (fireAt.isAfter(clock.now())) {
        await BackgroundAlarmService().scheduleReminderFollowUp(
          id: followUpId,
          reminderId: r.reminderId!,
          occurrenceDue: occurrenceDue,
          fireAt: fireAt,
          title: 'Still pending: ${r.title}',
          body: r.body.isEmpty ? 'You have not marked this done yet.' : r.body,
          escalation: r.escalation,
        );
      }
    }
    return ok;
  }

  @override
  Future<void> disarm({
    required int id,
    required RepeatType repeatType,
    List<int>? customDays,
  }) async {
    await NotificationService().cancelGenericReminder(id, repeatType, customDays);
    // The follow-up is a separate alarm; cancelling the reminder alone would
    // leave it to fire on its own half an hour later.
    await NotificationService()
        .cancelNotification(id + genericReminderFollowUpOffset);
  }
}

/// Records calls instead of making them.
///
/// Lives beside the production implementation rather than in `test/` for the
/// same reason [RecordingFocusSessionAlarm] does: adding a method to the
/// interface breaks this file, in `lib`, where it cannot be missed — instead of
/// silently leaving a test double behind.
class RecordingReminderAlarm implements ReminderAlarm {
  RecordingReminderAlarm({this.armResult = true});

  /// What [arm] returns. Set `false` to exercise the refusal path — an OS that
  /// declines must not be counted as armed.
  bool armResult;

  final List<ReminderArmRequest> armed = <ReminderArmRequest>[];
  final List<int> disarmed = <int>[];

  /// Every (id, repeatType, customDays) passed to [disarm], for asserting that
  /// a repeating reminder's sub-notifications were cancelled too.
  final List<({int id, RepeatType repeatType, List<int>? customDays})>
      disarmCalls = [];

  /// The order operations happened in — `arm:<id>` / `disarm:<id>`.
  ///
  /// Ordering is load-bearing: allocating a new notification id before
  /// cancelling the old one orphans the old registration, leaving an alarm
  /// nothing can cancel.
  final List<String> sequence = <String>[];

  @override
  Future<bool> arm(ReminderArmRequest request) async {
    armed.add(request);
    sequence.add('arm:${request.id}');
    return armResult;
  }

  @override
  Future<void> disarm({
    required int id,
    required RepeatType repeatType,
    List<int>? customDays,
  }) async {
    disarmed.add(id);
    disarmCalls.add((id: id, repeatType: repeatType, customDays: customDays));
    sequence.add('disarm:$id');
  }

  void clear() {
    armed.clear();
    disarmed.clear();
    disarmCalls.clear();
    sequence.clear();
  }
}
