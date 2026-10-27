import 'package:clock/clock.dart';

import '../../../core/health/vitals_analyzer.dart';
import '../../../core/services/notification_service.dart';
import '../models/glucose_reading.dart';

/// The 15-minute recheck after a low reading — the "15-15 rule" the severe-low
/// card already quotes: treat it, wait fifteen minutes, check again.
///
/// A low reading arms ONE reminder for fifteen minutes later; the next reading
/// of any kind withdraws it, since it has been answered. It says only that it is
/// time to check again: no value, no advice beyond what the app already says.
class GlucoseRecheck {
  const GlucoseRecheck._();

  /// Its own id, in a block no other family uses; one at a time, so a second low
  /// replaces the first rather than stacking.
  static const int notificationId = 985001;

  static const Duration after = Duration(minutes: 15);

  /// When a recheck is due after [reading]: fifteen minutes on for a low or a
  /// severe low, null for anything else.
  static DateTime? dueAfter(GlucoseReading reading) {
    final c = reading.glucoseClass;
    final low = c == GlucoseClass.low || c == GlucoseClass.severeLow;
    return low ? reading.takenAt.add(after) : null;
  }

  /// [reading] was just saved as a NEW entry. Takes down the recheck a previous
  /// low armed, and arms one for this reading if it is low and the time has not
  /// already passed (a low logged afterwards, from a diary, has nothing to wait
  /// for). Returns when the recheck is due, or null when none was armed.
  static Future<DateTime?> afterSave(GlucoseReading reading) async {
    final ns = NotificationService();
    await ns.cancelNotification(notificationId);
    final due = dueAfter(reading);
    if (due == null || !due.isAfter(clock.now())) return null;
    final armed = await ns.scheduleNotification(
      id: notificationId,
      title: 'Recheck your blood sugar',
      body: 'It has been 15 minutes since your low reading. Time to check '
          'again.',
      scheduledDate: due,
    );
    return armed ? due : null;
  }

  /// Take the pending recheck down.
  static Future<void> cancel() =>
      NotificationService().cancelNotification(notificationId);
}
