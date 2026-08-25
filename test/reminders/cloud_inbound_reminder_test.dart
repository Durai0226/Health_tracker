import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';

import '../support/reminder_harness.dart';

/// A reminder arriving from the cloud used to be written with **ten of its
/// seventeen columns** — `customDaysJson`, `snoozeDuration`, `sound`, `note`,
/// `imagePath` and `noteId` were all silently dropped.
///
/// The consequence was worse than lost detail. `sync_service` then scheduled it
/// with `repeatType` intact but `customDays` null, and the `custom` branch of
/// `scheduleGenericReminder` loops over that list — so a cloud-arrived custom
/// reminder armed **zero** notifications while looking perfectly normal in the
/// list.
///
/// Latent, not live: nothing writes to `users/{uid}/reminders` today
/// (`RemindersCloudService` was deleted in `0dd3c72`), so the listener never
/// receives anything. Fixed rather than deleted because whether reminders sync
/// across devices is a product decision, and a *broken* dormant path is strictly
/// worse than a correct one — whoever adds a writer would inherit the bug rather
/// than discover it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Reminder fromCloud({
    RepeatType repeat = RepeatType.custom,
    List<int>? customDays = const [1, 3, 5],
  }) =>
      Reminder(
        id: 'cloud-1',
        title: 'Physio',
        body: 'Shoulder exercises',
        scheduledTime: DateTime(2026, 6, 10, 18, 30),
        repeatType: repeat,
        customDays: customDays,
        snoozeDuration: 20,
        sound: 'chime',
        note: 'left side',
        imagePath: '/tmp/x.png',
        noteId: 'n-9',
        priority: ReminderPriority.high,
      );

  group('every column survives the trip', () {
    reminderTest('the fields that used to be dropped are persisted', (h) async {
      await CleanStorageService.saveSyncedReminderFromModel(fromCloud());
      final stored = CleanStorageService.getReminders().single;

      expect(stored.customDays, [1, 3, 5],
          reason: 'the dropped field that turned a custom repeat into zero '
              'notifications');
      expect(stored.snoozeDuration, 20);
      expect(stored.sound, 'chime');
      expect(stored.note, 'left side');
      expect(stored.imagePath, '/tmp/x.png');
      expect(stored.noteId, 'n-9');
      expect(stored.priority, ReminderPriority.high);
      expect(stored.repeatType, RepeatType.custom);
    });

    reminderTest('a custom repeat is armable — the actual failure', (h) async {
      // With customDays null, scheduleGenericReminder's `custom` branch loops
      // over an empty list and arms nothing at all.
      await CleanStorageService.saveSyncedReminderFromModel(fromCloud());
      final stored = CleanStorageService.getReminders().single;
      expect(stored.customDays, isNotNull);
      expect(stored.customDays, isNotEmpty);
    });

    reminderTest('a null customDays stays null rather than becoming []',
        (h) async {
      await CleanStorageService.saveSyncedReminderFromModel(
          fromCloud(repeat: RepeatType.daily, customDays: null));
      expect(CleanStorageService.getReminders().single.customDays, isNull);
    });
  });

  group('notification ids stay per-device', () {
    reminderTest('a cloud reminder gets a LOCAL reserved id', (h) async {
      // Carrying the other device's id would collide with whatever local
      // reminder already holds it.
      await CleanStorageService.saveSyncedReminderFromModel(fromCloud());
      final stored = CleanStorageService.getReminders().single;
      expect(stored.notificationId, isNull,
          reason: 'the inbound write must not invent one');

      final allocated =
          await CleanStorageService.saveReminderAllocatingId(stored);
      expect(allocated.notificationId, genericReminderIdBase);
    });

    reminderTest('an update from the cloud does not clobber the local id',
        (h) async {
      final local = await h.seed('cloud-1', at: h.now.add(const Duration(hours: 1)));
      expect(local.notificationId, genericReminderIdBase);

      // insertOnConflictUpdate with an absent notificationId must leave the
      // stored one alone — otherwise every cloud echo would orphan the alarm.
      await CleanStorageService.saveSyncedReminderFromModel(fromCloud());
      expect(CleanStorageService.getReminders().single.notificationId,
          genericReminderIdBase);
    });
  });
}
