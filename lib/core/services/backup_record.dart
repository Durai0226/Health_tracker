import 'package:clock/clock.dart';

import 'clean_storage_service.dart';

/// When the user last made a backup, by either route (the shareable zip or the
/// cloud copy).
///
/// Nothing recorded this before, so the app could not tell "you have never
/// backed up" from "you backed up yesterday". Stored as one timestamp: the
/// question is only ever "recently or not".
class BackupRecord {
  const BackupRecord._();

  static const _key = 'last_backup_at';

  /// "Recent" — long enough that a monthly backup counts, short enough that a
  /// backup from last year does not reassure anyone.
  static const Duration recentFor = Duration(days: 30);

  static DateTime? lastAt() {
    final v = CleanStorageService.getAppPreference(_key, '');
    return v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
  }

  static Future<void> markDone({DateTime? now}) =>
      CleanStorageService.setAppPreference(
          _key, (now ?? clock.now()).toIso8601String());

  static bool isRecent({DateTime? now}) {
    final last = lastAt();
    if (last == null) return false;
    return (now ?? clock.now()).difference(last) < recentFor;
  }
}
