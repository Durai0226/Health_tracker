import '../../../core/health/nudge_scheduler.dart';
import '../../../core/utils/quiet_hours.dart';
import '../models/reminder_escalation.dart';
import '../models/reminder_model.dart';

/// One batched summary instead of N separate low-urgency notifications.
///
/// The notification-fatigue guidance is consistent: keep high-urgency real-time,
/// move high-volume and low-urgency into a digest, and let the user pick the
/// hour. `NudgeScheduler`'s own docstring names the number — *2-5
/// notifications/week is the opt-out cliff*. Past it people do not tune the
/// settings, they turn notifications off wholesale, and the dose reminders go
/// with them.
///
/// Pure. Deciding *whether* and *what* to digest is ordinary logic and belongs
/// where it can be asserted; sending is the caller's job.
class ReminderDigest {
  const ReminderDigest._();

  /// The notification channel a digest posts to.
  ///
  /// Its own channel so a user can mute the daily summary without touching
  /// anything that matters — which is the entire argument for this app having
  /// separate channels rather than one.
  static const String channelId = 'reminders_digest';
  static const String channelName = 'Daily Summary';

  /// Only the quiet tiers are ever batched.
  ///
  /// Anything the user marked insistent or critical wants to interrupt, and
  /// folding it into a once-a-day summary would silently undo the choice they
  /// made on the form.
  static bool isDigestible(ReminderEscalation e) =>
      e == ReminderEscalation.gentle || e == ReminderEscalation.standard;

  /// Whether to post a digest now.
  ///
  /// [recentDigests] are the timestamps of previous ones, so the same frequency
  /// cap that governs in-app nudges governs this too — a digest that itself
  /// becomes daily noise has solved nothing.
  ///
  /// Quiet hours DO apply here, unlike to a user-picked reminder time. The
  /// distinction is the one written into `core/utils/quiet_hours.dart`: a digest
  /// hour is app-generated, so suppressing it respects the user; a dose time is
  /// user-picked, and overriding that "could suppress a clinically-timed
  /// reminder".
  static bool shouldSend({
    required List<Reminder> pending,
    required DateTime now,
    required List<DateTime> recentDigests,
    int wakeHour = 7,
    int wakeMinute = 0,
    int bedHour = 23,
    int bedMinute = 0,
    int minItems = 2,
  }) {
    final items = digestible(pending);
    // One outstanding reminder is not a summary, it is a notification — and the
    // reminder itself already fired.
    if (items.length < minItems) return false;
    if (!QuietHours.isAllowedMinute(
      now.hour * 60 + now.minute,
      respectQuietHours: true,
      wakeHour: wakeHour,
      wakeMinute: wakeMinute,
      bedHour: bedHour,
      bedMinute: bedMinute,
    )) {
      return false;
    }
    return NudgeScheduler.shouldShow(recentShows: recentDigests, now: now);
  }

  /// The reminders a digest would cover: quiet tiers, not paused, still unmet.
  static List<Reminder> digestible(List<Reminder> pending) => pending
      .where((r) => !r.isPaused && !r.isCompleted && isDigestible(r.escalation))
      .toList();

  /// The digest body.
  ///
  /// Names up to [maxNamed] reminders and counts the rest. A body that lists
  /// fifteen titles is a wall of text nobody reads, and Android truncates it
  /// anyway.
  static String body(List<Reminder> pending, {int maxNamed = 3}) {
    final items = digestible(pending);
    if (items.isEmpty) return '';
    final names = items.take(maxNamed).map((r) => r.title).toList();
    final extra = items.length - names.length;
    if (extra <= 0) return names.join(' · ');
    return '${names.join(' · ')} and $extra more';
  }

  static String title(List<Reminder> pending) {
    final n = digestible(pending).length;
    return '$n reminder${n == 1 ? '' : 's'} still waiting';
  }
}
