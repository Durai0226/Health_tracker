import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import 'medicine_storage_service.dart';

/// One concrete dose slot on a given day: a medicine, its scheduled time, the
/// slot index, and the matching log (if the dose was taken/skipped/missed).
///
/// This is the single source of truth for "today's doses" — used by both the
/// medication dashboard's schedule timeline and the Today hub's next-dose hero,
/// so the two can never drift apart.
class ScheduledDose {
  final EnhancedMedicine medicine;
  final DateTime scheduledTime;
  final int timeIndex;
  final MedicineLog? log;

  const ScheduledDose({
    required this.medicine,
    required this.scheduledTime,
    required this.timeIndex,
    this.log,
  });

  bool get isTaken => log?.isTaken ?? false;
  bool get isSkipped => log?.isSkipped ?? false;
  bool get isMissed => log?.isMissed ?? false;

  /// A stable per-slot key ("medicineId_index").
  String get key => '${medicine.id}_$timeIndex';
}

/// Builds the ordered list of scheduled doses for [date] across all active,
/// non-archived medicines, joining each slot to its log for that day. Pure over
/// the storage service, so it's reusable and testable.
class TodayScheduleService {
  const TodayScheduleService._();

  static Future<List<ScheduledDose>> getTodaysDoses(DateTime date) async {
    final medicines = await MedicineCleanStorageService.getAllMedicines();
    final active = medicines.where((m) => m.isActive && !m.isArchived);
    final logs = await MedicineCleanStorageService.getLogsForDate(date);

    final doses = <ScheduledDose>[];
    for (final medicine in active) {
      final times = medicine.schedule.getScheduledTimesForDate(date);
      for (int i = 0; i < times.length; i++) {
        final log = logs
            .where((l) =>
                l.medicineId == medicine.id &&
                l.scheduledTime.hour == times[i].hour &&
                l.scheduledTime.minute == times[i].minute)
            .firstOrNull;
        doses.add(ScheduledDose(
          medicine: medicine,
          scheduledTime: times[i],
          timeIndex: i,
          log: log,
        ));
      }
    }

    doses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return doses;
  }

  /// The dose to surface as "up next": the earliest overdue pending dose, else
  /// the next upcoming pending dose, else null (all taken / none scheduled).
  static ScheduledDose? nextDose(List<ScheduledDose> doses, DateTime now) {
    final pending = doses
        .where((d) => !d.isTaken && !d.isSkipped)
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (pending.isEmpty) return null;
    final overdue = pending.where((d) => d.scheduledTime.isBefore(now));
    if (overdue.isNotEmpty) return overdue.first;
    final upcoming = pending.where((d) => !d.scheduledTime.isBefore(now));
    return upcoming.isNotEmpty ? upcoming.first : pending.first;
  }
}
