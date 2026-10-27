import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/as_needed_status.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import 'medicine_storage_service.dart';

/// One as-needed medicine and where it stands against its limits.
class AsNeededEntry {
  const AsNeededEntry({required this.medicine, required this.status});

  final EnhancedMedicine medicine;
  final AsNeededStatus status;
}

/// The as-needed medicines on a person's list: when each was last taken, how
/// many doses in the last 24 hours, and when the next is OK — from the limits
/// set on the medicine, and nothing else.
class AsNeededService {
  const AsNeededService._();

  /// The as-needed ones among [medicines]: active, not archived, taken only
  /// when needed.
  static List<EnhancedMedicine> asNeededOf(Iterable<EnhancedMedicine> medicines) => [
        for (final m in medicines)
          if (m.isActive && !m.isArchived && m.schedule.isPRN) m,
      ];

  /// Every active as-needed medicine of the active profile, with its status.
  ///
  /// [medicines] is the list the caller has already read: Today loads them once
  /// for everything on it, and a card that read them again would put one more
  /// read of the table on every Home load. Without it they are read here.
  static Future<List<AsNeededEntry>> entries({
    DateTime? now,
    List<EnhancedMedicine>? medicines,
  }) async {
    final n = now ?? clock.now();
    final out = <AsNeededEntry>[];
    try {
      final meds =
          asNeededOf(medicines ?? await MedicineCleanStorageService.getAllMedicines());
      for (final m in meds) {
        final logs = await MedicineCleanStorageService.getLogsForMedicine(m.id);
        out.add(AsNeededEntry(
          medicine: m,
          status: AsNeededStatus.of(
            takenAt: [
              for (final l in logs)
                if (l.countsAsTaken) l.actionTime ?? l.scheduledTime,
            ],
            now: n,
            maxPer24h: m.schedule.maxDailyDoses,
            minHours: m.schedule.minHoursBetweenDoses,
          ),
        ));
      }
    } catch (e) {
      debugPrint('⚠️ As-needed statuses failed: $e');
    }
    return out;
  }

  /// Log one dose of [medicine] taken now, exactly as the Take sheet does for an
  /// as-needed medicine (stock decremented; the moment is the slot).
  static Future<MedicineLog> takeNow(EnhancedMedicine medicine, {DateTime? now}) {
    final n = now ?? clock.now();
    return MedicineCleanStorageService.markMedicineTaken(
      medicineId: medicine.id,
      scheduledTime: n,
      takenAt: n,
      dosageTaken: medicine.dosageAmount,
    );
  }
}
