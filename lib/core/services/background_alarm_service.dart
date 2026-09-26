import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; // IsolateNameServer — signal the foreground AlarmScreen
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
// Pure-Dart schedule model (no Flutter/DB deps) — safe to use inside the alarm
// isolate to decide whether a medicine alarm should fire on a given day.
import '../../features/medication/models/medicine_schedule.dart';
// Also pure-Dart (see reminder_slot_grouping.dart) — safe inside the isolate.
import '../../features/medication/services/reminder_slot_grouping.dart';
// Also pure-Dart — safe inside the isolate.
import '../../features/medication/services/reminder_window_nudges.dart';
import '../../features/reminders/models/reminder_escalation.dart';
import '../../features/reminders/models/reminder_kind.dart';

// Re-exported: ReminderKind moved to a pure file so plain-Dart entrypoints can
// use it, but every existing consumer imports it from here.
export '../../features/reminders/models/reminder_kind.dart';
import 'dose_action_queue.dart';
import 'notification_scheduler.dart';
import 'water_action_queue.dart';

/// When the user acts on the reminder from the NOTIFICATION (not the on-screen
/// buttons), tell a live full-screen [AlarmScreen] in the main isolate to stop
/// ringing and close. The looping ring lives in that screen's in-app player, so
/// canceling the notification alone would leave it ringing. No-op when no alarm
/// screen is showing (the named port is unregistered).
///
/// Public so `notification_service.dart`'s background handler can do exactly
/// the same thing — which of the two background handlers Android invokes is
/// decided by whichever isolate called `initialize()` last, so they must
/// behave identically (see [handleDoseNotificationAction]).
@pragma('vm:entry-point')
void stopRingingAlarmScreen(int? id) {
  try {
    ui.IsolateNameServer.lookupPortByName('db_alarm_stop_${id ?? 'default'}')
        ?.send('stop');
  } catch (_) {}
}

/// The calendar instant the dose behind a reminder actually belongs to, given
/// the moment [now] that reminder fired — or that the user tapped Take/Skip
/// on it.
///
/// A dose's identity IS its scheduled instant (`doseLogId(medicineId,
/// scheduledTime)`), so "today at hour:minute" is wrong the moment either the
/// fire or the tap crosses midnight: a 23:55 dose tapped at 00:05 was logged
/// against the NEXT day's 23:55 slot — the real dose stayed "missed" and the
/// following day showed a phantom taken dose. A reminder only exists once it
/// has fired, so the dose it refers to is the most recent occurrence of that
/// clock time at or before [now]. [futureGrace] keeps an alarm the OS delivers
/// a hair EARLY (or a small clock skew between fire and tap) attributed to
/// today instead of being thrown a whole day back.
DateTime resolveDoseInstant(
  DateTime now,
  int hour,
  int minute, {
  Duration futureGrace = const Duration(minutes: 2),
}) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  if (today.isAfter(now.add(futureGrace))) {
    // `day - 1` (not `subtract(Duration(days: 1))`) so month/year rollover is
    // handled by DateTime's own normalisation and the WALL-CLOCK time is
    // preserved across a DST boundary.
    return DateTime(now.year, now.month, now.day - 1, hour, minute);
  }
  return today;
}

/// The next instant a repeating alarm at [hour]:[minute] should fire, given
/// the moment [now] this fire was actually delivered.
///
/// The old "today at hour:minute, then unconditionally +1 day" silently
/// skipped a whole day whenever the alarm was delivered LATE — the reboot
/// catch-up case: a phone that was off at 08:00 gets yesterday's alarm the
/// moment it boots at 07:00, and +1 day then armed TOMORROW, dropping today's
/// dose entirely. Walking forward from today's occurrence instead keeps
/// today's dose. [minLead] stops an alarm the OS delivers a hair early from
/// re-arming itself for the same instant and firing twice.
///
/// Day steps use `day + 1` rather than `add(Duration(days: 1))` so the
/// wall-clock time survives a DST transition (a 24h duration would shift an
/// 08:00 reminder to 07:00 or 09:00).
DateTime nextRepeatOccurrence(
  DateTime now,
  int hour,
  int minute, {
  String frequency = 'daily',
  Duration minLead = const Duration(minutes: 1),
}) {
  DateTime nextDay(DateTime d) =>
      DateTime(d.year, d.month, d.day + 1, hour, minute);

  var next = DateTime(now.year, now.month, now.day, hour, minute);
  final earliest = now.add(minLead);
  while (!next.isAfter(earliest)) {
    next = nextDay(next);
  }

  if (frequency == 'weekdays') {
    while (next.weekday == DateTime.saturday ||
        next.weekday == DateTime.sunday) {
      next = nextDay(next);
    }
  } else if (frequency == 'weekends') {
    while (next.weekday != DateTime.saturday &&
        next.weekday != DateTime.sunday) {
      next = nextDay(next);
    }
  }
  return next;
}

/// SharedPreferences flag: `true` once an alarm had to be registered
/// INEXACTLY because Android refused the exact one.
///
/// android_alarm_manager_plus reports success either way — with
/// `alarmClock: true` and SCHEDULE_EXACT_ALARM revoked its native
/// `AlarmService.scheduleAlarm` just logs and returns, while `oneShotAt` still
/// resolves to `true` — so every medicine alarm was being dropped in total
/// silence: the patient saw "reminder set" and was never reminded. Alarms are
/// now downgraded to inexact (late is survivable; never is not) and this flag
/// records it so the UI can say so.
const String exactAlarmsDowngradedKey = 'exact_alarms_downgraded';

/// The ONE snooze counter, keyed by the BASE notification id (the id of the
/// original fire, not of a snoozed re-fire).
///
/// There used to be two. `notification_service.dart`'s background handler kept
/// its count in this SharedPreferences key while this file kept its own inside
/// the `alarm_$id` JSON blob, and long comments in both claimed they shared one.
/// They did not — and because flutter_local_notifications routes a background
/// action to whichever handler registered last, alternating "app dead" and "app
/// alive" snooze taps read and wrote different stores, so the cap could be
/// bypassed indefinitely. A dose could be snoozed forever.
///
/// SharedPreferences rather than the blob because it is the only store BOTH
/// paths can reach: a notification armed via `zonedSchedule` (water, a weekly
/// generic reminder) has no `alarm_$id` blob at all.
String snoozeCountKeyFor(int baseId) => 'snooze_count_$baseId';

/// How many times one reminder may be snoozed before it is shown a final time
/// with no snooze button. Mirrored out of `UserSettings` on save so the alarm
/// isolate — which cannot touch Drift — can read it.
const String maxSnoozeCountKey = 'max_snooze_count';

/// Minutes per snooze, mirrored out of `UserSettings` for the same reason.
const String snoozeIntervalMinutesKey = 'snooze_interval_minutes';

/// Whether the snooze action is offered at all, mirrored for the same reason.
const String snoozeEnabledKey = 'snooze_enabled';

/// Default snooze cap when nothing has been mirrored yet.
const int defaultMaxSnoozeCount = 3;

/// Default snooze interval when nothing has been mirrored yet.
const int defaultSnoozeIntervalMinutes = 5;

/// The notification action id for "log a glass of water".
///
/// Defined here, and re-exported by `notification_service.dart`, so the
/// background handler in this file can recognise it without importing that file
/// (which imports this one).
const String waterLogActionId = 'log_water';

/// The offset between a notification's id and its snoozed re-fire.
///
/// Both snooze paths must agree on it, or one path's reschedule cannot be
/// cancelled by the other's and the user gets two copies of one reminder.
const int snoozeIdOffset = 100000;

/// Resolve the base id a snooze counter belongs to.
///
/// A fresh fire is its own base. A snoozed re-fire carries the base forward
/// explicitly — in the alarm blob for the AlarmManager path, in the `alarm:`
/// payload for the `zonedSchedule` path — rather than being derived by
/// subtracting [snoozeIdOffset], which would be ambiguous: the medicine slot
/// block (100000-101439) overlaps the snooze-twin range of the ids below it.
int resolveSnoozeBaseId(int notificationId, Object? carriedBaseId) =>
    (carriedBaseId as num?)?.toInt() ?? notificationId;

/// Whether Android currently permits EXACT alarms. Any failure to find out is
/// treated as "permitted" so behaviour is unchanged when the check itself is
/// unavailable (e.g. a background isolate without the plugin attached).
///
/// The AlarmManager track ([_registerAlarm]) and the `zonedSchedule` track
/// ([zonedScheduleGuarded]) must agree on whether exact scheduling is available,
/// or the two disagree about whether a downgrade happened. They therefore ask
/// the one implementation below — `zonedScheduleGuarded` through its injected
/// [NotificationScheduler], so a test can answer for it; `_registerAlarm`
/// through this free function, which is the same code on the real plugin.
Future<bool> exactAlarmsAllowed() =>
    PluginNotificationScheduler().exactAlarmsAllowed();

/// Single registration point for every [alarmCallback] alarm in this file.
///
/// Prefers an exact, alarm-clock-grade registration (what a medicine reminder
/// needs) and transparently falls back to an inexact, allow-while-idle alarm
/// when Android has revoked SCHEDULE_EXACT_ALARM — which fires within the OS
/// batching window instead of not at all. [preferExact] is `false` for
/// reminder-window nudges, which are inexact BY DESIGN (see
/// [BackgroundAlarmService.scheduleWindowNudge]) and so are never "downgraded".
@pragma('vm:entry-point')
Future<bool> _registerAlarm(
  DateTime when,
  int id, {
  bool preferExact = true,
  bool alarmClock = true,
}) async {
  var exact = false;
  if (preferExact) {
    exact = await exactAlarmsAllowed();
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(exactAlarmsDowngradedKey) ?? false) != !exact) {
        await prefs.setBool(exactAlarmsDowngradedKey, !exact);
      }
    } catch (_) {}
    if (!exact) {
      debugPrint(
          '⚠️ SCHEDULE_EXACT_ALARM not granted — registering alarm $id INEXACTLY; it will still fire, just not to the minute');
    }
  }

  return AndroidAlarmManager.oneShotAt(
    when,
    id,
    alarmCallback,
    exact: exact,
    // Only consulted on the non-alarmClock paths; keeps the downgraded alarm
    // alive through Doze instead of waiting for the next maintenance window.
    allowWhileIdle: true,
    wakeup: true,
    rescheduleOnReboot: true,
    alarmClock: exact && alarmClock,
  );
}

