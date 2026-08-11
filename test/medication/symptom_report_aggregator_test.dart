import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/services/symptom_report_aggregator.dart';

/// Phase 2's aggregation gate: the report's "Symptoms & well-being" section is
/// only as trustworthy as this pure function. It must count side effects and
/// average mood/effectiveness from TAKEN doses only, and must never be
/// re-deriving dedup itself — see the file-level doc: callers are required to
/// pass an already `dedupeByDose`d, windowed log list, exactly as
/// `AdherenceReportService.buildPdf` does.
void main() {
  MedicineLog taken({
    String id = 'l1',
    DateTime? at,
    String? sideEffects,
    int? mood,
    int? effectiveness,
  }) =>
      MedicineLog.taken(
        id: id,
        medicineId: 'm1',
        scheduledTime: at ?? DateTime(2026, 3, 1, 8),
        sideEffects: sideEffects,
        moodRating: mood,
        effectivenessRating: effectiveness,
      );

  MedicineLog skipped({String id = 's1', DateTime? at}) => MedicineLog.skipped(
        id: id,
        medicineId: 'm1',
        scheduledTime: at ?? DateTime(2026, 3, 1, 8),
        reason: SkipReason.values.first,
      );

  MedicineLog missed({String id = 'm-miss', DateTime? at}) => MedicineLog.missed(
        id: id,
        medicineId: 'm1',
        scheduledTime: at ?? DateTime(2026, 3, 1, 8),
      );

  group('summarizeSymptoms', () {
    test('counts each reported side effect across taken doses', () {
      final logs = [
        taken(id: 'a', sideEffects: 'Nausea, Headache'),
        taken(id: 'b', sideEffects: 'Nausea'),
        taken(id: 'c', sideEffects: 'Nausea'),
        taken(id: 'd'), // no side effects this dose
      ];

      final s = summarizeSymptoms('Metformin 500mg', logs);

      expect(s.takenCount, 4);
      expect(s.sideEffectCounts, {'Nausea': 3, 'Headache': 1});
      expect(s.sideEffectsLabel, 'Nausea x3, Headache x1'); // most-reported first
      expect(s.hasAnyData, isTrue);
    });

    test('averages mood and effectiveness independently, ignoring unset ones', () {
      final logs = [
        taken(id: 'a', mood: 5, effectiveness: 4),
        taken(id: 'b', mood: 3, effectiveness: 2),
        taken(id: 'c'), // neither recorded — must not count as a 0
      ];

      final s = summarizeSymptoms('Aspirin', logs);

      expect(s.meanMood, 4.0); // (5+3)/2, not /3
      expect(s.meanEffectiveness, 3.0); // (4+2)/2, not /3
    });

    test('moodLabel and effectivenessLabel describe the SAME numeric mean '
        'in opposite directions — regression cover for the adversarial '
        'review finding that a bare "X.X/5" is ambiguous between the two',
        () {
      // A mean of 4 is 'Bad' for mood (1=best..5=worst) but 'Good' for
      // effectiveness (1=worst..5=best) — the labels must reflect that, not
      // collapse to the same word or the same implied direction.
      final s = summarizeSymptoms('X', [taken(mood: 4, effectiveness: 4)]);

      expect(s.moodLabel, 'Bad');
      expect(s.effectivenessLabel, 'Good');
      expect(s.moodLabel, isNot(s.effectivenessLabel));
    });

    test('label getters are null exactly when the corresponding mean is null', () {
      final s = summarizeSymptoms('X', [taken()]);
      expect(s.moodLabel, isNull);
      expect(s.effectivenessLabel, isNull);
    });

    test('only TAKEN doses contribute — skipped/missed never do', () {
      // Skipped/missed logs can never carry these fields via their own
      // factories, but summarizeSymptoms must filter by status regardless of
      // what a log happens to hold, not rely on that invariant alone.
      final tainted = skipped(id: 'sk').copyWith(
          sideEffects: 'Nausea', moodRating: 1, effectivenessRating: 1);
      final logs = [taken(id: 't', mood: 5), tainted, missed(id: 'ms')];

      final s = summarizeSymptoms('X', logs);

      expect(s.takenCount, 1);
      expect(s.meanMood, 5.0); // the skipped log's mood=1 must not pull this down
      expect(s.sideEffectCounts, isEmpty); // the skipped log's side effect ignored
    });

    test('a medicine with no symptom data at all reports hasAnyData=false', () {
      final s = summarizeSymptoms('Vitamin D', [taken(id: 'a'), taken(id: 'b')]);

      expect(s.hasAnyData, isFalse);
      expect(s.meanMood, isNull);
      expect(s.meanEffectiveness, isNull);
      expect(s.sideEffectsLabel, isNull);
    });

    test('an empty log list is handled without throwing', () {
      final s = summarizeSymptoms('Nothing taken', const []);
      expect(s.takenCount, 0);
      expect(s.hasAnyData, isFalse);
    });

    test('side-effect free text is split and trimmed on commas', () {
      final s = summarizeSymptoms(
          'X', [taken(sideEffects: ' Nausea ,  Dry mouth,  ,Nausea')]);
      // A blank segment (from the doubled comma) must not become a phantom
      // "" side-effect entry, and surrounding whitespace must not create
      // duplicate keys ('Nausea' vs 'Nausea ').
      expect(s.sideEffectCounts, {'Nausea': 2, 'Dry mouth': 1});
    });
  });
}
