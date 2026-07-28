import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/ai_assistant.dart';
import 'package:tablet_remainder/core/ai/rule_based_engine.dart';

/// QA — drug Q&A (Feature C). Confirms the offline drug-info KB tier returns a
/// real, drug-specific, disclaimed answer for known medicines (replacing the
/// old "ask your pharmacist" deflection), and still falls back gracefully +
/// disclaimed for unknown drugs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiAssistant.medicineAnswer — offline drug-info tier', () {
    test('a known generic returns real, specific info (not a deflection)',
        () async {
      final a = await AiAssistant().medicineAnswer(
          name: 'Dolo 650', generic: 'Paracetamol', question: 'what is it for?');
      expect(a, isNotNull);
      expect(a!.toLowerCase(), contains('pain'));
    });

    test('a known generic side-effect question returns specifics', () async {
      final a = await AiAssistant().medicineAnswer(
          name: 'Paracetamol', generic: 'Paracetamol', question: 'side effects?');
      expect(a!.toLowerCase(), contains('liver'));
    });

    test('every medical answer carries the not-medical-advice disclaimer',
        () async {
      final a = await AiAssistant().medicineAnswer(
          name: 'Paracetamol', generic: 'Paracetamol', question: 'what is it for?');
      expect(a!.toLowerCase(), contains('not medical advice'));
    });

    test('an unknown drug falls back to the general deflection (disclaimed)',
        () async {
      final a = await AiAssistant().medicineAnswer(
          name: 'Zzzmadeup', generic: 'Zzzmadeup', question: 'what is it for?');
      expect(a, isNotNull);
      expect(a!.toLowerCase(), isNot(contains('liver')));
      // The deflection is itself self-disclaiming ("ask your pharmacist"), which
      // SafetyGuard.hasDisclaimer recognizes — so it's not double-disclaimed.
      expect(a.toLowerCase(),
          anyOf(contains('pharmacist'), contains('leaflet'), contains('prescribed')));
    });
  });

  group('RuleBasedEngine.medicineAnswer — deflection fallbacks', () {
    const engine = RuleBasedEngine();

    test('a food question gives label/pharmacist guidance', () {
      final a = engine.medicineAnswer(name: 'X', question: 'with food?');
      expect(a.toLowerCase(), contains('food'));
    });

    test('a missed-dose question gives safe generic advice', () {
      final a = engine.medicineAnswer(name: 'X', question: 'what if I miss a dose?');
      expect(a.toLowerCase(), anyOf(contains('miss'), contains('next dose')));
    });

    test('a saved note is echoed when provided', () {
      final a = engine.medicineAnswer(
          name: 'X', question: 'anything?', instructions: 'after lunch');
      expect(a, contains('after lunch'));
    });
  });
}
