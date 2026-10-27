import '../../../core/services/clean_storage_service.dart';
import 'period_reminder_service.dart';

/// How private the person wants their cycle data kept.
///
/// Two switches, both OFF until switched on (nothing here changes behaviour for
/// anyone who has not asked):
///
///  * **private notifications**: cycle reminders say only "Reminder", with no
///    mention of cycles, periods or fertility, anywhere a notification can be
///    read: the lock screen, a smartwatch, an over-the-shoulder glance;
///  * **leave out of backups**: the backup file and cloud backups skip cycle
///    data altogether.
class CyclePrivacy {
  const CyclePrivacy._();

  static const privateNotificationsKey = 'cycle_private_notifications';
  static const excludeFromBackupsKey = 'cycle_exclude_from_backups';

  static bool get privateNotifications =>
      CleanStorageService.getAppPreference(privateNotificationsKey, false) ==
      true;

  static bool get excludeFromBackups =>
      CleanStorageService.getAppPreference(excludeFromBackupsKey, false) ==
      true;

  /// Re-arms the reminders straight away: the copy of one already scheduled is
  /// fixed at the moment it was armed.
  static Future<void> setPrivateNotifications(bool on) async {
    await CleanStorageService.setAppPreference(privateNotificationsKey, on);
    await PeriodReminderService.reschedule();
  }

  static Future<void> setExcludeFromBackups(bool on) =>
      CleanStorageService.setAppPreference(excludeFromBackupsKey, on);
}