/// The single `zonedSchedule` entry point for the app. Prefer this over calling
/// the plugin directly.
///
/// Lives here rather than in `notification_service.dart` because the exact-alarm
/// capability check and the downgrade flag it must agree with are here, and
/// because the background snooze path needs it — that file imports this one, so
/// the other direction would be circular.
///
/// **Why this exists.** `USE_EXACT_ALARM` is deliberately absent from the
/// manifest — Play's acceptable-use policy for that auto-granted, non-revocable
/// permission covers alarm-clock and calendar apps, which this is not. So on
/// Android 14+ `SCHEDULE_EXACT_ALARM` is denied by default and the plugin throws
/// `exact_alarms_not_permitted` for BOTH exact modes. Before this helper, 20 of
/// the 22 `zonedSchedule` call sites let that throw land in an outer `catch` that
/// only `debugPrint`ed, so on a default Android 14+ install **water reminders,
/// every snooze, and every weekly / weekdays / weekends / custom generic reminder
/// were silently never armed.** Only `scheduleFocusCompletion` handled it.
///
/// Late is survivable; never is not. So an exact request that Android refuses is
/// downgraded to `inexactAllowWhileIdle` rather than propagated.
///
/// Mirrors `_registerAlarm`'s strategy (pre-check, then act) so the AlarmManager
/// track and this track never disagree about whether a downgrade happened, and
/// keeps the reactive `catch` as well because the grant can be revoked between
/// the check and the call.
///
/// The downgrade flag ([exactAlarmsDowngradedKey], which drives the "Reminders may
/// arrive late" banner) is raised **only when the caller asked for an exact mode**.
/// A site that already requests `inexactAllowWhileIdle` — bedtime, steps, focus —
/// is inexact by design and was never downgraded, so it must not raise a banner
/// that reads as being about doses. Pass [recordDowngrade] `false` to opt out
/// explicitly even when requesting exact.
///
/// Returns `true` if armed exactly, `false` if armed inexactly. Anything that is
/// not a permission refusal is rethrown, so existing outer `catch` blocks behave
/// exactly as before.
@pragma('vm:entry-point')
Future<bool> zonedScheduleGuarded(
  NotificationScheduler scheduler,
  int id,
  String? title,
  String? body,
  tz.TZDateTime when,
  NotificationDetails details, {
  AndroidScheduleMode androidScheduleMode =
      AndroidScheduleMode.exactAllowWhileIdle,
  DateTimeComponents? matchDateTimeComponents,
  String? payload,
  bool? recordDowngrade,
  String debugLabel = 'notification',
}) async {
  const exactModes = {
    AndroidScheduleMode.exact,
    AndroidScheduleMode.exactAllowWhileIdle,
    AndroidScheduleMode.alarmClock,
  };
  final wantsExact = exactModes.contains(androidScheduleMode);
  final tracksDowngrade = recordDowngrade ?? wantsExact;

  Future<void> attempt(AndroidScheduleMode mode) => scheduler.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: mode,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );

  Future<void> noteDowngrade({required bool downgraded}) async {
    if (!tracksDowngrade) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(exactAlarmsDowngradedKey) ?? false) != downgraded) {
        await prefs.setBool(exactAlarmsDowngradedKey, downgraded);
      }
    } catch (_) {}
  }

  if (!wantsExact) {
    await attempt(androidScheduleMode);
    return false;
  }

  // Pre-check: avoids provoking a throw at all on the common Android 14+ path.
  // Asked of the SAME seam that does the arming — a check on one object and an
  // arm on another is two answers to one question.
  if (!await scheduler.exactAlarmsAllowed()) {
    await noteDowngrade(downgraded: true);
    await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
    debugPrint(
        '⚠️ $debugLabel $id armed INEXACTLY (exact alarms not permitted) for $when');
    return false;
  }

  try {
    await attempt(androidScheduleMode);
    await noteDowngrade(downgraded: false);
    return true;
  } on PlatformException catch (e) {
    // ONLY a permission refusal falls back. Anything else — a bad argument, a
    // channel failure — is a real error and must propagate: swallowing it here
    // would report "armed inexactly" for a notification that was never armed at
    // all, which is the silent-false-success shape this whole helper exists to
    // prevent.
    if (e.code != 'exact_alarms_not_permitted') rethrow;

    // Racy revocation between the check above and the call.
    await noteDowngrade(downgraded: true);
    await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
    debugPrint(
        '⚠️ $debugLabel $id armed INEXACTLY (exact refused mid-call) for $when');
    return false;
  }
}

/// The ONE background handler for notification ACTION taps.
///
/// flutter_local_notifications stores exactly ONE app-wide background callback
/// handle (`IsolatePreferences.saveCallbackKeys`, rewritten by every
/// `initialize()` that passes `onDidReceiveBackgroundNotificationResponse`), and
/// Android's `ActionBroadcastReceiver` spins up a fresh isolate running whichever
/// handle was written LAST.
///
/// There used to be two rival handlers — this one and `notification_service.dart`'s
/// — and which one Android invoked depended on whether the alarm isolate or the
/// main isolate had most recently initialised the plugin. They drifted, twice:
/// first this file's handler ignored `take`/`skip` (so a dose was never queued,
/// never logged, and stock never decremented, silently), then the other one was
/// the only one that knew about `log_water`. They also snoozed differently, into
/// two different counters, which made the snooze cap bypassable by alternating
/// app-dead and app-alive taps.
///
/// One function, registered by both isolates, is the only version of this that
/// cannot drift. Do not add a second.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('🔔 Background notification action: ${response.actionId}');
  // Any action means the user engaged — silence a ringing full-screen alarm.
  stopRingingAlarmScreen(response.id);
  switch (response.actionId) {
    case 'snooze':
      handleSnoozeAction(response.id ?? 0, response.payload);
    case 'dismiss':
      FlutterLocalNotificationsPlugin().cancel(response.id ?? 0);
      debugPrint('✓ Background notification dismissed: ${response.id}');
    case 'take':
      handleDoseNotificationAction(response.payload, DoseActionQueue.actionTake);
    case 'skip':
      handleDoseNotificationAction(response.payload, DoseActionQueue.actionSkip);
    case waterLogActionId:
      // Drift is unavailable in this isolate, so the drink is queued and written
      // on next resume — the same hand-off the dose actions use.
      WaterActionQueue.enqueue(
        amountMl: WaterActionQueue.defaultQuickAddMl,
        at: DateTime.now(),
      );
  }
}

/// Snooze whatever fired under [notificationId].
///
/// Two mechanisms arm notifications in this app, so two reschedule paths exist —
/// but only ONE entry point and only one counter. An AlarmManager alarm has a
/// persisted `alarm_$id` blob carrying the dose's identity (hour/minute, the
/// medicines list, window-nudge state); a `zonedSchedule` notification has
/// nothing but its payload. Choosing on the presence of the blob keeps the rich
/// path rich: routing a dose through the payload path would drop hour/minute, and
/// a "✓ Take" on the re-fire would then log it against midnight.
@pragma('vm:entry-point')
Future<void> handleSnoozeAction(int notificationId, String? payload) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('alarm_$notificationId') != null) {
      await _scheduleSnoozeNotification(notificationId);
      return;
    }
    await _snoozeFromPayload(notificationId, payload);
  } catch (e) {
    debugPrint('❌ Snooze dispatch failed for $notificationId: $e');
  }
}

/// Parse a medicine alarm payload and queue a Take/Skip for the main isolate to
/// apply on next resume (Drift is unavailable in this background isolate, so we
/// only touch SharedPreferences here — the queue-and-drain pattern).
///
/// A grouped slot's payload carries a `medicines` list instead of a single
/// `medicineId`; "Take all" fans out to one queued action per medicine (via
/// [medicineIdsFromAlarmPayload]), so the existing drain-and-report flow on
/// app resume covers it for free.
///
/// Public because BOTH background-response handlers in this app must run it:
/// flutter_local_notifications stores ONE app-wide background callback handle
/// (`IsolatePreferences.saveCallbackKeys`, last `initialize()` wins), so after
/// any cold start of the main isolate it is `notificationTapBackground` in
/// notification_service.dart — not this file's handler — that Android invokes
/// for a "✓ Take" tap. That handler ignored take/skip entirely, so the dose was
/// never queued, never logged, and stock was never decremented.
@pragma('vm:entry-point')
Future<void> handleDoseNotificationAction(String? payload, String action) async {
  try {
    final medicineIds = medicineIdsFromAlarmPayload(payload);
    if (medicineIds.isEmpty) return;
    final data = jsonDecode(payload!.substring('alarm:'.length))
        as Map<String, dynamic>;
    // Fire-time payloads (rebuilt by alarmCallback / _handleWindowNudge) carry
    // the resolved dose instant outright; older/schedule-time payloads carry
    // only hour:minute, which must be resolved against NOW — never assumed to
    // be "today", or a tap just after midnight lands on the wrong day.
    final doseEpochMs = (data['doseEpochMs'] as num?)?.toInt();
    final hour = (data['hour'] as num?)?.toInt() ?? 8;
    final minute = (data['minute'] as num?)?.toInt() ?? 0;
    final scheduled = doseEpochMs != null
        ? DateTime.fromMillisecondsSinceEpoch(doseEpochMs)
        : resolveDoseInstant(DateTime.now(), hour, minute);
    final prefs = await SharedPreferences.getInstance();
    for (final medId in medicineIds) {
      await DoseActionQueue.enqueue(
          medicineId: medId, scheduledTime: scheduled, action: action);
      // Stamp the resolved flag THE INSTANT the action is queued, not only
      // once the main isolate later drains it — a window-nudge alarm firing
      // in the gap between "notification tapped" and "app next opened" must
      // see this immediately, or it would show a redundant nudge for a dose
      // the user already acted on.
      await prefs.setBool(nudgeResolvedKey(medId, scheduled), true);
    }
  } catch (e) {
    debugPrint('⚠️ Dose action handling failed: $e');
  }
}

