import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import 'photo_store.dart';

/// Deletes the kept photos that no medicine, diary entry or family profile refers to.
///
/// A photo is orphaned by deleting what it was on, by a restore that replaced the rows,
/// and by anything that ends a form between picking and saving; each of those could
/// clean up as it goes, and this is the one pass that cannot be missed. It runs once
/// at start-up.
///
/// It deletes ONLY after both reads succeeded. A failed or half-open database read as
/// "nothing refers to anything" would be taken for permission to delete every photo the
/// person has.
class PhotoSweep {
  PhotoSweep._();

  /// Returns how many photos were deleted; 0 when it could not tell what is in use.
  static Future<int> run({AppDatabase? database}) async {
    try {
      final db = database ?? AppDatabase.instance;
      final referenced = <String>{};

      // Medicines that are not deleted. A soft-deleted one (a tombstone, kept for
      // cloud sync) no longer shows its photo, so does not hold it.
      final medicines = await (db.select(db.enhancedMedicines)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      for (final m in medicines) {
        final path = m.imagePath;
        if (path != null && path.isNotEmpty) referenced.add(path);
      }

      final entries = await db.select(db.diaryEntries).get();
      for (final e in entries) {
        final path = e.photoPath;
        if (path != null && path.isNotEmpty) referenced.add(path);
      }

      // Family profiles, every one: a profile that is not shown is still kept, and
      // its photo with it.
      final people = await db.select(db.dependentProfiles).get();
      for (final d in people) {
        final path = d.photoPath;
        if (path != null && path.isNotEmpty) referenced.add(path);
      }

      final n = await PhotoStore.sweep(referenced);
      if (n > 0) debugPrint('✓ Swept $n photos nothing refers to');
      return n;
    } catch (e) {
      debugPrint('⚠️ Photo sweep skipped: $e');
      return 0;
    }
  }
}
