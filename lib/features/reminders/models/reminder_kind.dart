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
  gentle;

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

  bool get isAlarmGrade => this != ReminderKind.gentle;
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
