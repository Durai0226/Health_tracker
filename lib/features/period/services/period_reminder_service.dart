import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/cycle_prediction.dart';
import '../models/period_reminder_config.dart';
import '../models/period_settings.dart';
import 'period_service.dart';

// Stable notification ids in the period range, so a reschedule cleanly cancels
// the previous arming before scheduling the (shifted) next one.
const int _idPeriodSoon = 990001;
const int _idPms = 990002;
const int _idLog = 990003;
const int _idFertile = 990004;
const List<int> _periodReminderIds = [_idPeriodSoon, _idPms, _idLog, _idFertile];

/// A single reminder the planner decided to arm: a stable [id], the local
/// [date] it should fire, and its discreet copy.
class PlannedReminder {
  final int id;
  final DateTime date;
  final String title;
  final String body;
  const PlannedReminder({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
  });
}

/// PURE: turns a [CyclePrediction] + [PeriodReminderConfig] into the concrete
/// reminders to arm. No I/O, no clock of its own ([now] is passed in) — so it
/// is fully unit-testable. Copy is discreet on purpose.
class PeriodReminderPlanner {
  const PeriodReminderPlanner._();

  static List<PlannedReminder> plan({
    required CyclePrediction prediction,
    required TrackingMode mode,
    required PeriodReminderConfig config,
    required DateTime now,
  }) {
    final out = <PlannedReminder>[];
    // Never nudge about cycles during pregnancy.
    if (mode == TrackingMode.pregnancy) return out;
    final start = prediction.predictedStart;
    // No confident prediction yet (onboarding / no logged cycle).
    if (start == null) return out;

    DateTime at(DateTime day, {int minusDays = 0}) {
      final d = day.subtract(Duration(days: minusDays));
      return DateTime(d.year, d.month, d.day, config.reminderHour, config.reminderMinute);
    }

    void add(bool enabled, int id, DateTime when, String title, String body) {
      if (enabled && when.isAfter(now)) {
        out.add(PlannedReminder(id: id, date: when, title: title, body: body));
      }
    }

    add(
      config.periodSoonEnabled,
      _idPeriodSoon,
      at(start, minusDays: config.daysBefore),
      'Cycle check-in',
      'Your next cycle may begin in about ${config.daysBefore} day${config.daysBefore == 1 ? '' : 's'}. A good time to prepare.',
    );
    add(
      config.pmsEnabled,
      _idPms,
      at(start, minusDays: config.pmsDaysBefore),
      'A gentle heads-up',
      'Your PMS window may be starting soon — be kind to yourself.',
    );
    add(
      config.logReminderEnabled,
      _idLog,
      at(start),
      'Anything to note today?',
      'Today is around your predicted start. Logging keeps your predictions accurate.',
    );

    // Fertile window is only meaningful (and only offered) in TTC mode.
    if (mode == TrackingMode.ttc && prediction.fertileStart != null) {
      add(
        config.fertileEnabled,
        _idFertile,
        at(prediction.fertileStart!, minusDays: 1),
        'Fertile window',
        'Your estimated fertile window starts tomorrow. This is an estimate, not medical advice.',
      );
    }

    return out;
  }
}

/// Owns the period-reminder config (prefs) and (re)arms the OS notifications.
/// Reminders are one-time (predicted dates shift every cycle), so this is
/// re-run on app start and after any data/config change to stay fresh.
class PeriodReminderService {
  PeriodReminderService._();

  static const String _key = 'periodReminderConfig';

  static PeriodReminderConfig getConfig() {
    final raw = CleanStorageService.getAppPreference(_key);
    if (raw is Map) {
      return PeriodReminderConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return PeriodReminderConfig.defaults;
  }

  /// Persists [config] and immediately re-arms notifications.
  static Future<void> saveConfig(PeriodReminderConfig config) async {
    await CleanStorageService.setAppPreference(_key, config.toJson());
    await reschedule();
  }

  /// Cancels the previous period reminders and arms the ones the planner
  /// selects from the current prediction + config. Best-effort (never throws
  /// out — reminders must never break logging or startup).
  static Future<void> reschedule() async {
    try {
      final ns = NotificationService();
      for (final id in _periodReminderIds) {
        await ns.cancelNotification(id);
      }
      final config = getConfig();
      if (!config.anyEnabled) return;

      final planned = PeriodReminderPlanner.plan(
        prediction: PeriodService.getPrediction(),
        mode: PeriodService.getSettings().trackingMode,
        config: config,
        now: DateTime.now(),
      );
      for (final r in planned) {
        await ns.scheduleNotification(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: r.date,
        );
      }
    } catch (_) {
      // Swallow — a reminder failure must not surface to the user.
    }
  }
}
