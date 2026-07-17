import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/safety_guard.dart';

void main() {
  group('SafetyGuard.emergencyResponse', () {
    test('detects red-flag symptoms and returns an emergency card', () {
      for (final q in [
        'I have severe chest pain right now',
        "I can't breathe properly",
        'my face is drooping and speech is slurred',
        'I think I took too many pills and feel sick',
        'my throat is closing, severe allergic reaction',
        'I feel suicidal',
        'he is unresponsive and had a seizure',
      ]) {
        final r = SafetyGuard.emergencyResponse(q);
        expect(r, isNotNull, reason: q);
        expect(r!.toLowerCase(), contains('emergency'));
      }
    });

    test('does NOT false-alarm on benign medicine questions', () {
      for (final q in [
        'can I take this with food?',
        'what is this medicine for?',
        'did I miss my dose?',
        'can this cause a mild headache?',
      ]) {
        expect(SafetyGuard.emergencyResponse(q), isNull, reason: q);
      }
    });

    test('localizes the emergency number', () {
      expect(SafetyGuard.emergencyResponse('chest pain', locale: 'en_US'), contains('911'));
      expect(SafetyGuard.emergencyResponse('chest pain', locale: 'en_GB'), contains('999'));
      expect(SafetyGuard.emergencyResponse('chest pain', locale: 'in'), contains('112'));
    });
  });

  group('SafetyGuard.ensureDisclaimer', () {
    test('appends the disclaimer when missing', () {
      final out = SafetyGuard.ensureDisclaimer('Take it in the morning.');
      expect(SafetyGuard.hasDisclaimer(out), isTrue);
    });

    test('is idempotent when a disclaimer is already present', () {
      final once = SafetyGuard.ensureDisclaimer('Some info.');
      final twice = SafetyGuard.ensureDisclaimer(once);
      expect(once, twice);
    });

    test('recognizes existing paraphrased disclaimers', () {
      expect(SafetyGuard.hasDisclaimer('…the most reliable source is your pharmacist or doctor.'), isTrue);
      expect(SafetyGuard.hasDisclaimer('ask your pharmacist for details'), isTrue);
      expect(SafetyGuard.hasDisclaimer('take one tablet daily'), isFalse);
    });
  });
}
