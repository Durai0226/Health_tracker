import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/vitals_analyzer.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_report_service.dart';

void main() {
  bool isPdf(List<int> b) =>
      b.length > 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46;

  test('BP PDF builds valid, non-empty bytes', () async {
    final bytes = await VitalsReportService.buildBpPdf(
      readings: [
        BloodPressureReading(
            id: '1',
            systolic: 150,
            diastolic: 95,
            pulse: 72,
            takenAt: DateTime(2026, 3, 2, 8),
            createdAt: DateTime(2026, 3, 2, 8)),
        BloodPressureReading(
            id: '2',
            systolic: 118,
            diastolic: 76,
            takenAt: DateTime(2026, 3, 1, 20),
            createdAt: DateTime(2026, 3, 1, 20)),
      ],
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 31),
      generatedAt: DateTime(2026, 3, 15),
    );
    expect(isPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(1000));
  });

  test('Glucose PDF builds valid bytes incl. eA1C section', () async {
    final readings = List.generate(
      20,
      (i) => GlucoseReading(
          id: 'g$i',
          valueMgdl: 120 + (i % 5) * 10,
          context: GlucoseContext.fasting,
          takenAt: DateTime(2026, 3, 1 + i, 8),
          createdAt: DateTime(2026, 3, 1 + i, 8)),
    );
    final bytes = await VitalsReportService.buildGlucosePdf(
      readings: readings,
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 31),
      generatedAt: DateTime(2026, 3, 25),
    );
    expect(isPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(1000));
  });

  test('empty readings still produce a valid PDF', () async {
    final bytes = await VitalsReportService.buildBpPdf(
        readings: const [], generatedAt: DateTime(2026, 3, 15));
    expect(isPdf(bytes), isTrue);
  });
}
