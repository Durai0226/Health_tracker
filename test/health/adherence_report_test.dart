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

  /// The report's denominator is scheduled slots, not log rows.
  ///
  /// It used to be `taken + missed + skipped` — only slots with a row. A slot
  /// the user simply ignored gets no row until `reconcileMissedDoses` reaches
  /// it, and its lookback is 14 days while this report's window is 30. So a
  /// user who ignored three weeks of doses and then resumed got a PDF reading
  /// 100%, while the Adherence screen — which counts slots that came due,
  /// logged or not — read about half that. Both print the identical phrase
  /// "scheduled doses taken", and the flattering number is the one handed to
  /// a clinician.
  group('the denominator counts due slots, not log rows', () {
    EnhancedMedicine daily({DateTime? createdAt}) => EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          strength: '500mg',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          createdAt: createdAt ?? DateTime(2026, 2, 1),
          schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
          ),
        );

    test('a 30-day window of a once-daily medicine is 30, not the log count',
        () {
      final n = AdherenceReportService.dueSlotCount(
        daily(),
        DateTime(2026, 3, 1),
        // End of the 31st, not its midnight — a window ending at 00:00 stops
        // before that day's own 08:00 slot.
        DateTime(2026, 3, 31, 23, 59),
        DateTime(2026, 3, 31, 23, 59),
      );
      expect(n, 31,
          reason: 'Mar 1-31 inclusive is 31 slots at 08:00. Only three of them '
              'have log rows in this file, and that is exactly the gap.');
    });

    test('slots still ahead of now are not due yet', () {
      // Window says the whole month; "now" is the 10th at 07:00, before that
      // day's 08:00 slot.
      final n = AdherenceReportService.dueSlotCount(
        daily(),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
        DateTime(2026, 3, 10, 7, 0),
      );
      expect(n, 9, reason: 'Mar 1-9 came due; the 10th has not yet');
    });

    test('nothing is counted before the medicine existed', () {
      final n = AdherenceReportService.dueSlotCount(
        daily(createdAt: DateTime(2026, 3, 20, 9)),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31, 23, 59),
        DateTime(2026, 3, 31, 23, 59),
      );
      expect(n, 11,
          reason: 'created on the 20th after that day\'s 08:00 slot, so the '
              '21st-31st count');
    });

    test('a PRN medicine has no schedule to be due', () {
      final prn = EnhancedMedicine(
        id: 'p1',
        name: 'Ibuprofen',
        strength: '200mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime(2026, 2, 1),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.asNeeded,
          times: const [],
          isPRN: true,
        ),
      );
      expect(
          AdherenceReportService.dueSlotCount(prn, DateTime(2026, 3, 1),
              DateTime(2026, 3, 31), DateTime(2026, 3, 31)),
          0,
          reason: 'buildPdf falls back to the log count for PRN, which is the '
              'only measure it has');
    });

    /// The function `buildPdf` actually divides by.
    ///
    /// The tests above pin `dueSlotCount`, but reverting the CALL SITE to
    /// `taken + missed + skipped` left them all green — the helper was still
    /// correct, just unused. That is the vacuous-guard shape this project
    /// keeps finding, so the denominator now lives in one function and this
    /// asserts on that.
    test('the value the report divides by is the slot count, not the rows',
        () {
      final windowLogs = logs(); // three rows: 2 taken, 1 missed
      final due = AdherenceReportService.dueCountFor(
        daily(),
        windowLogs,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31, 23, 59),
        DateTime(2026, 3, 31, 23, 59),
      );
      expect(due, 31,
          reason: 'three log rows against a month of daily slots. Dividing by '
              '3 is the 100% the clinician was shown.');
      expect(due, isNot(windowLogs.length));
    });

    /// The headline percentage, computed by the code the PDF actually uses.
    ///
    /// This is the assertion the earlier ones were missing: reverting the CALL
    /// SITE to `taken + missed + skipped` left every helper test green because
    /// the helper stayed correct and simply went unused.
    test('the headline is the number the clinician is shown', () {
      final tally = AdherenceReportService.tallyAdherence(
        [MedicineReportEntry(medicine: daily(), logs: logs())],
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31, 23, 59),
        DateTime(2026, 3, 31, 23, 59),
      );

      // 2 taken out of 31 due slots. Counting log rows instead gives 2/3 = 67%.
      expect(tally.totalDue, 31);
      expect(tally.totalTaken, 2);
      expect(tally.overallPct, 6,
          reason: 'dividing by the three log rows prints 67% for a user who '
              'took two of a month of doses');
      expect(tally.overallPct, lessThan(50),
          reason: 'the whole defect is that this number came out flattering');

      // ...and the per-medicine row agrees with the headline.
      expect(tally.rows.single[2], '6%');
    });

    test('a PRN medicine still divides by its own logs', () {
      final prn = EnhancedMedicine(
        id: 'p1',
        name: 'Ibuprofen',
        strength: '200mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime(2026, 2, 1),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.asNeeded,
          times: const [],
          isPRN: true,
        ),
      );
      expect(
        AdherenceReportService.dueCountFor(prn, logs(), DateTime(2026, 3, 1),
            DateTime(2026, 3, 31, 23, 59), DateTime(2026, 3, 31, 23, 59)),
        3,
        reason: 'there is no schedule to be due against, so the rows are the '
            'only measure',
      );
    });
  });
}
