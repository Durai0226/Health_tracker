import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart' as db;
import '../../reminders/models/reminder_category_model.dart' as model;

/// The reminder categories of the app backup.
///
/// A reminder names its category by id. The reminders were in the backup and the
/// categories they point at were not, so a restore on a new phone brought back a
/// reminder filed under "Gym" and a category list that had never heard of it.
/// The three built-in ones come back with the rest.
///
/// Export, import and clear live in one file for the reason given on
/// [HealthBackupSerializer]: a table this clears but cannot put back is data a
/// restore destroys.
class RemindersBackupSerializer {
  RemindersBackupSerializer._();

  static const String categoriesKey = 'reminderCategories';

  static db.AppDatabase get _db => db.AppDatabase.instance;

  static Future<Map<String, dynamic>> exportJson() async {
    final d = _db;
    final rows = await d.select(d.reminderCategories).get();
    return {categoriesKey: [for (final r in rows) r.toJson()]};
  }

  /// Upsert each category by id. A section that is absent is left alone, and a
  /// malformed row is skipped rather than failing the restore.
  static Future<void> importJson(Map<String, dynamic> data) async {
    final d = _db;
    for (final raw in (data[categoriesKey] as List? ?? const [])) {
      try {
        await d.into(d.reminderCategories).insertOnConflictUpdate(
            db.ReminderCategory.fromJson(Map<String, dynamic>.from(raw as Map))
                .toCompanion(false));
      } catch (e) {
        debugPrint('Import reminder category failed: $e');
      }
    }
  }

  /// Wipe the categories only when the file being restored carries them: an
  /// older backup has none, and clearing them would leave a restore with
  /// nothing to put back. Null means "a current export".
  ///
  /// The three built-in categories are never wiped. They are only seeded on a
  /// first launch, into an empty table, so one removed here with a custom
  /// category left beside it would not come back.
  static Future<void> clearRestorableRows({Map<String, dynamic>? forBackup}) async {
    if (forBackup != null && !forBackup.containsKey(categoriesKey)) return;
    final d = _db;
    await (d.delete(d.reminderCategories)
          ..where((t) => t.id.isNotIn(model.ReminderCategory.starterIds)))
        .go();
  }
}