/// Which dose an alarm payload is for.
///
/// The full-screen [AlarmScreen] used to derive this as
/// `DateTime(now.year, now.month, now.day, hour, minute)`, which silently
/// assumes the dose belongs to *today* — reintroducing on the foreground path the
/// midnight-attribution bug [resolveDoseInstant] exists to prevent. Taking a
/// 23:55 dose at 00:05 logged it against tomorrow's 23:55 slot: an orphan log,
/// with the real dose still showing missed.
///
/// It also mis-keyed the resolved flag. `markMedicineTaken` and
/// `markMedicineSkipped` derive `nudgeResolvedKey` from this instant, so a wrong
/// instant stamps a key nothing reads and the rest of that window's nudges still
/// fire for a dose the user already acted on.
///
/// `doseEpochMs` wins when present: the background path already resolved the
/// instant and stamped it into the payload, and a value it computed beats
/// re-deriving one. Falls back to [now] when the payload carries no clock time at
/// all (a generic reminder, which has no dose identity).
DateTime doseInstantFromAlarmPayload(
  Map<String, dynamic> payload, {
  required DateTime now,
}) {
  final epochMs = (payload['doseEpochMs'] as num?)?.toInt();
  if (epochMs != null) return DateTime.fromMillisecondsSinceEpoch(epochMs);
  final hour = (payload['hour'] as num?)?.toInt();
  final minute = (payload['minute'] as num?)?.toInt();
  if (hour == null || minute == null) return now;
  return resolveDoseInstant(now, hour, minute);
}

/// Schedule a snoozed notification
@pragma('vm:entry-point')
Future<void> _scheduleSnoozeNotification(int originalId) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Get original alarm data
    final alarmDataJson = prefs.getString('alarm_$originalId');
    if (alarmDataJson == null) {
      debugPrint('⚠️ No alarm data for snooze: $originalId');
      return;
    }
    
    final alarmData = jsonDecode(alarmDataJson) as Map<String, dynamic>;

    // This reminder's OWN snooze duration wins over the global preference.
    // The button the user tapped is LABELLED with the per-reminder value (see
    // the `snoozeDuration` override in [alarmCallback]), so rescheduling off
    // the global one brought a reminder configured for 30 minutes back in 5 —
    // the button promised one thing and the alarm did another. Read as `num`
    // because a value that survived a JSON round-trip may be either.
    final snoozeMinutes = (alarmData['snoozeDuration'] as num?)?.toInt() ??
        prefs.getInt(snoozeIntervalMinutesKey) ??
        defaultSnoozeIntervalMinutes;
    final isWindowNudge = alarmData['isWindowNudge'] == true;
    final title = isWindowNudge
        ? 'Time for ${alarmData['medicineName'] ?? 'your medicine'}'
        : (alarmData['title'] as String? ?? 'Snoozed Reminder');
    final body = alarmData['body'] as String? ?? 'Time for your reminder!';

    // Cap repeat snoozing. Read the raw pref key rather than pulling in
    // CleanStorageService, which transitively imports Drift and is unsafe in
    // this background isolate; `saveUserSettings` mirrors the value out for us.
    //
    // The count lives in [snoozeCountKeyFor], NOT in this blob. It used to live
    // in the blob while the other snooze path used the pref key, which is how
    // the cap became bypassable by alternating app-dead and app-alive taps.
    // `alarmData['snoozeCount']` is still read as a fallback so a snooze already
    // in flight across the upgrade is not silently reset to zero.
    final baseId = resolveSnoozeBaseId(originalId, alarmData['baseId']);
    final isFreshFire = originalId == baseId;
    final snoozeCount = isFreshFire
        ? 0
        : prefs.getInt(snoozeCountKeyFor(baseId)) ??
            (alarmData['snoozeCount'] as num?)?.toInt() ??
            0;
    final maxSnoozeCount =
        prefs.getInt(maxSnoozeCountKey) ?? defaultMaxSnoozeCount;
    if (snoozeCount >= maxSnoozeCount) {
      // The tapped notification is ALREADY gone by this point — Android's
      // ActionBroadcastReceiver cancels it natively (cancelNotification
      // defaults to true for an action with showsUserInterface:false) before
      // this Dart handler even runs. Returning here without showing anything
      // would silently lose the reminder entirely, not just cap snoozing —
      // so show a final, snooze-less notification instead.
      debugPrint(
          '⏹️ Snooze cap ($maxSnoozeCount) reached for alarm $originalId — showing a final reminder with no snooze option');
      await _showFinalCappedNotification(
        originalId,
        title,
        body,
        channelId: alarmData['channelId'] as String? ?? 'medicine_channel',
        channelName: alarmData['channelName'] as String? ?? 'Medicine Reminders',
        payload: alarmData['payload'] as String?,
      );
      return;
    }

    await prefs.setInt(snoozeCountKeyFor(baseId), snoozeCount + 1);

    // Schedule snooze alarm. Window nudges snooze inexactly too, matching
    // scheduleWindowNudge's own choice — a snooze is exactly as time-tolerant
    // as the window it belongs to.
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));
    final snoozeId = (originalId + snoozeIdOffset) & 0x7FFFFFFF;

    // Android drops every pending alarm on reboot; _registerAlarm always sets
    // rescheduleOnReboot, so a restart inside the snooze window no longer
    // loses that dose's reminder (the original notification is already
    // cancelled by then). The blob it needs is persisted under
    // `alarm_$snoozeId` just below, so the rebooted re-fire finds everything.
    final result = await _registerAlarm(
      snoozeTime,
      snoozeId,
      preferExact: !isWindowNudge,
      alarmClock: !isWindowNudge,
    );

    // Store snooze alarm data
    final snoozeData = {
      'title': '⏰ $title',
      'body': body,
      'channelId': alarmData['channelId'] ?? 'medicine_channel',
      'channelName': alarmData['channelName'] ?? 'Medicine Reminders',
      'isRepeating': false,
      'snoozeDuration': snoozeMinutes,
      // The base this snooze chain belongs to, so the next hop finds the same
      // counter. The count itself is in [snoozeCountKeyFor], not here.
      'baseId': baseId,
      'sound': alarmData['sound'],
      // Carry the payload so the snoozed re-fire again opens the full-screen
      // AlarmScreen (whose on-screen Dismiss always works) instead of a
      // button-limited notification. Null when the source had no payload.
      'payload': alarmData['payload'],
      // Carry the already-gated medicines list forward too, so the snoozed
      // re-fire still shows the same InboxStyle group / "Take all" instead of
      // falling back to a generic single reminder.
      if (alarmData['medicines'] != null) 'medicines': alarmData['medicines'],
      // The dose's scheduled clock time must survive the snooze for EVERY
      // reminder type, not just window nudges. Without it a snoozed medicine
      // slot re-fired with hour/minute defaulting to 0:0, so a "✓ Take" on the
      // snoozed notification logged the dose against MIDNIGHT instead of its
      // real slot — an orphan log, with the actual dose still showing missed.
      if (alarmData['hour'] != null) 'hour': alarmData['hour'],
      if (alarmData['minute'] != null) 'minute': alarmData['minute'],
      // Window nudges: carry forward everything _handleWindowNudge needs, so
      // the snoozed re-fire is recognized as a nudge (not misread as a plain
      // medicine-slot alarm) and can still chain/suppress correctly. Chaining
      // the next nudge targets its own ORIGINAL absolute minute-of-day, not
      // an offset from this snooze, so a late re-fire can't push it out.
      if (isWindowNudge) ...{
        'isWindowNudge': true,
        'baseAlarmId': alarmData['baseAlarmId'],
        'medicineId': alarmData['medicineId'],
        'medicineName': alarmData['medicineName'],
        // hour/minute are carried above for every reminder type.
        'nudgeIndex': alarmData['nudgeIndex'],
        'nudgeMinutes': alarmData['nudgeMinutes'],
        'scheduleJson': alarmData['scheduleJson'],
      },
    };
    await prefs.setString('alarm_$snoozeId', jsonEncode(snoozeData));
    
    // Cancel the original notification
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.cancel(originalId);
    
    debugPrint('✓ Snoozed for $snoozeMinutes min, ID: $snoozeId, result: $result');
  } catch (e) {
    debugPrint('❌ Snooze scheduling failed: $e');
  }
}

/// Shows a plain, snooze-less notification once the snooze cap is reached —
/// simpler than the rich medicine-slot notification (no InboxStyle/Take-all
/// reconstruction), but it's shown only after 3+ snoozes of the same
/// reminder, and the carried-forward [payload] still opens the full AlarmScreen
/// (Take/Skip available there) on tap.
@pragma('vm:entry-point')
Future<void> _showFinalCappedNotification(
  int id,
  String title,
  String body, {
  required String channelId,
  required String channelName,
  String? payload,
}) async {
  try {
    final notifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Reminder (snooze limit reached)',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('dismiss', '✕ Dismiss',
            showsUserInterface: false, cancelNotification: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await notifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  } catch (e) {
    debugPrint('❌ Final capped notification failed: $e');
  }
}

/// Handle snooze action from within alarmCallback context
@pragma('vm:entry-point')
Future<void> _handleBackgroundSnooze(int originalId, SharedPreferences prefs) async {
  await _scheduleSnoozeNotification(originalId);
}

/// Everything about *how* an alarm presents itself, derived from what it is.
///
/// Pure and public so the invariant that matters can actually be asserted: a
/// vitals check-in must never carry a `✓ Take` button or take over the screen.
/// Before [ReminderKind] this was ~90 lines of `AndroidNotificationDetails`
/// inlined in [alarmCallback] with `alarm_channel`, `fullScreenIntent: true` and
/// the dose action set hardcoded — unreachable by any test, and wrong for five of
/// the families that went through it.
class AlarmPresentation {
  const AlarmPresentation({
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
    required this.importance,
    required this.priority,
    required this.fullScreenIntent,
    required this.category,
    required this.audioUsage,
    required this.autoCancel,
    required this.ongoing,
    required this.timeoutAfterMs,
    required this.vibrationPattern,
    required this.actions,
  });

  final String channelId;
  final String channelName;
  final String channelDescription;
  final Importance importance;
  final Priority priority;
  final bool fullScreenIntent;
  final AndroidNotificationCategory category;
  final AudioAttributesUsage audioUsage;
  final bool autoCancel;
  final bool ongoing;
  final int? timeoutAfterMs;
  final List<int> vibrationPattern;
  final List<AndroidNotificationAction> actions;

  /// Whether any action button logs a dose. Nothing but a real dose may.
  bool get offersDoseLogging => actions.any((a) => a.id == 'take');
}

