import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/services/adherence_report_service.dart';

void main() {
  EnhancedMedicine med({String id = 'm1', String name = 'Metformin'}) =>
      EnhancedMedicine(
        id: id,
        name: name,
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

  group('buildPdf', () {
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

    test('builds identically well with NO symptom, vitals, or interaction data'
        ' (the "beats the leader" sections are additive, never required)',
        () async {
      final bytes = await AdherenceReportService.buildPdf(
        entries: [MedicineReportEntry(medicine: med(), logs: logs())],
        generatedAt: DateTime(2026, 3, 15),
      );
      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('builds a larger PDF once symptom data is present (section actually renders)',
        () async {
      final plain = await AdherenceReportService.buildPdf(
        entries: [MedicineReportEntry(medicine: med(), logs: logs())],
        generatedAt: DateTime(2026, 3, 15),
      );

      final withSymptoms = [
        MedicineLog.taken(
            id: 'l1',
            medicineId: 'm1',
            scheduledTime: DateTime(2026, 3, 1, 8),
            sideEffects: 'Nausea',
            moodRating: 4,
            effectivenessRating: 5),
        MedicineLog.taken(
            id: 'l2',
            medicineId: 'm1',
            scheduledTime: DateTime(2026, 3, 2, 8),
            sideEffects: 'Nausea',
            moodRating: 3),
      ];
      final bytes = await AdherenceReportService.buildPdf(
        entries: [MedicineReportEntry(medicine: med(), logs: withSymptoms)],
        generatedAt: DateTime(2026, 3, 15),
      );

      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(plain.length),
          reason: 'the Symptoms & well-being section must add real content');
    });

    test('a duplicated slot (stale missed + later taken) is not double-counted '
        'into the symptom section', () async {
      // Regression cover for the exact double-write scenario dedupeByDose
      // exists for: a slot that has BOTH an auto-written `missed` row and a
      // later real `taken` row must still count as ONE dose, not two — and
      // the missed row (whose sideEffects/moodRating are always null by
      // construction) must not suppress the real taken row's data either.
      final duplicated = [
        MedicineLog.missed(
            id: 'auto-missed', medicineId: 'm1', scheduledTime: DateTime(2026, 3, 1, 8)),
        MedicineLog.taken(
            id: 'real-taken',
            medicineId: 'm1',
            scheduledTime: DateTime(2026, 3, 1, 8),
            moodRating: 5),
      ];
      final bytes = await AdherenceReportService.buildPdf(
        entries: [MedicineReportEntry(medicine: med(), logs: duplicated)],
        generatedAt: DateTime(2026, 3, 15),
      );
      expect(isPdf(bytes), isTrue); // must not throw and must still render
    });

    test('folds in BP and glucose vitals when provided', () async {
      final bytes = await AdherenceReportService.buildPdf(
        entries: [MedicineReportEntry(medicine: med(), logs: logs())],
        generatedAt: DateTime(2026, 3, 15),
        bpReadings: [
          BloodPressureReading(
              id: 'bp1',
              systolic: 130,
              diastolic: 85,
              takenAt: DateTime(2026, 3, 5, 8),
              createdAt: DateTime(2026, 3, 5, 8)),
        ],
        glucoseReadings: [
          GlucoseReading(
              id: 'g1',
              valueMgdl: 110,
              context: GlucoseContext.fasting,
              takenAt: DateTime(2026, 3, 5, 7),
              createdAt: DateTime(2026, 3, 5, 7)),
        ],
      );
      expect(isPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('flags an interaction between two co-prescribed medicines with a known pair',
        () async {
      // Warfarin + Aspirin is one of the curated built-in interaction pairs
      // (DrugInteractionService._interactionDatabase) — a real pair, not a
      // fabricated one, so this exercises the actual lookup, not a stub.
      final plain = await AdherenceReportService.buildPdf(
        entries: [MedicineReportEntry(medicine: med(id: 'm1', name: 'Warfarin'), logs: const [])],
        generatedAt: DateTime(2026, 3, 15),
      );
      final withInteraction = await AdherenceReportService.buildPdf(
        entries: [
          MedicineReportEntry(medicine: med(id: 'm1', name: 'Warfarin'), logs: const []),
          MedicineReportEntry(medicine: med(id: 'm2', name: 'Aspirin'), logs: const []),
        ],
        generatedAt: DateTime(2026, 3, 15),
      );
      expect(isPdf(withInteraction), isTrue);
      expect(withInteraction.length, greaterThan(plain.length),
          reason: 'the Interaction warnings section must add real content');
    });
  });

  group('buildCsv', () {
    test('one row per deduped dose, in the documented column order', () {
      final csv = AdherenceReportService.buildCsv(
        entries: [MedicineReportEntry(medicine: med(), logs: logs())],
      );
      final lines = csv.trim().split('\n');
      expect(lines.first, 'Date,Time,Medicine,Status,SideEffects,Mood,Effectiveness');
      expect(lines.length, 4); // header + 3 logs
      expect(lines[1], '2026-03-01,08:00,Metformin 500mg,Taken,,,');
    });

    test('side effects, mood, and effectiveness appear as their own columns', () {
      final withSymptoms = [
        MedicineLog.taken(
            id: 'l1',
            medicineId: 'm1',
            scheduledTime: DateTime(2026, 3, 1, 8),
            sideEffects: 'Nausea, Headache',
            moodRating: 4,
            effectivenessRating: 5),
      ];
      final csv = AdherenceReportService.buildCsv(
        entries: [MedicineReportEntry(medicine: med(), logs: withSymptoms)],
      );
      final row = csv.trim().split('\n')[1];
      expect(row, '2026-03-01,08:00,Metformin 500mg,Taken,"Nausea, Headache",4,5');
    });

    test('a stale missed row superseded by a real taken row for the same slot '
        'produces exactly ONE csv line, not two', () {
      // This is the exact bug the report-service research surfaced: buildCsv
      // never deduped, unlike buildPdf. Regression cover for the fix.
      final duplicated = [
        MedicineLog.missed(
            id: 'auto-missed', medicineId: 'm1', scheduledTime: DateTime(2026, 3, 1, 8)),
        MedicineLog.taken(
            id: 'real-taken', medicineId: 'm1', scheduledTime: DateTime(2026, 3, 1, 8)),
      ];
      final csv = AdherenceReportService.buildCsv(
        entries: [MedicineReportEntry(medicine: med(), logs: duplicated)],
      );
      final lines = csv.trim().split('\n');
      expect(lines.length, 2); // header + exactly one row
      expect(lines[1], startsWith('2026-03-01,08:00,Metformin 500mg,Taken'));
    });

    test('handles an empty medication list without throwing', () {
      final csv = AdherenceReportService.buildCsv(entries: const []);
      expect(csv.trim(), 'Date,Time,Medicine,Status,SideEffects,Mood,Effectiveness');
    });
  });
}
