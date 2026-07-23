import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/services/drug_interaction_service.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';

/// Guards the "What it's for" feature: the flagship example (Dolo 650 →
/// Paracetamol → Acetaminophen monograph) must resolve, uncovered meds must
/// fall back to null (so the UI shows the user's own note, never a fabrication).
void main() {
  final svc = DrugInteractionService();

  group('purposeSummary', () {
    test('Dolo 650 / Paracetamol / Crocin / Acetaminophen all resolve', () {
      for (final n in ['Dolo 650', 'Paracetamol', 'Crocin', 'Acetaminophen']) {
        final s = svc.purposeSummary(name: n);
        expect(s, isNotNull, reason: n);
        expect(s!.toLowerCase(), contains('acetaminophen'));
        expect(s.toLowerCase(),
            anyOf(contains('pain'), contains('fever')), reason: n);
      }
    });

    test('other covered common meds resolve', () {
      for (final n in ['Ibuprofen', 'Metformin', 'Atorvastatin', 'Amoxicillin']) {
        expect(svc.purposeSummary(name: n), isNotNull, reason: n);
      }
    });

    test('uncovered med returns null (UI falls back to the user note)', () {
      expect(svc.purposeSummary(name: 'Gabapentin'), isNull);
      expect(svc.purposeSummary(name: 'Zzznotreal'), isNull);
    });

    test('genericName is used when the brand alone would not resolve', () {
      expect(svc.purposeSummary(name: 'Azithral', genericName: 'Metformin'),
          isNotNull);
    });
  });

  group('primaryUses', () {
    test('short phrase for a covered med', () {
      final u = svc.primaryUses(name: 'Paracetamol');
      expect(u, isNotNull);
      expect(u!.toLowerCase(), anyOf(contains('pain'), contains('fever')));
    });

    test('null for an uncovered med', () {
      expect(svc.primaryUses(name: 'Gabapentin'), isNull);
    });
  });

  group('DrugNameCatalog.genericFor', () {
    test('resolves a brand to its generic from the bundled asset', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await DrugNameCatalog.ensureLoaded();
      expect(DrugNameCatalog.genericFor('Dolo 650'), 'Paracetamol');
      expect(DrugNameCatalog.genericFor('Lipitor'), 'Atorvastatin');
      expect(DrugNameCatalog.genericFor('nope-not-real'), isNull);
    });
  });
}
