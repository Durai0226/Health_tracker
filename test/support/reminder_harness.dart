import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_alarm.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';

/// The reminder equivalent of `focus_harness.dart`: an in-memory database, a
/// pinned wall clock, a recording notification seam, and the process-wide
/// singletons reset between tests.
///
/// Reminders had none of this, which is why `water_reminder_pacing_test`
/// documents its own subject as untestable: *"The pruning itself is private to
/// ReminderRescheduleService (it needs NotificationService, which has no
/// headless implementation)."* [ReminderAlarm] is that missing implementation.
///
/// Two singletons bite if not reset. `CleanStorageService` caches the
/// `AppDatabase` in a static, so without a reset it keeps the previous test's
/// **closed** connection and every write fails with "Can't re-open a database
/// after closing it". `ReminderService` holds a stream subscription to it.
class ReminderHarness {
  ReminderHarness._(this.database, this.alarm, this.now);

  /// Named `database`, not `db` — that would shadow the import prefix.
  final db.AppDatabase database;
  final RecordingReminderAlarm alarm;

  /// The pinned wall clock. Production code reads `clock.now()`, so anything
  /// time-of-day dependent — a past-due one-off being skipped, the roll-forward
  /// to the next occurrence, the missed sweep's grace window — is deterministic
  /// instead of depending on when the suite happens to run.
  final DateTime now;

  Future<void> tearDown() async {
    await ReminderService.instance.resetForTesting();
    CleanStorageService.resetForTesting();
    await database.close();
  }

  /// Persist a reminder and return it as stored (with its allocated id).
  Future<Reminder> seed(
    String id, {
    String title = 'Stretch',
    DateTime? at,
    RepeatType repeat = RepeatType.none,
    List<int>? customDays,
    bool isCompleted = false,
    int? notificationId,
  }) =>
      CleanStorageService.saveReminderAllocatingId(Reminder(
        id: id,
        title: title,
        body: '',
        scheduledTime: at ?? now.add(const Duration(hours: 1)),
        repeatType: repeat,
        customDays: customDays,
        isCompleted: isCompleted,
        notificationId: notificationId,
      ));
}

/// Build a harness. Defaults to **13:00 today**, for the reason
/// `focus_harness` records: a suite pinned to midnight fails on anything that
/// distinguishes "earlier today" from "tomorrow".
Future<ReminderHarness> reminderSetUp({DateTime? at}) async {
  final real = DateTime.now();
  final pinned = at ?? DateTime(real.year, real.month, real.day, 13, 0);
  // Reminder code reaches SharedPreferences on several paths — the alarm-isolate
  // settings mirror, the snooze counter, and the `reminderResolvedKey` flag a
  // follow-up checks. Without a mock those throw MissingPluginException from
  // inside a `catch` that swallows it, so the write silently does nothing and
  // the test fails somewhere unrelated.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = db.AppDatabase.forTesting(NativeDatabase.memory());
  db.AppDatabase.setInstanceForTesting(database);
  CleanStorageService.resetForTesting();
  await ReminderService.instance.resetForTesting();
  return ReminderHarness._(database, RecordingReminderAlarm(), pinned);
}

/// `test` inside a pinned clock zone, with the harness set up and torn down.
///
/// Use this instead of bare `test` for anything reminder-related, so a test that
/// passes at 14:00 also passes at 00:01.
void reminderTest(
  String description,
  Future<void> Function(ReminderHarness h) body, {
  DateTime? at,
}) {
  test(description, () async {
    final real = DateTime.now();
    final pinned = at ?? DateTime(real.year, real.month, real.day, 13, 0);
    await withClock(Clock.fixed(pinned), () async {
      final h = await reminderSetUp(at: pinned);
      try {
        await body(h);
      } finally {
        await h.tearDown();
      }
    });
  });
}
