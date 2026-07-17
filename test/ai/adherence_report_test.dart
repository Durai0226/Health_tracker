import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/services/adherence_report_service.dart';

void main() {
  EnhancedMedicine med() => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );

  List<MedicineLog> logs() => [
        MedicineLog(id: 'l1', medicineId: 'm1', scheduledTime: DateTime(2026, 3, 1, 8), status: MedicineStatus.taken),
        MedicineLog(id: 'l2', medicineId: 'm1', scheduledTime: DateTime(2026, 3, 2, 8), status: MedicineStatus.taken),
        MedicineLog(id: 'l3', medicineId: 'm1', scheduledTime: DateTime(2026, 3, 3, 8), status: MedicineStatus.missed),
      ];

  bool isPdf(List<int> b) =>
      b.length > 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46; // %PDF

  test('builds a valid, non-empty PDF for a real entry', () async {
    final bytes = await AdherenceReportService.buildPdf(
      entries: [MedicineReportEntry(medicine: med(), logs: logs())],
      patientName: 'Test Patient',
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 31),
      generatedAt: DateTime(2026, 3, 15),
    );
    expect(bytes, isNotEmpty);
    expect(isPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(1000));
  });

  test('handles an empty medication list without throwing', () async {
    final bytes = await AdherenceReportService.buildPdf(
      entries: const [],
      generatedAt: DateTime(2026, 3, 15),
    );
    expect(isPdf(bytes), isTrue);
  });
}
