/// What was going on when a pressure was taken: context, never a correction.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/bp_tags.dart';

void main() {
  test('every tag has a stable id and a label, and none repeat', () {
    final ids = BpTags.all.map((t) => t.id).toList();
    final labels = BpTags.all.map((t) => t.label).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(labels.toSet(), hasLength(labels.length));
    for (final t in BpTags.all) {
      expect(t.id, matches(RegExp(r'^[a-z_]+$')), reason: 'ids are plain, for a backup');
      expect(t.label, isNotEmpty);
    }
  });

  test('the ids are the ones already written to disk: never renamed', () {
    // A backup written by this build must read the same in the next.
    expect(BpTags.all.map((t) => t.id), [
      'after_exercise',
      'after_caffeine',
      'after_meal',
      'stressed',
      'rushed',
      'slept_badly',
      'missed_medicine',
      'at_clinic',
    ]);
  });

  group('labels', () {
    test('a known tag shows its label', () {
      expect(BpTags.labelOf('after_caffeine'), 'After caffeine');
    });

    test('one this build does not know is made readable, not hidden', () {
      expect(BpTags.labelOf('after_swim'), 'After swim');
      expect(BpTags.labelOf('white_coat'), 'White coat');
    });

    test('and nothing breaks on odd input', () {
      expect(BpTags.labelOf(''), '');
      expect(BpTags.labelOf('___'), '___');
    });
  });

  group('describe', () {
    test('in the catalogue\'s order, whatever order they were ticked in', () {
      expect(BpTags.describe(['stressed', 'after_exercise']),
          'After exercise, Stressed');
    });

    test('with an unknown one after the known ones', () {
      expect(BpTags.describe(['after_swim', 'stressed']), 'Stressed, After swim');
    });

    test('nothing is nothing', () {
      expect(BpTags.describe(const []), '');
    });

    test('a repeat is said once', () {
      expect(BpTags.describe(['stressed', 'stressed']), 'Stressed');
    });
  });

  group('normalise', () {
    test('catalogue order, whatever order they were ticked in', () {
      expect(BpTags.normalise(['stressed', 'after_exercise']),
          ['after_exercise', 'stressed']);
    });

    test('each once', () {
      expect(BpTags.normalise(['stressed', 'stressed', 'rushed']), ['stressed', 'rushed']);
    });

    test('unknown ones kept, after the known, in the order given', () {
      expect(BpTags.normalise(['b_unknown', 'stressed', 'a_unknown']),
          ['stressed', 'b_unknown', 'a_unknown']);
    });

    test('nothing is nothing', () {
      expect(BpTags.normalise(const []), isEmpty);
    });
  });

  group('toggle', () {
    test('on adds it', () {
      expect(BpTags.toggle(['stressed'], 'rushed', on: true), ['stressed', 'rushed']);
    });

    test('on twice does not double it', () {
      expect(BpTags.toggle(['stressed'], 'stressed', on: true), ['stressed']);
    });

    test('off removes it', () {
      expect(BpTags.toggle(['stressed', 'rushed'], 'stressed', on: false), ['rushed']);
    });

    test('and leaves a tag this build does not know exactly where it was', () {
      expect(BpTags.toggle(['after_swim', 'stressed'], 'stressed', on: false),
          ['after_swim'],
          reason: 'an edit must not quietly wipe what another build wrote');
      expect(BpTags.toggle(['after_swim'], 'rushed', on: true), ['after_swim', 'rushed']);
    });
  });
}
