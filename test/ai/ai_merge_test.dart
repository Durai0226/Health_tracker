import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/ai_merge.dart';
import 'package:tablet_remainder/core/ai/ai_types.dart';
import 'package:tablet_remainder/core/ai/on_device_llm_engine.dart';

void main() {
  final base = ParsedReminder(
    title: 'Rule title',
    time: DateTime(2026, 3, 10, 9, 0),
    repeat: 'daily',
    priority: 'low',
    categoryHint: 'Health',
    customDays: [1, 4],
    durationMinutes: 30,
  );

  group('AiMerge.mergeReminder', () {
    test('overlays valid LLM fields onto the rule baseline', () {
      final r = AiMerge.mergeReminder(base: base, llm: {
        'title': 'Call mom',
        'repeat': 'weekly',
        'priority': 'high',
        'datetimeIso': '2026-03-20T17:00:00',
        'category': 'Personal',
      });
      expect(r.title, 'Call mom');
      expect(r.repeat, 'weekly');
      expect(r.priority, 'high');
      expect(r.time, DateTime(2026, 3, 20, 17, 0));
      expect(r.categoryHint, 'Personal');
      // Rule-owned fields are preserved.
      expect(r.customDays, [1, 4]);
      expect(r.durationMinutes, 30);
    });

    test('rejects out-of-schema LLM values, keeping the safe baseline', () {
      final r = AiMerge.mergeReminder(base: base, llm: {
        'title': '', // empty → keep base
        'repeat': 'monthly', // not supported → keep base
        'priority': 'urgent', // invalid → keep base
        'datetimeIso': 'not-a-date', // unparseable → keep base time
      });
      expect(r.title, 'Rule title');
      expect(r.repeat, 'daily');
      expect(r.priority, 'low');
      expect(r.time, DateTime(2026, 3, 10, 9, 0));
    });
  });

  group('AiMerge.mergeMedicine', () {
    final medBase = {'name': 'Aspirin', 'frequency': 'once daily'};

    test('overlays valid fields + validates times', () {
      final m = AiMerge.mergeMedicine(base: medBase, llm: {
        'name': 'Ibuprofen',
        'dosageAmount': 200,
        'dosageUnit': 'mg',
        'frequency': 'twice daily',
        'times': ['08:00', '20:00', '25:00', 'noon'], // last two invalid
      });
      expect(m['name'], 'Ibuprofen');
      expect(m['dosageAmount'], 200);
      expect(m['dosageUnit'], 'mg');
      expect(m['frequency'], 'twice daily');
      expect(m['times'], ['08:00', '20:00']);
    });

    test('canonicalizes free-form frequency', () {
      expect(AiMerge.mergeMedicine(base: medBase, llm: {'frequency': 'BID'})['frequency'],
          'twice daily');
      expect(
          AiMerge.mergeMedicine(base: medBase, llm: {'frequency': 'every 8 hours'})['frequency'],
          'everyXHours');
    });

    test('invalid frequency keeps the baseline', () {
      final m = AiMerge.mergeMedicine(base: medBase, llm: {'frequency': 'monthly'});
      expect(m['frequency'], 'once daily');
    });

    test('ignores non-positive dosage', () {
      final m = AiMerge.mergeMedicine(base: {'dosageAmount': 1}, llm: {'dosageAmount': 0});
      expect(m['dosageAmount'], 1);
    });
  });

  group('OnDeviceLlmEngine (build-safe slot)', () {
    test('is inert until a runtime is attached', () async {
      final e = OnDeviceLlmEngine();
      expect(e.id, 'on_device');
      expect(e.isAvailable, isFalse);
      expect(await e.init(), isFalse);
      expect(await e.completeText(system: 's', user: 'u'), isNull);
      expect(await e.completeJson(system: 's', user: 'u'), isNull);
    });
  });
}
