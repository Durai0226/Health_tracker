import 'package:flutter/foundation.dart';

import '../../../core/database/daos/reminders_dao.dart'
    show genericReminderFollowUpOffset;
import '../../../core/services/background_alarm_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/reminder_model.dart';

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
    this.payload,
    this.escalation = ReminderEscalation.standard,
    this.reminderId,
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
  final String? payload;

  /// How insistent this reminder is. Drives whether a follow-up is armed
  /// alongside the reminder itself.
  final ReminderEscalation escalation;

  /// The owning reminder's id, needed to key the follow-up's resolved flag.
  /// Null for callers that do not want a follow-up.
  final String? reminderId;

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
      payload: r.payload,
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
      await BackgroundAlarmService().scheduleReminderFollowUp(
        id: followUpId,
        reminderId: r.reminderId!,
        occurrenceDue: r.scheduledTime,
        fireAt: r.scheduledTime.add(r.escalation.followUpAfter),
        title: 'Still pending: ${r.title}',
        body: r.body.isEmpty ? 'You have not marked this done yet.' : r.body,
        escalation: r.escalation,
      );
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
