/// The visit brief as a page: what it says, and that it stays one page.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/visit_brief.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/adherence_report_service.dart';
import 'package:tablet_remainder/features/medication/services/visit_brief_pdf.dart';
import 'package:tablet_remainder/features/medication/services/visit_brief_service.dart';

import '../support/pdf_words.dart';

void main() {
  final now = DateTime(2026, 6, 20, 15, 30);
  final visit = DateTime(2026, 6, 25, 10, 30);

  EnhancedMedicine med(String name, {String? strength}) => EnhancedMedicine(
        id: name,
        name: name,
        strength: strength,
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime(2026),
        schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
      );

  MedicineAdherence adh(String name,
          {int due = 40, int taken = 36, int missed = 3, int skipped = 1, String? strength}) =>
      MedicineAdherence(
          medicine: med(name, strength: strength),
          logs: const [],
          due: due,
          taken: taken,
          missed: missed,
          skipped: skipped);

  VisitBrief brief({
    List<MedicineAdherence> medicines = const [],
    DateTime? since,
    int days = 30,
    BpSummary? bp,
    GlucoseSummary? glucose,
    WeightSummary? weight,
    List<EnhancedMedicine> started = const [],
    List<EnhancedMedicine> stopped = const [],
    List<String> discuss = const [],
    String? patient,
    String? location,
  }) {
    final due = medicines.fold<int>(0, (s, m) => s + m.due);
    return VisitBrief(
      appointment: Appointment(
        id: 'v',
        doctorName: 'Dr Anand',
        dateTime: visit,
        location: location,
      ),
      window: VisitBriefWindow(
        from: since ?? now.subtract(Duration(days: days)),
        to: now,
        sinceVisit: since,
      ),
      generatedAt: now,
      medicines: medicines,
      due: due,
      taken: medicines.fold<int>(0, (s, m) => s + m.taken),
      missed: medicines.fold<int>(0, (s, m) => s + m.missed),
      skipped: medicines.fold<int>(0, (s, m) => s + m.skipped),
      bp: bp,
      glucose: glucose,
      weight: weight,
      started: started,
      stopped: stopped,
      discuss: discuss,
      patientName: patient,
    );
  }

  Future<List<String>> words(VisitBrief b) async =>
      pdfWords(await VisitBriefPdf.build(b));

  Future<int> pages(VisitBrief b) async {
    final bytes = await VisitBriefPdf.build(b);
    final raw = String.fromCharCodes(bytes);
    return RegExp(r'/Type\s*/Page\b').allMatches(raw).length;
  }

  test('the visit, and what it covers', () async {
    final w = await words(brief(
        since: DateTime(2026, 5, 4, 14), days: 47, location: 'St Mary, clinic 3'));
    final text = w.join(' ');
    expect(text, contains('Visit brief'));
    expect(text, contains('Visit: Dr Anand, 25 Jun 2026 at 10:30 AM, St Mary, clinic 3'));
    expect(text, contains('Covers: since your last visit on 4 May 2026'));
    expect(text, contains('Made: 20 Jun 2026'));
  });

  test('with no earlier visit it says the last thirty days', () async {
    final text = (await words(brief())).join(' ');
    expect(text, contains('Covers: the last 30 days'));
    expect(text, isNot(contains('since your last visit')));
  });

  test('the patient, for someone you look after only', () async {
    expect((await words(brief(patient: 'Aarav'))).join(' '), contains('Patient: Aarav'));
    expect((await words(brief())).join(' '), isNot(contains('Patient:')));
  });

  test('the doses: the headline and a row each', () async {
    final text = (await words(brief(medicines: [
      adh('Metformin', strength: '500mg', due: 40, taken: 30, missed: 8, skipped: 2),
      adh('Aspirin'),
    ]))).join(' ');
    // 66 of 80.
    expect(text, contains('83% of scheduled doses taken: 66 of 80, 11 missed, 3 skipped.'));
    expect(text, contains('Metformin 500mg'));
    expect(text, contains('75%'));
    expect(text, contains('Aspirin'));
    expect(text, contains('90%'));
  });

  test('nothing due is said, not a percentage', () async {
    final text = (await words(brief(medicines: [adh('Metformin', due: 0, taken: 0, missed: 0, skipped: 0)])))
        .join(' ');
    expect(text, contains('No scheduled doses came due in this period.'));
    expect(text, isNot(contains('%')));
  });

  test('no medicines is said too', () async {
    expect((await words(brief())).join(' '),
        contains('No medicines were being taken in this period.'));
  });

  test('the readings, as lines', () async {
    final text = (await words(brief(
      bp: const BpSummary(
          sessions: 12,
          readings: 14,
          avgSystolic: 128,
          avgDiastolic: 82,
          minSystolic: 112,
          maxSystolic: 146,
          minDiastolic: 70,
          maxDiastolic: 94),
      glucose: const GlucoseSummary(
          readings: 21, avgMgdl: 118, minMgdl: 84, maxMgdl: 190, inRangePercent: 76),
      weight: const WeightSummary(firstKg: 71.4, lastKg: 70.2, readings: 5),
    ))).join(' ');
    expect(text, contains('Blood pressure: average 128/82 mmHg over 12 measurements'));
    expect(text, contains('systolic 112 to 146, diastolic 70 to 94'));
    expect(text, contains('Blood sugar: average 118 mg/dL over 21 readings (84 to 190), 76% in target.'));
    expect(text, contains('Weight: 71.4 to 70.2 kg (-1.2 kg).'));
  });

  test('one reading is one reading', () async {
    final text = (await words(brief(
      bp: const BpSummary(
          sessions: 1,
          readings: 2,
          avgSystolic: 128,
          avgDiastolic: 82,
          minSystolic: 128,
          maxSystolic: 128,
          minDiastolic: 82,
          maxDiastolic: 82),
      glucose: const GlucoseSummary(readings: 1, avgMgdl: 100, minMgdl: 100, maxMgdl: 100),
      weight: const WeightSummary(firstKg: 70, lastKg: 70, readings: 1),
    ))).join(' ');
    expect(text, contains('over 1 measurement '));
    expect(text, contains('over 1 reading (100 to 100).'));
    expect(text, contains('Weight: 70.0 kg (one reading).'));
  });

  test('a weight gained has a plus', () async {
    final text = (await words(
            brief(weight: const WeightSummary(firstKg: 70, lastKg: 71.5, readings: 3))))
        .join(' ');
    expect(text, contains('(+1.5 kg)'));
  });

  test('no readings, no Readings heading', () async {
    expect((await words(brief())).join(' '), isNot(contains('Readings')));
  });

  test('the changes', () async {
    final text = (await words(brief(
      started: [med('Amlodipine')],
      stopped: [med('Ibuprofen'), med('Lisinopril')],
    ))).join(' ');
    expect(text, contains('Started: Amlodipine'));
    expect(text, contains('Stopped or put away: Ibuprofen, Lisinopril'));
  });

  test('what to discuss', () async {
    final text = (await words(brief(discuss: [
      'Six-month review',
      'Ask about the dizziness',
      'Medicines to talk about: Metformin',
    ]))).join(' ');
    expect(text, contains('To discuss'));
    expect(text, contains('Six-month review'));
    expect(text, contains('Ask about the dizziness'));
    expect(text, contains('Medicines to talk about: Metformin'));
  });

  test('without any, no To discuss heading', () async {
    expect((await words(brief())).join(' '), isNot(contains('To discuss')));
  });

  test('it says what it is not', () async {
    expect((await words(brief())).join(' '), contains('It is not medical advice.'));
  });

  group('one page', () {
    test('an ordinary brief is one page', () async {
      expect(
          await pages(brief(
            medicines: [adh('Metformin'), adh('Aspirin')],
            discuss: ['Review'],
          )),
          1);
    });

    test('and so is the longest it can get', () async {
      final many = [
        for (var i = 0; i < 30; i++)
          adh('Medicine number $i with a rather long name', strength: '500mg'),
      ];
      final b = brief(
        medicines: many,
        since: DateTime(2026, 5, 4),
        days: 47,
        patient: 'Aarav Venkataraghavan',
        location: 'St Mary\'s Hospital, East Wing, clinic 3',
        bp: const BpSummary(
            sessions: 12,
            readings: 14,
            avgSystolic: 128,
            avgDiastolic: 82,
            minSystolic: 112,
            maxSystolic: 146,
            minDiastolic: 70,
            maxDiastolic: 94),
        glucose: const GlucoseSummary(
            readings: 21, avgMgdl: 118, minMgdl: 84, maxMgdl: 190, inRangePercent: 76),
        weight: const WeightSummary(firstKg: 71.4, lastKg: 70.2, readings: 5),
        started: [for (var i = 0; i < 6; i++) med('Started medicine $i')],
        stopped: [for (var i = 0; i < 6; i++) med('Stopped medicine $i')],
        discuss: [for (var i = 0; i < 12; i++) 'A point to raise, number $i, said at some length'],
      );
      expect(await pages(b), 1);
    });

    test('ten medicines are shown, and the rest counted', () async {
      final many = [for (var i = 0; i < 14; i++) adh('Med$i')];
      final text = (await words(brief(medicines: many))).join(' ');
      expect(text, contains('Med9'));
      expect(text, isNot(contains('Med10')));
      expect(text, contains('and 4 more medicines'));
    });

    test('six points to discuss are shown, and the rest counted', () async {
      final text = (await words(brief(
        discuss: [for (var i = 0; i < 9; i++) 'Point$i'],
      ))).join(' ');
      expect(text, contains('Point5'));
      expect(text, isNot(contains('Point6')));
      expect(text, contains('and 3 more'));
    });
  });
}