/// The presentation for [kind].
///
/// [requestedChannelId] is honoured for alarm-grade kinds. A `gentle` kind is
/// forced onto `checkin_channel` regardless: `reminders_channel` and
/// `medicine_channel` are both created with `audioAttributesUsage: alarm`, and
/// channel audio attributes are IMMUTABLE once created — so a nudge posted there
/// rings at alarm volume however politely the notification itself asks.
///
/// One shared `checkin_channel` rather than one per family is a deliberate
/// stopping point, not the end state: separate channels are why muting hydration
/// cannot mute doses in this app, and splitting vitals / appointments / cycle
/// apart changes notification settings the user may already have tuned, which
/// deserves its own decision.
@pragma('vm:entry-point')
AlarmPresentation alarmPresentationFor(
  ReminderKind kind, {
  bool isGroup = false,
  required int snoozeMinutes,
  bool snoozeEnabled = true,
  String? requestedChannelId,
  String? requestedChannelName,
}) {
  final alarmGrade = kind.isAlarmGrade;
  return AlarmPresentation(
    channelId: alarmGrade
        ? (requestedChannelId ?? 'alarm_channel')
        : 'checkin_channel',
    channelName: alarmGrade
        ? (requestedChannelName ?? 'Alarm Reminders')
        : 'Check-ins & Nudges',
    channelDescription: alarmGrade
        ? 'High priority alarm reminders'
        : 'Gentle check-in and heads-up nudges',
    importance: alarmGrade ? Importance.max : Importance.high,
    priority: alarmGrade ? Priority.max : Priority.defaultPriority,
    // A nudge must never take over the screen. Play can revoke
    // USE_FULL_SCREEN_INTENT for exactly that over-reach, and the manifest keeps
    // the permission solely for dose-grade alerts.
    fullScreenIntent: alarmGrade,
    category: alarmGrade
        ? AndroidNotificationCategory.alarm
        : AndroidNotificationCategory.reminder,
    // The default (notification) stream respects the user's notification volume
    // and Do Not Disturb; the alarm stream deliberately does not.
    audioUsage: alarmGrade
        ? AudioAttributesUsage.alarm
        : AudioAttributesUsage.notification,
    // A nudge is dismissible by swipe; an alarm is not.
    autoCancel: !alarmGrade,
    ongoing: alarmGrade,
    timeoutAfterMs: alarmGrade ? 300000 : null, // 5 minute safety timeout
    vibrationPattern: alarmGrade
        ? const [0, 1000, 500, 1000, 500, 1000]
        : const [0, 250, 250, 250],
    actions: _actionsFor(kind,
        isGroup: isGroup,
        snoozeMinutes: snoozeMinutes,
        snoozeEnabled: snoozeEnabled),
  );
}

