// The PURE enum file, deliberately not `background_alarm_service.dart` — that
// one drags in flutter_local_notifications, android_alarm_manager_plus and
// sqlite3, which would make this policy object unusable from a plain-Dart
// entrypoint (and did: it crashed the DST probe in the FFI transformer).
import 'reminder_kind.dart';

/// How hard a reminder pushes when it is ignored.
///
/// The single biggest adherence lever, and the one thing every review of this
/// category converges on: *most apps send one normal notification; you swipe it
/// away and the app assumes you took the dose.* Before this, escalation was
/// all-or-nothing — a reminder either rang as a full-screen alarm or it did not,
/// and the choice was made by which code path happened to schedule it.
///
/// Distinct from [ReminderKind], which is what a reminder *is* (a dose, a
/// user-set alarm, a nudge) and decides channel and buttons. This is how
/// *insistent* it is, and the two are genuinely independent: a daily vitamin is a
/// dose that can be gentle, and a heart medication is a dose that must not be.
/// Graded by importance rather than globally is the whole point — "time-critical
/// heart medication needs maximum persistence, a daily vitamin can be gentler".
enum ReminderEscalation {
  /// One quiet notification. Never rings, never follows up.
  gentle,

  /// One notification with sound. The default.
  standard,

  /// Sound, then a follow-up if nothing is logged, then auto-snooze until the
  /// user actually acts — the Due pattern, capped so it cannot nag forever.
  insistent,

  /// Everything [insistent] does, plus a full-screen alarm on the lock screen.
  ///
  /// Exact alarms and `USE_FULL_SCREEN_INTENT` are reserved for this tier alone.
  /// Play can revoke that permission for over-reach, and `USE_EXACT_ALARM` is
  /// deliberately absent from the manifest, so widening this is a policy
  /// decision and not a product one.
  critical;

  static ReminderEscalation fromName(String? name) {
    for (final v in ReminderEscalation.values) {
      if (v.name == name) return v;
    }
    return ReminderEscalation.standard;
  }

  /// The presentation tier this maps to.
  ///
  /// `gentle` is [ReminderKind.quiet]: no sound and no vibration, as its label
  /// and description promise — it used to share `standard`'s channel, so "Quiet"
  /// and "Normal" both made a sound. `standard` is an ordinary notification.
  /// Only `insistent` and `critical` are alarm-grade, and only `critical` takes
  /// over the screen.
  ReminderKind get kind {
    switch (this) {
      case ReminderEscalation.gentle:
        return ReminderKind.quiet;
      case ReminderEscalation.standard:
        return ReminderKind.gentle;
      case ReminderEscalation.insistent:
      case ReminderEscalation.critical:
        return ReminderKind.alarm;
    }
  }

  /// Whether the OS should be asked for an exact alarm.
  ///
  /// False for everything but [critical]. An inexact alarm can drift by up to an
  /// hour, which is fine for a nudge and not fine for a dose — and asking for
  /// exact everywhere is what gets the permission revoked.
  bool get wantsExactAlarm => this == ReminderEscalation.critical;

  /// Whether a full-screen takeover is permitted.
  bool get wantsFullScreen => this == ReminderEscalation.critical;

  /// Re-notify once if nothing is logged within [followUpAfter].
  ///
  /// The Apple Health Medications pattern: a second notification 30 minutes
  /// later if the dose has not been logged. Cheap, and it catches the single
  /// most common failure — the notification arrived while the user's hands were
  /// full and was dismissed by reflex.
  bool get hasFollowUp =>
      this == ReminderEscalation.insistent || this == ReminderEscalation.critical;

  Duration get followUpAfter => const Duration(minutes: 30);

  /// Keep re-notifying until the user completes or reschedules — the Due
  /// pattern, which its reviews single out as the reason the app works.
  ///
  /// Capped by the shared snooze counter, so "until acted on" cannot become
  /// "forever": at the cap a final, snooze-less notification is shown instead of
  /// the reminder silently disappearing.
  bool get autoSnoozeUntilActedOn => this == ReminderEscalation.critical;

  /// Human label for the picker.
  String get label {
    switch (this) {
      case ReminderEscalation.gentle:
        return 'Quiet';
      case ReminderEscalation.standard:
        return 'Normal';
      case ReminderEscalation.insistent:
        return 'Insistent';
      case ReminderEscalation.critical:
        return 'Critical';
    }
  }

  String get description {
    switch (this) {
      case ReminderEscalation.gentle:
        return 'A silent notification.';
      case ReminderEscalation.standard:
        return 'A notification with sound.';
      case ReminderEscalation.insistent:
        return "Reminds you again if you don't respond.";
      case ReminderEscalation.critical:
        return 'Full-screen alarm that keeps asking until you act.';
    }
  }
}

/// What to do at the moment an occurrence is still unresolved.
///
/// Pure: given how insistent the reminder is, how long ago it fired, and how
/// many times it has already been snoozed, decide the next step. Keeping this
/// separate from the scheduling machinery is what makes escalation testable at
/// all — the alternative is asserting against a real notification queue.
enum EscalationStep {
  /// Nothing to do — either resolved, too soon, or this tier does not follow up.
  none,

  /// Send the one-off "you haven't logged this yet" nudge.
  followUp,

  /// Re-arm the reminder itself.
  autoSnooze,

  /// The cap is reached: show a final notification with no snooze option rather
  /// than letting the reminder vanish.
  finalNotice,
}

/// Decide the next escalation step for an unresolved occurrence.
///
/// [sinceFired] is how long ago the notification appeared. [snoozeCount] is how
/// many times this occurrence has already been pushed back. [maxSnoozes] is the
/// user's cap.
EscalationStep nextEscalationStep({
  required ReminderEscalation escalation,
  required Duration sinceFired,
  required int snoozeCount,
  required int maxSnoozes,
  required bool resolved,
}) {
  if (resolved) return EscalationStep.none;
  if (!escalation.hasFollowUp) return EscalationStep.none;
  if (sinceFired < escalation.followUpAfter) return EscalationStep.none;

  // The first pass is the follow-up: one polite "still waiting" before anything
  // starts repeating.
  if (snoozeCount == 0) return EscalationStep.followUp;

  if (!escalation.autoSnoozeUntilActedOn) return EscalationStep.none;
  if (snoozeCount >= maxSnoozes) return EscalationStep.finalNotice;
  return EscalationStep.autoSnooze;
}
