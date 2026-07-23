import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/memory_service.dart';

/// The guard that keeps a data question from ever being mistaken for a memory
/// write. Pure + deterministic — no DB.
void main() {
  group('MemoryCommand.parse — explicit-only classification', () {
    test('a plain data question is NOT a memory command', () {
      for (final q in [
        'what is the luteal phase?',
        'when is my next period?',
        'how did i sleep?',
        'am i hitting my step goal?',
        'do you know how much water i should drink',
      ]) {
        expect(MemoryCommand.parse(q).type, MemoryCommandType.none,
            reason: '"$q" must not be treated as a memory write');
      }
    });

    test('"remember …" saves a fact', () {
      final c = MemoryCommand.parse("remember I'm trying to conceive");
      expect(c.type, MemoryCommandType.remember);
      expect(c.kind, MemoryService.kKindFact);
      expect(c.content, "I'm trying to conceive");
    });

    test('"remember that …" strips the connective', () {
      final c = MemoryCommand.parse('Remember that I take my meds at 8am');
      expect(c.type, MemoryCommandType.remember);
      expect(c.content, 'I take my meds at 8am');
    });

    test('preference phrasing is tagged as a preference', () {
      final c = MemoryCommand.parse('remember I prefer evening reminders');
      expect(c.type, MemoryCommandType.remember);
      expect(c.kind, MemoryService.kKindPreference);
    });

    test('"my goal is …" is a goal', () {
      final c = MemoryCommand.parse('my goal is 8000 steps');
      expect(c.type, MemoryCommandType.remember);
      expect(c.kind, MemoryService.kKindGoal);
      expect(c.content, '8000 steps');
    });

    test('recall is recognized', () {
      for (final q in [
        'what do you remember about me',
        'what do you know about me?',
        'show my memories',
        'what do you remember',
      ]) {
        expect(MemoryCommand.parse(q).type, MemoryCommandType.recall,
            reason: q);
      }
    });

    test('forget-by-text vs forget-last', () {
      final byText = MemoryCommand.parse("forget that I'm trying to conceive");
      expect(byText.type, MemoryCommandType.forget);
      expect(byText.content, "I'm trying to conceive");

      expect(MemoryCommand.parse('forget that').type,
          MemoryCommandType.forgetLast);
      expect(
          MemoryCommand.parse('forget it').type, MemoryCommandType.forgetLast);
    });

    test('empty / whitespace is none', () {
      expect(MemoryCommand.parse('').type, MemoryCommandType.none);
      expect(MemoryCommand.parse('   ').type, MemoryCommandType.none);
    });
  });
}
