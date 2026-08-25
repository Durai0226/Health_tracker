import 'dart:io';

import 'package:flutter/foundation.dart';

import 'background_alarm_service.dart' show ReminderKind;

/// How many pending notifications/alarms the OS will actually keep, and who gets
/// the slots when demand exceeds that.
///
/// Nothing enforced this before. The consequences are not theoretical:
///
/// * **iOS keeps only the soonest-firing 64 pending requests and silently
///   discards the rest.** The medication fallback path schedules up to 24
///   requests per medicine, so a user with three medicines already overflows —
///   and the requests dropped are the *furthest out*, which is invisible until a
///   dose simply never arrives.
/// * **Samsung's AlarmManager throws past roughly 500 alarms per app.** Window
///   nudges alone are `3 × 24 × N` registrations, on top of up to 100 water
///   reminders and the medicine slot block.
///
/// `getPendingNotificationCount()` existed the whole time and was only ever read
/// into a debug log.
///
/// The allocation policy is deliberately pure and separate from the querying, so
/// it can be tested without a platform channel.
class ReminderBudget {
  const ReminderBudget._();

  /// iOS keeps the soonest-firing 64 and discards the rest. A hard system limit
  /// with no way around it — a repeating request counts as ONE, which is exactly
  /// why repeating requests are preferred over materialising N instances.
  static const int iosPendingRequestCap = 64;

  /// Android is looser, but Samsung throws past ~500 alarms per app, and the
  /// system batches aggressively well before that.
  static const int androidAlarmCap = 500;

  /// Slots deliberately left unallocated.
  ///
  /// A dose scheduled *after* the budget was computed must still fit: reminders
  /// are armed by several independent services at different moments (app start,
  /// a settings save, a medicine edit), so filling the ceiling exactly would mean
  /// whichever ran last lost.
  static const int reserve = 8;

  /// The ceiling for the current platform.
  static int ceilingFor({bool? isIOS}) =>
      (isIOS ?? Platform.isIOS) ? iosPendingRequestCap : androidAlarmCap;

  /// Usable slots once the safety reserve is held back.
  static int usable(int ceiling) => (ceiling - reserve).clamp(0, ceiling);

  /// Who gets the slots when demand exceeds what the OS will keep.
  ///
  /// Strictly by kind: a dose is never pruned, a user-set alarm is pruned only
  /// after every nudge has been, and nudges go first. Returning a map rather than
  /// a single number so the caller can see what each family actually got — a
  /// silently truncated fan-out reads as "scheduled everything" when it did not.
  ///
  /// A dose demand that alone exceeds the ceiling is granted in full and reported
  /// via [overCommitted]. Refusing to arm a dose is never the better option; the
  /// honest failure is to arm it and say the platform may drop some.
  static Map<ReminderKind, int> allocate({
    required int ceiling,
    required Map<ReminderKind, int> demand,
  }) {
    var remaining = usable(ceiling);
    final granted = <ReminderKind, int>{};
    // Highest priority first.
    for (final kind in const [
      ReminderKind.dose,
      ReminderKind.alarm,
      ReminderKind.gentle,
    ]) {
      final want = demand[kind] ?? 0;
      if (kind == ReminderKind.dose) {
        granted[kind] = want; // never pruned
        remaining -= want;
        continue;
      }
      final give = want.clamp(0, remaining < 0 ? 0 : remaining);
      granted[kind] = give;
      remaining -= give;
    }
    return granted;
  }

  /// Whether [demand] cannot fit even after pruning everything prunable.
  static bool overCommitted({
    required int ceiling,
    required Map<ReminderKind, int> demand,
  }) =>
      (demand[ReminderKind.dose] ?? 0) > usable(ceiling);

  /// Slots left for [kind] given what is already pending.
  ///
  /// Used by the fan-outs that are unbounded in principle — water reminder times
  /// and the per-medicine iOS fallback — so they truncate against a real number
  /// instead of a hardcoded one.
  static int headroomFor(
    ReminderKind kind, {
    required int pending,
    int? ceiling,
    bool? isIOS,
  }) {
    final cap = ceiling ?? ceilingFor(isIOS: isIOS);
    final free = usable(cap) - pending;
    if (free <= 0) return 0;
    return free;
  }

  /// Say out loud what was dropped. A truncated fan-out that logs nothing is
  /// indistinguishable from one that scheduled everything.
  static void reportTruncation({
    required String family,
    required int wanted,
    required int granted,
  }) {
    if (granted >= wanted) return;
    debugPrint(
        '⚠️ Reminder budget: $family wanted $wanted slots, got $granted — '
        '${wanted - granted} not armed (OS pending-notification ceiling)');
  }
}
