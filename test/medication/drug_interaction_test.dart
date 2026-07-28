import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/services/drug_interaction_service.dart';

/// QA — drug interaction checker (F2). Pure in-memory database, no I/O.
void main() {
  final svc = DrugInteractionService();

  group('checkInteraction — positive', () {
    test('a known interacting pair is flagged (Warfarin + Aspirin)', () {
      final hits = svc.checkInteraction('Warfarin', 'Aspirin');
      expect(hits, isNotEmpty);
    });

    test('order does not matter (Aspirin + Warfarin also flagged)', () {
      expect(svc.checkInteraction('Aspirin', 'Warfarin'), isNotEmpty);
    });

    test('matching is case-insensitive', () {
      expect(svc.checkInteraction('warfarin', 'aspirin'), isNotEmpty);
    });
  });

  group('checkInteraction — negative', () {
    test('two unrelated / unknown drugs return no interaction', () {
      expect(svc.checkInteraction('Foobarium', 'Bazquxil'), isEmpty);
    });

    test('a drug against itself is not a false interaction', () {
      expect(svc.checkInteraction('Aspirin', 'Aspirin'), isEmpty);
    });
  });

  group('checkFoodInteractions', () {
    test('returns a list without throwing for a known drug', () {
      expect(svc.checkFoodInteractions('Warfarin'), isA<List<String>>());
    });

    test('an unknown drug has no food interactions', () {
      expect(svc.checkFoodInteractions('Foobarium'), isEmpty);
    });
  });
}
