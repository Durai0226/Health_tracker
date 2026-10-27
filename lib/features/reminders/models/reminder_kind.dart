/// **Pure Dart on purpose — no Flutter, no plugins, no FFI.**
///
/// This enum used to live in `background_alarm_service.dart`, which transitively
/// pulls in flutter_local_notifications, android_alarm_manager_plus and sqlite3.
/// The moment `reminder_escalation.dart` referenced it, that whole graph became
/// a dependency of a pure policy object — and
/// `test/core/dst_date_arithmetic_probe.dart`, which runs under a bare
/// `dart run` precisely so it can pin the TZ, died in the FFI transformer with
/// "type 'InvalidType' is not a subtype of type 'FunctionType'".
///
/// A presentation *tier* is a value, not a service. Keep this file free of
/// imports so it stays usable from anywhere, including plain-Dart entrypoints.

/// What an alarm actually *is*, which decides how loudly it announces itself.
///
/// [alarmCallback] used to hardcode one shape for everything it fired:
/// `alarm_channel`, `fullScreenIntent: true`, `ongoing: true` and a `✓ Take`
/// button — discarding the `channelId` its caller had passed. So the four vitals
/// reminders ("time to check your blood pressure") and the onboarding daily
/// check-in arrived as full-screen ringing medicine alarms offering to log a dose
/// that does not exist. Focus and water each escaped this individually by
/// bypassing the service; nothing generalised the fix.
///
/// Serialised into the alarm blob by `.name`, not `.index`: the blob outlives the
/// build that wrote it, and reordering an enum must not silently repurpose alarms
/// already on disk.
enum ReminderKind {
  /// A medicine dose. Alarm-grade and loggable: full-screen, ongoing, and the
  /// `✓ Take` / `⏰ Snooze` / `✕ Dismiss` action set.
  dose,

  /// A time the *user* chose and expects to be woken by — the wake alarm, a
  /// generic reminder. Alarm-grade, but nothing to "take", so no dose actions.
  alarm,

  /// A nudge: vitals check-ins, the onboarding daily prompt, an appointment or
  /// cycle heads-up. Ordinary notification, ordinary audio stream, no
  /// full-screen takeover, no action buttons.
  gentle,

  /// A reminder the person asked to be quiet about ("Quiet — a silent
  /// notification"): it arrives in the shade with no sound and no vibration, never
  /// takes over the screen, and can still be marked Done or put off to Later.
  ///
  /// Apart from [gentle] because Android fixes a channel's sound when the channel
  /// is created, so "silent" needs a channel of its own — and because a Quiet
  /// reminder and a check-in nudge only looked different on the picker.
  quiet;

  static ReminderKind fromBlob(Map<String, dynamic> alarmData) {
    final wire = alarmData['kind'] as String?;
    if (wire != null) {
      for (final k in ReminderKind.values) {
        if (k.name == wire) return k;
      }
    }
    // Legacy blob, written before `kind` existed. Infer, biased toward
    // over-alerting: a user-set reminder that goes quiet is a worse failure than
    // a nudge that is louder than it needs to be for one cycle. The `✓ Take`
    // button — the actually-wrong part — is withheld either way.
    final hasMedicines = (alarmData['medicines'] as List?)?.isNotEmpty ?? false;
    if (hasMedicines) return ReminderKind.dose;
    return alarmData['channelId'] == 'medicine_channel'
        ? ReminderKind.dose
        : ReminderKind.alarm;
  }

  bool get isAlarmGrade => this == ReminderKind.dose || this == ReminderKind.alarm;
}

/// Answer buttons a check-in nudge can carry, so the question it asks is
/// answered from the notification without opening the app.
///
/// A nudge with answers carries NOTHING else: no Snooze (it would train the
/// person to put the question off) and no Dismiss (a swipe does that). Android
/// shows at most three buttons, and both sets here fit.
///
/// Serialised into the alarm blob by `.name`, like [ReminderKind].
enum NudgeAnswers {
  /// "How are you feeling?": Good · Okay · Bad.
  mood,

  /// "Today is around your predicted start": Started today · Not yet.
  period;

  static const String moodGoodId = 'mood_good';
  static const String moodOkayId = 'mood_okay';
  static const String moodBadId = 'mood_bad';
  static const String periodStartedId = 'period_started';
  static const String periodNotYetId = 'period_not_yet';

  /// Every action id the answers can produce, for a handler to recognise.
  static const Set<String> actionIds = {
    moodGoodId,
    moodOkayId,
    moodBadId,
    periodStartedId,
    periodNotYetId,
  };

  /// The Mood log's own scale (0 = Great … 4 = Terrible): the three buttons are
  /// its middle three values, so Good is 1, Okay is 2 and Bad is 3.
  static int? moodIndexFor(String? actionId) {
    switch (actionId) {
      case moodGoodId:
        return 1;
      case moodOkayId:
        return 2;
      case moodBadId:
        return 3;
    }
    return null;
  }

  /// Which answers an alarm blob asks for, if any.
  static NudgeAnswers? fromBlob(Map<String, dynamic> alarmData) {
    final wire = alarmData['answers'] as String?;
    if (wire == null) return null;
    for (final a in NudgeAnswers.values) {
      if (a.name == wire) return a;
    }
    return null;
  }
}

/// The buttons a general reminder's notification carries beyond Snooze: "Done"
/// ("I did it") and "Later" ("not now, don't lose it").
///
/// Only a reminder the person made in the Reminders feature has them — one whose
/// alarm payload names it ([reminderIdFromAlarmPayload]). Nothing else has a
/// "done" to mark.
class ReminderActions {
  const ReminderActions._();

  static const String doneId = 'reminder_done';
  static const String laterId = 'reminder_later';

  /// Every action id a reminder's notification can produce, for a handler to
  /// recognise.
  static const Set<String> ids = {doneId, laterId};
}

/// SharedPreferences key marking one *occurrence* of a generic reminder as
/// resolved.
///
/// The direct analogue of `nudgeResolvedKey` for medication windows, and it
/// exists for the same reason: a follow-up notification fires from the alarm
/// isolate, which has no Drift connection and therefore cannot see the
/// `ReminderOccurrences` row that says the user already acted. Without this
/// flag, a follow-up would nag about a reminder that was ticked off twenty
/// minutes ago.
///
/// Written from BOTH sides — the main isolate when an outcome is recorded, and
/// the background handler the moment a notification action is tapped, before
/// the main isolate ever drains anything. The two MUST agree byte-for-byte on
/// this format, which is why it lives here rather than being formatted at each
/// call site.
String reminderResolvedKey(String reminderId, DateTime scheduledFor) =>
    'reminder_resolved_${reminderId}_${scheduledFor.millisecondsSinceEpoch}';