/// The action buttons an alarm of each [ReminderKind] carries.
///
/// Android caps a notification at 3 action buttons; a 4th makes the last one
/// silently disappear. Every list below is at that limit, so adding to one means
/// removing from it. Dropping one (as [snoozeEnabled] false does) is always
/// safe.
///
/// [snoozeEnabled] is the user's "Snooze enabled" setting. It was mirrored into
/// the alarm isolate and then read by nothing, so someone who had turned
/// snoozing OFF was still handed a Snooze button on every alert — the setting
/// appeared to do nothing at all.
List<AndroidNotificationAction> _actionsFor(
  ReminderKind kind, {
  required bool isGroup,
  required int snoozeMinutes,
  bool snoozeEnabled = true,
}) {
  switch (kind) {
    case ReminderKind.gentle:
      // No buttons at all. There is nothing to "take", and a nudge that offers
      // Snooze invites the user to train themselves to dismiss it.
      return const <AndroidNotificationAction>[];

    case ReminderKind.alarm:
      // A time the user chose. Nothing to log — "Mark done" needs a handler and
      // an occurrence row, which is a later change, not a button added here.
      return <AndroidNotificationAction>[
        if (snoozeEnabled)
          AndroidNotificationAction(
            'snooze',
            '⏰ Snooze ${snoozeMinutes}min',
            showsUserInterface: false,
          ),
        const AndroidNotificationAction(
          'dismiss',
          '✕ Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ];

    case ReminderKind.dose:
      // A grouped medicine slot (2+ medicines due at the same time) collapses to
      // ONE notification, not one-per-medicine. With only 3 slots a group trades
      // Dismiss for "Take all" + Snooze — per-medicine Take/Skip stays in-app,
      // where it already works.
      if (isGroup) {
        return <AndroidNotificationAction>[
          // Loops DoseActionQueue.enqueue for every medicine in the group (see
          // handleDoseNotificationAction) — nearly free, since the drain on app
          // resume already reports "Logged N doses" with one Undo.
          const AndroidNotificationAction(
            'take',
            '✓ Take all',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          if (snoozeEnabled)
            AndroidNotificationAction(
              'snooze',
              '⏰ Snooze ${snoozeMinutes}min',
              showsUserInterface: false,
            ),
        ];
      }
      return <AndroidNotificationAction>[
        // 1-tap Take straight from the notification (Pogue's #1 differentiator).
        // Queued for the main isolate to log (Drift is unavailable here).
        const AndroidNotificationAction(
          'take',
          '✓ Take',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        if (snoozeEnabled)
          AndroidNotificationAction(
            'snooze',
            '⏰ Snooze ${snoozeMinutes}min',
            showsUserInterface: false,
          ),
        // Dismiss must always be present for a solo reminder — this is the third
        // and final slot. Clears the alert without logging the dose; "Skip" (a
        // logged non-dose) lives in-app.
        const AndroidNotificationAction(
          'dismiss',
          '✕ Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ];
  }
}

/// Top-level callback function for background alarms
/// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> alarmCallback(int alarmId) async {
  debugPrint('🔔 ALARM CALLBACK FIRED! ID: $alarmId');
  
  try {
    // Initialize shared preferences
    final prefs = await SharedPreferences.getInstance();
    
    // Get alarm data
    final alarmDataJson = prefs.getString('alarm_$alarmId');
    if (alarmDataJson == null) {
      debugPrint('⚠️ No alarm data found for ID: $alarmId');
      return;
    }
    
    final alarmData = jsonDecode(alarmDataJson) as Map<String, dynamic>;
    var title = alarmData['title'] as String? ?? 'Reminder';
    var body = alarmData['body'] as String? ?? 'Time for your reminder!';
    var payload = alarmData['payload'] as String?;

    debugPrint('📋 Alarm data: $title - $body (Payload: $payload)');

    // A Phase 4 reminder-window nudge is structurally separate from the
    // medicine-slot flow below — it never groups with other medicines and
    // can fire up to 3 times, chaining itself. Handle it entirely and return.
    if (alarmData['isWindowNudge'] == true) {
      await _handleWindowNudge(alarmId, alarmData, prefs);
      return;
    }

    // A reminder FOLLOW-UP: the second nudge an insistent/critical reminder
    // arms 30 minutes out ("you haven't logged this yet" — the Apple Health
    // Medications pattern). It must not fire if the user has since acted.
    //
    // Checked against a SharedPreferences flag rather than the occurrence row,
    // because this isolate has no Drift connection. `reminderResolvedKey` is
    // written from both the main isolate and the notification action handler,
    // so a tap made seconds ago is already visible here.
    if (alarmData['isReminderFollowUp'] == true) {
      final reminderId = alarmData['reminderId'] as String?;
      final dueMs = (alarmData['occurrenceMs'] as num?)?.toInt();
      if (reminderId != null && dueMs != null) {
        final resolved = prefs.getBool(reminderResolvedKey(
                reminderId, DateTime.fromMillisecondsSinceEpoch(dueMs))) ??
            false;
        if (resolved) {
          debugPrint('⏭️ Follow-up suppressed — reminder already resolved');
          await prefs.remove('alarm_$alarmId');
          return;
        }
        // "Keep asking until you act" — the Due pattern, and the only reason
        // that app works according to its own reviews. Implemented by the
        // follow-up re-arming ITSELF, the same self-chaining shape
        // `_handleWindowNudge` uses, because a background sweep cannot run
        // while the app is dead and that is precisely when it is needed.
        //
        // Capped: past the cap it stops chaining and the notification below is
        // the last one. Uncapped this would not be persistence, it would be
        // harassment with no exit but deleting the reminder.
        // What happens next is decided by [nextEscalationStep], NOT re-derived
        // here. This branch used to reimplement the same round/cap rule that
        // the pure function already expressed and that its tests already
        // covered — two implementations of one rule, which is exactly the drift
        // that let the two background handlers and the two snooze counters
        // diverge before they were merged.
        final tier = ReminderEscalation.fromName(
            alarmData['escalation'] as String?);
        final round = (alarmData['round'] as num?)?.toInt() ?? 1;
        final cap = prefs.getInt(maxSnoozeCountKey) ?? defaultMaxSnoozeCount;
        final step = nextEscalationStep(
          escalation: tier,
          // By construction: this alarm was armed to fire exactly one
          // follow-up window after the occurrence was due.
          sinceFired: tier.followUpAfter,
          snoozeCount: round,
          maxSnoozes: cap,
          resolved: false, // handled above, with an early return
        );
        switch (step) {
          case EscalationStep.autoSnooze:
            final gapMinutes = prefs.getInt(snoozeIntervalMinutesKey) ??
                defaultSnoozeIntervalMinutes;
            await prefs.setString(
              'alarm_$alarmId',
              jsonEncode({...alarmData, 'round': round + 1}),
            );
            await _registerAlarm(
              DateTime.now().add(Duration(minutes: gapMinutes)),
              alarmId,
              preferExact: false,
              alarmClock: false,
            );
            debugPrint(
                '🔁 Follow-up round $round/$cap — next in $gapMinutes min');
          case EscalationStep.finalNotice:
            debugPrint('⏹️ Follow-up cap ($cap) reached — final notice');
          case EscalationStep.followUp:
          case EscalationStep.none:
            // Nudge once and let go. The notification below is the whole of it.
            break;
        }
      }
    }

    // Which dose does THIS fire belong to? Not necessarily "now": an alarm
    // delivered late (reboot catch-up, Doze batching, a snoozed re-fire) can
    // land on the far side of midnight from the dose it is reminding about.
    // Resolved once here and used for BOTH the active-day gate and the dose
    // identity in the payload, so a Take/Skip can never be logged against the
    // wrong calendar day. Alarms with no clock time (one-shot reminders) keep
    // using the fire instant, exactly as before.
    final fireTime = DateTime.now();
    final slotHour = (alarmData['hour'] as num?)?.toInt();
    final slotMinute = (alarmData['minute'] as num?)?.toInt();
    final doseInstant = (slotHour != null && slotMinute != null)
        ? resolveDoseInstant(fireTime, slotHour, slotMinute)
        : fireTime;

    // ── Medicine slot gate ──────────────────────────────────────────────────
    // A medicine-slot alarm (Phase 1 grouping) carries one entry per medicine
    // sharing this exact clock time, each with its OWN serialized
    // MedicineSchedule — day-based regimens (specific days / every-X-days /
    // cyclical, past end/duration) must not appear on their off-days even
    // though a co-slotted medicine fires today. Filter down to the medicines
    // actually due today; skip the whole alarm only if NONE are.
    // Pure-Dart + SharedPreferences only — safe inside the alarm isolate.
    final rawMedicines =
        (alarmData['medicines'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> activeToday = rawMedicines;

    if (rawMedicines.isNotEmpty) {
      activeToday = rawMedicines.where((med) {
        final sj = med['scheduleJson'] as String?;
        if (sj == null || sj.isEmpty) return true;
        try {
          final schedule =
              MedicineSchedule.fromJson(jsonDecode(sj) as Map<String, dynamic>);
          if (!schedule.isActiveOnDate(doseInstant)) return false;
          // Is this CLOCK TIME one of the medicine's slots for this day?
          //
          // The day gate alone is not enough once a weekend override exists:
          // both the weekday and the weekend slot are armed (see
          // groupRemindersBySlot), and only one of them belongs to any given
          // day. Without this check a 07:00 weekday alarm also rang on
          // Saturday, when the dose is actually due at 10:00.
          if (slotHour == null || slotMinute == null) return true;
          final todaysSlots = schedule.getScheduledTimesForDate(doseInstant);
          if (todaysSlots.isEmpty) return true; // nothing to compare against
          return todaysSlots
              .any((t) => t.hour == slotHour && t.minute == slotMinute);
        } catch (e) {
          // On any parse error, fail OPEN (fire) — never silently drop a dose.
          debugPrint('⚠️ Schedule gate parse failed (firing anyway): $e');
          return true;
        }
      }).toList();

      if (activeToday.isEmpty) {
        debugPrint('⏭️ Alarm $alarmId: no medicines due today — skipping, rescheduling');
        final isRepeating = alarmData['isRepeating'] as bool? ?? false;
        if (isRepeating) {
          await _rescheduleRepeatingAlarm(alarmId, alarmData, prefs);
        } else {
          await prefs.remove('alarm_$alarmId');
        }
        return;
      }
    } else {
      // Legacy path: non-medicine alarms (water/sleep/fitness/etc.) still carry
      // a single top-level scheduleJson gate.
      final scheduleJson = alarmData['scheduleJson'] as String?;
      if (scheduleJson != null && scheduleJson.isNotEmpty) {
        try {
          final schedule = MedicineSchedule.fromJson(
              jsonDecode(scheduleJson) as Map<String, dynamic>);
          if (!schedule.isActiveOnDate(doseInstant)) {
            debugPrint('⏭️ Alarm $alarmId inactive today — skipping, rescheduling');
            final isRepeating = alarmData['isRepeating'] as bool? ?? false;
            if (isRepeating) {
              await _rescheduleRepeatingAlarm(alarmId, alarmData, prefs);
            } else {
              await prefs.remove('alarm_$alarmId');
            }
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Schedule gate parse failed (firing anyway): $e');
        }
      }
    }

    // ── Build today's title/body/payload from the active medicines ─────────
    // A single medicine keeps the exact wording/payload shape used before
    // grouping existed. Two-or-more collapse into one InboxStyle notification
    // with a "Take all" action, per Google's own grouping guidance: group only
    // when children are independently complete/actionable — a shared dose time
    // isn't, so one merged notification beats N near-identical ones.
    InboxStyleInformation? inboxStyle;
    if (rawMedicines.isNotEmpty) {
      final hour = slotHour ?? 0;
      final minute = slotMinute ?? 0;
      // The dose this notification is about, stamped at FIRE time so a
      // Take/Skip tapped minutes (or a midnight) later can't be misattributed.
      final doseEpochMs = doseInstant.millisecondsSinceEpoch;
      if (activeToday.length == 1) {
        final med = activeToday.single;
        title = 'Medicine Reminder 💊';
        body = 'Time to take ${med['name']}';
        payload = 'alarm:${jsonEncode({
              'id': alarmId,
              'title': 'Time for your ${med['name']}',
              'body': 'Medicine reminder',
              if (alarmData['snoozeDuration'] != null)
                'snoozeDuration': alarmData['snoozeDuration'],
              'medicineId': med['medicineId'],
              'hour': hour,
              'minute': minute,
              'doseEpochMs': doseEpochMs,
            })}';
      } else {
        title = 'Medicine Reminder 💊 · ${activeToday.length} due';
        body = '${activeToday.length} medicines due now';
        inboxStyle = InboxStyleInformation(
          activeToday.map((m) => m['name']?.toString() ?? '').toList(),
          contentTitle: title,
          summaryText: body,
        );
        payload = 'alarm:${jsonEncode({
              'id': alarmId,
              'title': title,
              'body': activeToday
                  .map((m) => m['name']?.toString() ?? '')
                  .join(', '),
              if (alarmData['snoozeDuration'] != null)
                'snoozeDuration': alarmData['snoozeDuration'],
              'medicines': activeToday
                  .map((m) => {
                        'medicineId': m['medicineId'],
                        'name': m['name'],
                      })
                  .toList(),
              'hour': hour,
              'minute': minute,
              'doseEpochMs': doseEpochMs,
            })}';
      }

      // Persist today's resolved view so a snooze re-fire (which reads this
      // same 'alarm_$alarmId' entry) shows the same medicines/payload rather
      // than falling back to a generic reminder.
      alarmData['title'] = title;
      alarmData['body'] = body;
      alarmData['payload'] = payload;
      alarmData['medicines'] = activeToday;
      await prefs.setString('alarm_$alarmId', jsonEncode(alarmData));
    }

    // Initialize notifications plugin
    final notifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('🔔 Background notification action: ${response.actionId}');
        stopRingingAlarmScreen(response.id);
        if (response.actionId == 'snooze') {
          await _handleBackgroundSnooze(response.id ?? 0, prefs);
        } else if (response.actionId == 'dismiss') {
          await notifications.cancel(response.id ?? 0);
          debugPrint('✓ Notification dismissed via tap (callback): ${response.id}');
        } else if (response.actionId == 'take') {
          await handleDoseNotificationAction(response.payload, DoseActionQueue.actionTake);
        } else if (response.actionId == 'skip') {
          await handleDoseNotificationAction(response.payload, DoseActionQueue.actionSkip);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    
    // Get snooze interval from stored settings (default 5 minutes), override if in alarmData
    var snoozeMinutes = prefs.getInt(snoozeIntervalMinutesKey) ??
        defaultSnoozeIntervalMinutes;
    if (alarmData['snoozeDuration'] != null) {
      snoozeMinutes = alarmData['snoozeDuration'] as int;
    }

    // Use system default alarm sound (null = default sound from channel)
    // The channel is configured with audioAttributesUsage: alarm
    // which makes it use the alarm audio stream and ring like a real alarm
    
    // A grouped medicine slot (2+ medicines due at the same time) collapses to
    // ONE notification, not one-per-medicine. Android shows at most 3 action
    // buttons, so a group trades Dismiss for "Take all" + Snooze only —
    // per-medicine Take/Skip stays in-app, where it already works.
    final isGroup = rawMedicines.isNotEmpty && activeToday.length > 1;

    // What this alarm IS decides how loudly it announces itself. This block used
    // to hardcode `alarm_channel`, a full-screen takeover and a `✓ Take` button
    // for everything, discarding the `channelId` its caller had passed — so
    // vitals check-ins and the onboarding daily prompt arrived as full-screen
    // ringing medicine alarms offering to log a dose that does not exist.
    final kind = ReminderKind.fromBlob(alarmData);
    final look = alarmPresentationFor(
      kind,
      isGroup: isGroup,
      snoozeMinutes: snoozeMinutes,
      // The user's "Snooze enabled" choice, mirrored out of UserSettings by
      // saveUserSettings because this isolate has no Drift connection. Read
      // here so turning snoozing off actually removes the button: it was
      // mirrored and then read by nothing, so the setting did nothing.
      snoozeEnabled: prefs.getBool(snoozeEnabledKey) ?? true,
      requestedChannelId: alarmData['channelId'] as String?,
      requestedChannelName: alarmData['channelName'] as String?,
    );

    final androidDetails = AndroidNotificationDetails(
      look.channelId,
      look.channelName,
      channelDescription: look.channelDescription,
      importance: look.importance,
      priority: look.priority,
      playSound: true,
      sound: null, // Use system default sound from the channel
      enableVibration: true,
      vibrationPattern: Int64List.fromList(look.vibrationPattern),
      enableLights: true,
      ledColor: const Color(0xFF4CAF50),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: look.fullScreenIntent,
      category: look.category,
      // Honour the user's "Show on lock screen" choice.
      //
      // This was hardcoded `public`, and because ALL Android medicine
      // reminders route through this service, the settings-driven branch in
      // NotificationService was only ever reached on the iOS fallback — so the
      // toggle did nothing on the platform this app primarily ships to. The
      // body here is "Time to take <medicine name>", so a locked phone on a
      // desk announced the user's prescription to the room.
      //
      // Read from SharedPreferences rather than the DB: this runs in the alarm
      // isolate, which has no Drift connection. Default is PRIVATE — for a
      // medication app the safe default is not showing the drug name.
      visibility: (prefs.getBool(kShowOnLockScreenPref) ?? false)
          ? NotificationVisibility.public
          : NotificationVisibility.private,
      showWhen: true,
      autoCancel: look.autoCancel,
      channelShowBadge: true,
      styleInformation: inboxStyle,
      audioAttributesUsage: look.audioUsage,
      actions: look.actions,
      ongoing: look.ongoing,
      timeoutAfter: look.timeoutAfterMs,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await notifications.show(
      alarmId,
      title,
      body,
      details,
      payload: payload,
    );
    
    debugPrint('✅ Notification shown successfully!');
    
    // Check if this is a repeating alarm - reschedule for next occurrence
    final isRepeating = alarmData['isRepeating'] as bool? ?? false;
    if (isRepeating) {
      await _rescheduleRepeatingAlarm(alarmId, alarmData, prefs);
    }
    // A non-repeating fire (a one-time reminder's first fire, OR ANY snoozed
    // re-fire, which always carries isRepeating:false) deliberately does NOT
    // delete 'alarm_$alarmId' here anymore. It used to, which deleted the
    // blob microseconds after showing — long before a human could react —
    // so a snooze tap on THIS notification would find no data and silently
    // fail. That made every snooze path cap at exactly one attempt
    // regardless of maxSnoozeCount. The blob is small and harmless to leave;
    // it's simply overwritten the next time this id is reused for a genuine
    // new snooze, and protected ids (medicine slots, window nudges) are never
    // touched by the pruning sweeps' snooze-range exclusion either way.

  } catch (e, stack) {
    debugPrint('❌ Alarm callback error: $e');
    debugPrint('Stack: $stack');
    // Try to reschedule even on error to prevent alarm from being lost
    await _attemptRescheduleOnError(alarmId);
  }
}

/// Reschedule a repeating alarm for the next occurrence
@pragma('vm:entry-point')
Future<void> _rescheduleRepeatingAlarm(
  int alarmId,
  Map<String, dynamic> alarmData,
  SharedPreferences prefs,
) async {
  try {
    final frequency = alarmData['frequency'] as String? ?? 'daily';
    final hour = (alarmData['hour'] as num?)?.toInt() ?? 8;
    final minute = (alarmData['minute'] as num?)?.toInt() ?? 0;

    // The next occurrence AFTER now — not "today + 1 day". A fire delivered
    // late (the reboot catch-up: a phone that was off at 08:00 receives
    // yesterday's alarm the instant it boots at 07:00) used to arm TOMORROW
    // and silently skip today's dose entirely. See [nextRepeatOccurrence].
    final nextOccurrence = nextRepeatOccurrence(
      DateTime.now(),
      hour,
      minute,
      frequency: frequency,
    );

    debugPrint('📅 Rescheduling alarm $alarmId for ${nextOccurrence.toString()}');

    // Schedule the next occurrence (downgrades to inexact rather than being
    // dropped when SCHEDULE_EXACT_ALARM is revoked — otherwise a revoked
    // permission killed the whole repeating chain from here on).
    final result = await _registerAlarm(nextOccurrence, alarmId);

    debugPrint('✓ Alarm rescheduled: $result');
  } catch (e) {
    debugPrint('❌ Failed to reschedule repeating alarm: $e');
  }
}

/// Reschedules a window nudge's day-1 start for tomorrow — the window-nudge
/// analog of [_rescheduleRepeatingAlarm], but deliberately inexact (see
/// [BackgroundAlarmService.scheduleWindowNudge]'s doc for why); kept separate
/// rather than adding a branch to the shared function so nothing about the
/// existing exact-alarm reminder types changes.
@pragma('vm:entry-point')
Future<void> _rescheduleWindowNudgeStart(
  int alarmId,
  Map<String, dynamic> alarmData,
  SharedPreferences prefs,
) async {
  try {
    final hour = (alarmData['hour'] as num?)?.toInt() ?? 8;
    final minute = (alarmData['minute'] as num?)?.toInt() ?? 0;
    // Same late-delivery fix as [_rescheduleRepeatingAlarm]: a nudge start
    // delivered after its own time (boot catch-up, Doze batching) must not
    // skip the day it lands on.
    final nextOccurrence = nextRepeatOccurrence(DateTime.now(), hour, minute);

    debugPrint('📅 Rescheduling window nudge $alarmId for $nextOccurrence');
    final result = await _registerAlarm(
      nextOccurrence,
      alarmId,
      preferExact: false,
      alarmClock: false,
    );
    debugPrint('✓ Window nudge rescheduled: $result');
  } catch (e) {
    debugPrint('❌ Failed to reschedule window nudge: $e');
  }
}

/// Handles a Phase 4 reminder-window nudge — a synthetic per-medicine alarm
/// (start/middle/end of a window), structurally separate from the medicine
/// slot gate in [alarmCallback]: a nudge never groups with other medicines,
/// and instead of firing once, it fires up to 3 times, chaining the next
/// nudge itself and stopping the moment the dose is resolved (taken/
/// skipped, via ANY path — a notification action, in-app, or "Take all" on
/// an unrelated grouped reminder). See reminder_window_nudges.dart for the
/// pure minute-of-day math and the shared resolved-flag key format.
@pragma('vm:entry-point')
Future<void> _handleWindowNudge(
  int alarmId,
  Map<String, dynamic> alarmData,
  SharedPreferences prefs,
) async {
  final medicineId = alarmData['medicineId'] as String? ?? '';
  final medicineName = alarmData['medicineName'] as String? ?? 'your medicine';
  final hour = (alarmData['hour'] as num?)?.toInt() ?? 8;
  final minute = (alarmData['minute'] as num?)?.toInt() ?? 0;
  final nudgeIndex = (alarmData['nudgeIndex'] as num?)?.toInt() ?? 0;
  // The canonical windowNudgeId(medicineIndex, timeIndex, 0), NOT this fire's
  // own alarmId — a snoozed re-fire's alarmId is offset by +100000, and
  // chaining off that directly would manufacture an id outside the range
  // MedicationReminderService._recomputeWindowNudges protects from pruning.
  final baseAlarmId = (alarmData['baseAlarmId'] as num?)?.toInt() ?? alarmId;
  final nudgeMinutes = ((alarmData['nudgeMinutes'] as List?) ?? const [])
      .map((m) => (m as num).toInt())
      .toList();
  final isRepeating = alarmData['isRepeating'] as bool? ?? false;
  final now = DateTime.now();
  // The window's START (hour:minute) is the canonical dose identity — every
  // nudge in the sequence resolves to the SAME doseLogId, regardless of
  // which nudge the user actually acts on. Resolved against `now` rather than
  // assumed to be today: a window that spans midnight (start 23:00 + 120 min)
  // fires its later nudges on the NEXT calendar day, where "today at 23:00"
  // would be a different — future — dose, breaking both the resolved-flag
  // gate and any Take/Skip logged from that nudge.
  final scheduledTime = resolveDoseInstant(now, hour, minute);

  // Gate 1: is this medicine's regimen even active today (specific-days /
  // cyclical / past end-date, etc.)? Fail open on any parse error — never
  // silently drop a dose.
  final scheduleJson = alarmData['scheduleJson'] as String?;
  var activeToday = true;
  if (scheduleJson != null && scheduleJson.isNotEmpty) {
    try {
      activeToday = MedicineSchedule.fromJson(
              jsonDecode(scheduleJson) as Map<String, dynamic>)
          .isActiveOnDate(scheduledTime);
    } catch (e) {
      debugPrint(
          '⚠️ Window nudge schedule gate parse failed (firing anyway): $e');
    }
  }

  if (!activeToday) {
    debugPrint('⏭️ Window nudge $alarmId: medicine inactive today — skipping');
    if (isRepeating) {
      await _rescheduleWindowNudgeStart(alarmId, alarmData, prefs);
    } else {
      await prefs.remove('alarm_$alarmId');
    }
    return;
  }

  // Gate 2: has this exact dose already been resolved (taken/skipped) —
  // whether via an earlier nudge, in-app, or a "Take all" on a different
  // reminder entirely? If so, this nudge stays silent.
  final resolvedKey = nudgeResolvedKey(medicineId, scheduledTime);
  final alreadyResolved = prefs.getBool(resolvedKey) ?? false;

  if (!alreadyResolved) {
    final payload = 'alarm:${jsonEncode({
          'id': alarmId,
          'title': 'Time for your $medicineName',
          'body': 'Medicine reminder',
          'medicineId': medicineId,
          'hour': hour,
          'minute': minute,
          // The dose identity, resolved once here so a Take/Skip tapped from
          // this nudge logs against the same instant the resolved-flag uses.
          'doseEpochMs': scheduledTime.millisecondsSinceEpoch,
        })}';

    final notifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        stopRingingAlarmScreen(response.id);
        if (response.actionId == 'snooze') {
          await _handleBackgroundSnooze(response.id ?? 0, prefs);
        } else if (response.actionId == 'dismiss') {
          await notifications.cancel(response.id ?? 0);
        } else if (response.actionId == 'take') {
          await handleDoseNotificationAction(response.payload, DoseActionQueue.actionTake);
        } else if (response.actionId == 'skip') {
          await handleDoseNotificationAction(response.payload, DoseActionQueue.actionSkip);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final snoozeMinutes = prefs.getInt(snoozeIntervalMinutesKey) ??
        defaultSnoozeIntervalMinutes;
    final isLast = nudgeIndex >= nudgeMinutes.length - 1;
    final baseTitle = nudgeIndex == 0
        ? 'Time for $medicineName'
        : (isLast ? 'Last call for $medicineName' : 'Still time for $medicineName');
    // _scheduleSnoozeNotification only ever sets 'title' for a window-nudge
    // snooze re-fire (the initial schedule/chain paths never do) — reuse that
    // as the signal to keep the ⏰ prefix consistent with every other snoozed
    // reminder type in the app.
    final title = alarmData['title'] != null ? '⏰ $baseTitle' : baseTitle;
    const body = 'Take it before your window closes.';

    final androidDetails = AndroidNotificationDetails(
      'medicine_channel',
      'Medicine Reminders',
      channelDescription: 'Reminders for taking medicines on time',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'take',
          '✓ Take',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze',
          '⏰ Snooze ${snoozeMinutes}min',
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'skip',
          '✕ Skip',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
      autoCancel: false,
      timeoutAfter: 300000,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await notifications.show(
      alarmId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
    debugPrint('✅ Window nudge shown: $title');
  } else {
    debugPrint('⏭️ Window nudge $alarmId: dose already resolved — suppressing');
  }

  // Has this dose's window already closed? A nudge delivered long after its
  // own time (the boot catch-up: a phone that was off all night receives
  // yesterday's start nudge the moment it powers on) has nothing left to nudge
  // toward — chaining then would fire the remaining nudges seconds apart. The
  // small in-window drift an inexact alarm normally has is still chained
  // immediately, below.
  final startMinuteOfDay = hour * 60 + minute;
  final windowClosed = nudgeMinutes.isNotEmpty &&
      now.isAfter(scheduledTime
          .add(Duration(minutes: nudgeMinutes.last - startMinuteOfDay)));

  // Chain the NEXT nudge (only if this dose is still unresolved, its window is
  // still open, and there is a next one in the sequence).
  if (!alreadyResolved && !windowClosed && nudgeIndex < nudgeMinutes.length - 1) {
    final nextMinute = nudgeMinutes[nudgeIndex + 1];
    // Offset from the DOSE's own start instant, not from "today" — a window
    // that runs past midnight (start 23:00, nudgeMinutes up to 1500) has
    // later nudges on the following calendar day, and anchoring them to the
    // current day would jump them a further 24h each time.
    var nextTime =
        scheduledTime.add(Duration(minutes: nextMinute - startMinuteOfDay));
    if (nextTime.isBefore(now)) {
      // A delayed/batched fire (inexact alarms can drift) pushed us past the
      // next nudge's instant — fire it almost immediately rather than lose it.
      nextTime = now.add(const Duration(seconds: 5));
    }
    // Off baseAlarmId, NOT alarmId: a snoozed re-fire's alarmId is offset by
    // +100000, and alarmId+1 would chain into that offset range instead of
    // the canonical windowNudgeId(...) — see baseAlarmId's doc above.
    final nextId = baseAlarmId + nudgeIndex + 1;
    final nextData = {
      ...alarmData,
      'nudgeIndex': nudgeIndex + 1,
      'isRepeating': false,
      // A fresh nudge, not a snooze re-fire — reset the count a prior snooze
      // of THIS nudge may have left in the spread alarmData, or it would
      // wrongly eat into the next nudge's own snooze allowance.
      'snoozeCount': 0,
    };
    await prefs.setString('alarm_$nextId', jsonEncode(nextData));
    await _registerAlarm(nextTime, nextId,
        preferExact: false, alarmClock: false);
    debugPrint('✓ Chained next window nudge: id=$nextId at $nextTime');
  }

  if (isRepeating) {
    // Nudge 0 self-reschedules for tomorrow, exactly like a medicine slot —
    // regardless of whether today's dose was resolved (tomorrow's is fresh).
    await _rescheduleWindowNudgeStart(alarmId, alarmData, prefs);
  }
  // The final nudge's blob is deliberately NOT removed here anymore — same
  // fix and same reasoning as alarmCallback's main tail: deleting it right
  // after showing meant the "last call" nudge (arguably the one most worth
  // snoozing) could never be snoozed even once. neededIds in
  // MedicationReminderService._recomputeWindowNudges already protects every
  // nudge id unconditionally, so leaving this one inert is harmless.
}

/// Attempt to reschedule alarm on error to prevent data loss
@pragma('vm:entry-point')
Future<void> _attemptRescheduleOnError(int alarmId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final alarmDataJson = prefs.getString('alarm_$alarmId');
    if (alarmDataJson == null) return;
    
    final alarmData = jsonDecode(alarmDataJson) as Map<String, dynamic>;
    final isRepeating = alarmData['isRepeating'] as bool? ?? false;
    
    if (isRepeating) {
      await _rescheduleRepeatingAlarm(alarmId, alarmData, prefs);
    }
  } catch (e) {
    debugPrint('❌ Error recovery failed: $e');
  }
}

/// Background Alarm Service - schedules alarms that work when app is closed
/// Mirror of `UserSettings.showOnLockScreen` in SharedPreferences.
///
/// The alarm fires in a background isolate with no Drift connection, so it
/// cannot call `CleanStorageService.getUserSettings()`. The main isolate
/// mirrors the flag here whenever settings are saved.
const String kShowOnLockScreenPref = 'notif_show_on_lock_screen';

class BackgroundAlarmService {
  static final BackgroundAlarmService _instance = BackgroundAlarmService._internal();
  
  factory BackgroundAlarmService() => _instance;
  
  BackgroundAlarmService._internal();
  
  bool _isInitialized = false;
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Initialize timezone from the REAL device zone (never hardcode).
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(
            tz.getLocation(await FlutterTimezone.getLocalTimezone()));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
      
      // Initialize Android Alarm Manager
      if (Platform.isAndroid) {
        final result = await AndroidAlarmManager.initialize();
        debugPrint('✓ BackgroundAlarmService initialized: $result');
      }
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ BackgroundAlarmService init failed: $e');
    }
  }

  /// `true` when the most recent scheduling pass had to register alarms
  /// INEXACTLY because Android refused exact ones (SCHEDULE_EXACT_ALARM not
  /// granted / revoked). Reminders still fire, but within the OS's batching
  /// window rather than to the minute — worth telling the user, since the
  /// alternative (what happened before) was firing not at all.
  ///
  /// Exposed for the permission banner via
  /// [NotificationService.remindersDowngradedToInexact].
  Future<bool> exactAlarmsDowngraded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(exactAlarmsDowngradedKey) ?? false;
    } catch (_) {
      return false;
    }
  }


  /// Schedule a one-time alarm
  Future<bool> scheduleOneTimeAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    String channelId = 'medicine_channel',
    /// How loudly this announces itself. See [ReminderKind]; defaults to the
    /// historical behaviour of this method so an un-updated caller is unchanged.
    ReminderKind kind = ReminderKind.dose,
    String channelName = 'Medicine Reminders',
    int? snoozeDuration,
    String? sound,
    String? payload,
  }) async {
    try {
      await init();
      
      // Store alarm data in shared preferences
      final prefs = await SharedPreferences.getInstance();
      final alarmData = {
        'title': title,
        'body': body,
        'channelId': channelId,
        'kind': kind.name,
        'channelName': channelName,
        'scheduledTime': dateTime.toIso8601String(),
        'isRepeating': false,
        'snoozeDuration': snoozeDuration,
        'sound': sound,
        'payload': payload,
      };
      await prefs.setString('alarm_$id', jsonEncode(alarmData));
      
      debugPrint('📅 Scheduling alarm ID: $id for ${dateTime.toString()}');

      // Schedule the alarm
      final result = await _registerAlarm(dateTime, id);

      debugPrint('✓ Alarm scheduled: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to schedule alarm: $e');
      return false;
    }
  }
  
  /// Schedule a daily repeating alarm
  Future<bool> scheduleDailyAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String channelId = 'medicine_channel',
    /// How loudly this announces itself. See [ReminderKind]; defaults to the
    /// historical behaviour of this method so an un-updated caller is unchanged.
    ReminderKind kind = ReminderKind.dose,
    String channelName = 'Medicine Reminders',
    int? snoozeDuration,
    String? sound,
    String? payload,
    String? scheduleJson,
    List<Map<String, dynamic>>? medicines,
  }) async {
    try {
      await init();

      // Calculate next occurrence
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Store alarm data
      final prefs = await SharedPreferences.getInstance();
      final alarmData = {
        'title': title,
        'body': body,
        'channelId': channelId,
        'kind': kind.name,
        'channelName': channelName,
        'hour': hour,
        'minute': minute,
        'isRepeating': true,
        'frequency': 'daily',
        'snoozeDuration': snoozeDuration,
        'sound': sound,
        'payload': payload,
        // Legacy single-medicine active-day gate (still used by non-medicine
        // repeating alarms, e.g. water/sleep/fitness).
        'scheduleJson': scheduleJson,
        // Medicine slot alarms (Phase 1 grouping): one entry per medicine due
        // at this clock time, each carrying its OWN schedule for the
        // alarmCallback gate. Absent/empty for non-medicine alarms.
        if (medicines != null) 'medicines': medicines,
      };
      await prefs.setString('alarm_$id', jsonEncode(alarmData));
      
      debugPrint('📅 Scheduling daily alarm ID: $id for $hour:$minute');

      // For daily alarms, we schedule the first occurrence and reschedule in
      // the callback. Registration goes through [_registerAlarm] so a revoked
      // SCHEDULE_EXACT_ALARM downgrades the alarm instead of silently dropping
      // it — android_alarm_manager_plus returns `true` either way, so this
      // used to leave the patient with no reminders and no indication of it.
      final result = await _registerAlarm(scheduledDate, id);

      debugPrint('✓ Daily alarm scheduled: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to schedule daily alarm: $e');
      return false;
    }
  }
  
  /// Schedules nudge index 0 (a reminder window's start) as a self-
  /// rescheduling daily alarm — the same "compute next occurrence, persist,
  /// register" shape as [scheduleDailyAlarm], but deliberately INEXACT: no
  /// `alarmClock`, no `exact`. A window nudge tolerates a few minutes of OS
  /// batching/drift by design (that tolerance is the whole point of a
  /// window), so it doesn't need — and shouldn't claim — the restricted
  /// exact-alarm permission the way a patient's precise-time reminder does.
  /// Nudges 1 and 2 (if this window has them) are chained by [alarmCallback]
  /// itself each time the previous nudge fires; this method only ever
  /// schedules index 0 directly.
  Future<bool> scheduleWindowNudge({
    required int id,
    required String medicineId,
    required String medicineName,
    required int hour, // the dose's window START — the canonical dose identity
    required int minute,
    required List<int> nudgeMinutes, // nudgeMinutes[0] == hour*60+minute
    required String scheduleJson,
  }) async {
    try {
      await init();

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final prefs = await SharedPreferences.getInstance();
      final alarmData = {
        'isWindowNudge': true,
        // The canonical windowNudgeId(medicineIndex, timeIndex, 0) — kept
        // alongside the alarm id that actually fires so chaining can compute
        // windowNudgeId(...,  nudgeIndex+1) as `baseAlarmId + nudgeIndex + 1`
        // even from a snoozed re-fire, whose OWN id is offset by +100000.
        'baseAlarmId': id,
        'nudgeIndex': 0,
        'nudgeMinutes': nudgeMinutes,
        'medicineId': medicineId,
        'medicineName': medicineName,
        'hour': hour,
        'minute': minute,
        'channelId': 'medicine_channel',
        'channelName': 'Medicine Reminders',
        'isRepeating': true,
        'scheduleJson': scheduleJson,
      };
      await prefs.setString('alarm_$id', jsonEncode(alarmData));

      debugPrint('📅 Scheduling window nudge ID: $id at $hour:$minute');

      final result = await _registerAlarm(scheduledDate, id,
          preferExact: false, alarmClock: false);

      debugPrint('✓ Window nudge scheduled: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to schedule window nudge: $e');
      return false;
    }
  }

  /// Arm the one-off follow-up for an unresolved reminder occurrence.
  ///
  /// Inexact and non-alarm-clock by design: a follow-up is already late by
  /// definition, so it does not need — or deserve — the restricted exact-alarm
  /// permission. Same reasoning as [scheduleWindowNudge].
  ///
  /// Cheaper than a background sweep, and it works while the app is dead, which
  /// is the only state that matters: a user who is in the app does not need a
  /// follow-up notification.
  Future<bool> scheduleReminderFollowUp({
    required int id,
    required String reminderId,
    required DateTime occurrenceDue,
    required DateTime fireAt,
    required String title,
    required String body,
    String channelId = 'checkin_channel',
    String channelName = 'Check-ins & Nudges',
    required ReminderEscalation escalation,
  }) async {
    try {
      await init();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'alarm_$id',
        jsonEncode({
          'isReminderFollowUp': true,
          'reminderId': reminderId,
          'occurrenceMs': occurrenceDue.millisecondsSinceEpoch,
          'title': title,
          'body': body,
          'channelId': channelId,
          'channelName': channelName,
          'kind': ReminderKind.alarm.name,
          'isRepeating': false,
          // The TIER, not a pre-computed flag: what it implies is decided by
          // [nextEscalationStep] at fire time, in one place.
          'escalation': escalation.name,
          'round': 1,
        }),
      );
      final ok = await _registerAlarm(fireAt, id,
          preferExact: false, alarmClock: false);
      debugPrint('📅 Reminder follow-up armed for $fireAt: $ok');
      return ok;
    } catch (e) {
      debugPrint('❌ Failed to arm reminder follow-up: $e');
      return false;
    }
  }

  /// Cancel an alarm
  Future<bool> cancelAlarm(int id) async {
    try {
      final result = await AndroidAlarmManager.cancel(id);
      
      // Remove alarm data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_$id');
      
      debugPrint('✓ Alarm $id cancelled: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to cancel alarm: $e');
      return false;
    }
  }
  
  /// Schedule a quick test alarm (10 seconds)
  Future<bool> scheduleQuickTest() async {
    final testTime = DateTime.now().add(const Duration(seconds: 10));
    return scheduleOneTimeAlarm(
      id: 99998,
      dateTime: testTime,
      title: 'Test Alarm ✅',
      body: 'Background alarm works! Your reminders will fire even when the app is closed.',
    );
  }
  
  /// Get all scheduled alarms
  Future<List<Map<String, dynamic>>> getScheduledAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = <Map<String, dynamic>>[];
    
    for (final key in prefs.getKeys()) {
      if (key.startsWith('alarm_')) {
        final data = prefs.getString(key);
        if (data != null) {
          try {
            final alarm = jsonDecode(data) as Map<String, dynamic>;
            alarm['id'] = int.tryParse(key.replaceFirst('alarm_', '')) ?? 0;
            alarms.add(alarm);
          } catch (e) {
            debugPrint('Error parsing alarm data: $e');
          }
        }
      }
    }
    
    return alarms;
  }
}

