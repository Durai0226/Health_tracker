/// The Condition Library must never tell someone what they have.
///
/// Suggestions are allowed; findings are not. *"People taking Amlodipine often
/// read about high blood pressure"* is a reading suggestion. *"Your condition:
/// hypertension"* is a diagnostic claim, and under Play's Health Content policy
/// that is a different product.
///
/// Copy is one careless edit away from crossing that line, and nothing about a
/// pull request makes the crossing visible — so it gets a guard rather than a
/// guideline, in the same source-grep idiom as
/// `test/health/no_generative_ai_guard_test.dart`.
///
/// ## What is banned, and what deliberately is not
///
/// The ban is on **assertions about the reader**, not on the vocabulary of
/// medicine. `"That is not a diagnosis"` is exactly the copy this feature
/// should carry, so a bare `diagnos` ban would forbid the good version along
/// with the bad. Only the asserting forms are listed.
///
/// This distinction is not hypothetical: the first draft of
/// `ConditionMedicineLink.why` read *"It does not mean you have this
/// condition"* — an honest negation that a blunt substring check flagged
/// anyway. The copy was reworded rather than the guard taught to parse
/// negation, because a guard that has to understand negation is a guard that
/// will eventually be wrong about it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Everything that renders or produces Condition Library copy.
const _watched = <String>[
  'lib/features/medication/data/condition_library_data.dart',
  'lib/features/medication/models/condition_info.dart',
  'lib/features/medication/screens/conditions',
  'lib/features/medication/services/condition_library_service.dart',
  'lib/features/medication/services/condition_taxonomy.dart',
  'lib/features/medication/services/condition_search_index.dart',
];

/// Assertions about the reader. Lower-cased before matching.
const _banned = <String>[
  'you have',
  'you likely have',
  'you may have',
  'you probably have',
  'your condition',
  'your diagnosis',
  'diagnosed with',
  'we think you',
  'this means you',
  'suggests you have',
];

/// Single- or double-quoted runs. Written as two adjacent literals because a
/// single Dart string cannot hold both quote characters raw.
final _literal = RegExp("'([^']*)'" r'|"([^"]*)"');

/// Quoted runs on a line, with `//` and `///` lines removed first.
Iterable<String> _stringLiterals(String line) sync* {
  final code = line.trimLeft();
  if (code.startsWith('//')) return;
  for (final m in _literal.allMatches(line)) {
    yield m.group(1) ?? m.group(2) ?? '';
  }
}

List<File> _dartFilesIn(String path) {
  final f = File(path);
  if (f.existsSync()) return [f];
  final d = Directory(path);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((x) => x.path.endsWith('.dart'))
      .toList();
}

void main() {
  test('the watched paths all exist', () {
    // A guard pointed at a moved file passes forever while checking nothing.
    for (final p in _watched) {
      expect(File(p).existsSync() || Directory(p).existsSync(), isTrue,
          reason: '$p is gone — update this list or the guard is checking '
              'nothing');
    }
  });

  test('no user-facing string asserts a condition about the reader', () {
    final offenders = <String>[];

    for (final path in _watched) {
      for (final file in _dartFilesIn(path)) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final s in _stringLiterals(lines[i])) {
            final lower = s.toLowerCase();
            for (final b in _banned) {
              if (lower.contains(b)) {
                offenders.add('${file.path}:${i + 1}  "$b"  in: $s');
              }
            }
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'The Condition Library may suggest reading; it may not tell '
            'someone what they have. Reword so the subject of the sentence is '
            'the MEDICINE or the PAGE, not the reader.\n'
            '${offenders.join('\n')}');
  });

  test('the disclaimer wording that SHOULD pass, does', () {
    // Pins the distinction the ban list draws, so a future tightening cannot
    // quietly forbid the good copy along with the bad.
    const good = [
      'That is not a diagnosis — only a clinician can say what applies to you.',
      'This is general information, not medical advice or a diagnosis.',
      "This medicine's drug family is commonly used for conditions in this area.",
    ];
    for (final s in good) {
      final lower = s.toLowerCase();
      for (final b in _banned) {
        expect(lower.contains(b), isFalse,
            reason: 'the ban list now forbids legitimate copy: "$b" in "$s"');
      }
    }
  });

  test('the guard actually catches the phrasing it exists to catch', () {
    // A ban list is worthless if nothing would ever trip it. These are the
    // sentences a well-meaning edit would produce.
    const bad = [
      "Your condition: high blood pressure",
      'Based on your medicines, you have type 2 diabetes',
      'You may have asthma',
      'You were diagnosed with hypertension',
    ];
    for (final s in bad) {
      final lower = s.toLowerCase();
      expect(_banned.any(lower.contains), isTrue, reason: 'missed: $s');
    }
  });
}