/// Snooze a notification that has NO `alarm_$id` blob.
///
/// Everything armed through `zonedSchedule` rather than AlarmManager lands here:
/// water reminders, weekly/weekdays/weekends/custom generic reminders, focus.
/// All it has to work from is the `alarm:{json}` payload, so a dose must never
/// come through this path — [handleSnoozeAction] routes anything with a blob to
/// [_scheduleSnoozeNotification], which preserves hour/minute and the medicines
/// list. Without those, a "✓ Take" on the snoozed re-fire would log the dose
/// against midnight.
@pragma('vm:entry-point')
Future<void> _snoozeFromPayload(int notificationId, String? payload) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Parse the rich `alarm:{json}` payload for a clean title/body — otherwise
    // the raw JSON would be shown as the notification body. Parsed FIRST
    // because the reminder's own snooze duration rides in it too.
    var snoozeTitle = '⏰ Snoozed Reminder';
    var snoozeBody = 'Time for your reminder!';
    Map<String, dynamic>? decodedPayload;
    if (payload != null && payload.startsWith('alarm:')) {
      try {
        final decoded = jsonDecode(payload.substring('alarm:'.length));
        if (decoded is Map) {
          decodedPayload = Map<String, dynamic>.from(decoded);
          snoozeTitle = '⏰ Snoozed: ${decoded['title'] ?? 'Reminder'}';
          snoozeBody = (decoded['body'] ?? snoozeBody).toString();
        }
      } catch (_) {}
    }

    // This reminder's OWN snooze duration wins over the global preference, for
    // the same reason as in [_scheduleSnoozeNotification]: the button the user
    // tapped was labelled with the per-reminder value, so rescheduling off the
    // global one brought a "Snooze 30min" reminder back in 5.
    final snoozeMinutes = (decodedPayload?['snoozeDuration'] as num?)?.toInt() ??
        prefs.getInt(snoozeIntervalMinutesKey) ??
        defaultSnoozeIntervalMinutes;

    // Initialize timezone. Snooze uses a RELATIVE offset (now + minutes) so the
    // absolute instant is correct regardless, but keep tz.local honest instead
    // of the old hardcoded IST.
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    
    // Calculate snooze time
    final now = tz.TZDateTime.now(tz.local);
    final snoozeTime = now.add(Duration(minutes: snoozeMinutes));
    // Same clamp snoozeReminder applies, so both snooze paths land on the SAME
    // id for the same notification — otherwise one path's reschedule could not
    // be cancelled by the other's, leaving two copies of one reminder.
    final snoozeId = (notificationId + snoozeIdOffset) & 0x7FFFFFFF;

    // The ONE counter, shared with the AlarmManager path and with
    // NotificationService.snoozeReminder —
    // NOT a payload-embedded count. This handler and snoozeReminder register
    // on the SAME plugin instance for the SAME notifications (this one fires
    // when the app is dead at tap time, snoozeReminder when it's alive), so a
    // separate counter here would let alternating foreground/background
    // snooze taps bypass the cap entirely. 'baseId' rides in the payload
    // (falling back to notificationId for a payload that predates this field,
    // i.e. a never-yet-snoozed notification) so this stays correct across any
    // number of hops without needing the CleanStorageService.getReminders()
    // lookup snoozeReminder uses — unsafe to call from this background isolate.
    final baseId =
        resolveSnoozeBaseId(notificationId, decodedPayload?['baseId']);
    final isFreshFire = notificationId == baseId;
    final snoozeCountKey = snoozeCountKeyFor(baseId);
    final snoozeCount = isFreshFire ? 0 : (prefs.getInt(snoozeCountKey) ?? 0);

    // Raw pref key rather than CleanStorageService, which transitively imports
    // Drift and is unsafe in this isolate; saveUserSettings mirrors it out.
    final maxSnoozeCount =
        prefs.getInt(maxSnoozeCountKey) ?? defaultMaxSnoozeCount;
    if (snoozeCount >= maxSnoozeCount) {
      // The tapped notification is ALREADY gone by this point (Android's
      // ActionBroadcastReceiver auto-cancels for a showsUserInterface:false
      // action) — show a final, snooze-less one rather than lose the
      // reminder entirely. See background_alarm_service.dart's identical fix.
      debugPrint(
          '⏹️ Snooze cap ($maxSnoozeCount) reached for notification $notificationId — showing a final reminder with no snooze option');
      await _showFinalCappedPayloadNotification(notificationId, snoozeTitle, snoozeBody, payload);
      return;
    }
    await prefs.setInt(snoozeCountKey, snoozeCount + 1);
    final nextPayload = decodedPayload == null
        ? payload
        : 'alarm:${jsonEncode({...decodedPayload, 'baseId': baseId})}';

    // Initialize notifications plugin for background
    final notifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await notifications.initialize(initSettings);

    // Schedule snoozed notification using alarm channel.
    //
    // Guarded: a snooze re-fire is exactly the case where a swallowed
    // `exact_alarms_not_permitted` is worst — the user asked to be reminded again
    // and silently was not.
    await zonedScheduleGuarded(
      PluginNotificationScheduler(notifications),
      snoozeId,
      snoozeTitle,
      snoozeBody,
      snoozeTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel', // Use alarm channel for proper alarm sound
          'Alarm Reminders',
          channelDescription: 'High priority alarm reminders',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: null, // Use system default alarm sound
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          // Honour 'Show on lock screen', default PRIVATE — the same policy
          // `alarmCallback` applies a few hundred lines up. This path is a
          // SNOOZED DOSE re-firing, so its title is a medicine name; pinning it
          // public put "Take sertraline" on a locked screen for anyone walking
          // past, whatever the user had chosen.
          visibility: (prefs.getBool(kShowOnLockScreenPref) ?? false)
              ? NotificationVisibility.public
              : NotificationVisibility.private,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          autoCancel: false,
          ongoing: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'snooze',
              '⏰ Snooze ${snoozeMinutes}min',
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'dismiss',
              '❌ Dismiss',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: nextPayload,
      debugLabel: 'background snooze',
    );

    // Cancel the original notification
    await notifications.cancel(notificationId);
    
    debugPrint('✓ Background snooze scheduled for $snoozeMinutes min (ID: $snoozeId)');
  } catch (e) {
    debugPrint('❌ Background snooze failed: $e');
  }
}

/// Twin of [_showFinalCappedNotification] for the payload path — shown once
/// the snooze cap is reached, since the OS already removed the tapped
/// notification by the time this handler runs.
@pragma('vm:entry-point')
Future<void> _showFinalCappedPayloadNotification(
    int id, String title, String body, String? payload) async {
  try {
    final notifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await notifications.initialize(initSettings);
    await notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarm Reminders',
          channelDescription: 'Reminder (snooze limit reached)',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction('dismiss', '❌ Dismiss',
                showsUserInterface: false, cancelNotification: true),
          ],
        ),
      ),
      payload: payload,
    );
  } catch (e) {
    debugPrint('❌ Final capped background notification failed: $e');
  }
}
