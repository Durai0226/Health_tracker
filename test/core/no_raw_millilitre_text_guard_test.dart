/// An amount of water in the app's text goes through `Units`, or someone who counts
/// in ounces is shown millilitres on exactly the screen they were promised ounces.
///
/// This is the guard that makes the conversion stick: it reads every Dart file under
/// `lib/` and fails on a number — a digit or an interpolation — written directly
/// against "ml". The few that remain are listed with the reason each is right.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A number against "ml": `250 ml`, `250ml`, `${x} ml`, `$x ml`.
  final rawMl = RegExp(r'(\$\{[^}]*\}|\$\w+|\d) ?ml\b');

  /// Where a number against "ml" is correct, and why. Keyed by file; a line is
  /// allowed when it contains the fragment.
  const allowed = <String, Map<String, String>>{
    'lib/core/services/water_action_queue.dart': {
      'Queued water action': 'a debug line for a developer, not text anyone reads',
    },
    'lib/features/insights/screens/trends_dashboard_screen.dart': {
      "'\${_fmtInt(v)} ml'":
          'the thousands-grouped millilitre branch, chosen only when the unit is ml',
    },
    'lib/features/water/models/custom_drink.dart': {
      'per 100 ml': 'caffeine is stated per 100 ml, the label standard, in either unit',
    },
    'lib/features/water/screens/custom_drink_screen.dart': {
      'every 100 ml': 'the same per-100 ml convention',
    },
    'lib/features/medication/models/enhanced_medicine.dart': {
      '10mg/5ml': 'a medicine strength example, not a drink',
    },
    'lib/features/medication/screens/nunito_add_medication_flow.dart': {
      '10mg/5ml': 'a medicine strength example, not a drink',
    },
  };

  test('no amount is written against "ml" outside the places that are right', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//')) continue;
        // A trailing comment is not text a person reads.
        final code = lines[i].replaceFirst(RegExp(r'\s//.*$'), '');
        if (!rawMl.hasMatch(code)) continue;
        final fragments = allowed[path]?.keys ?? const <String>[];
        if (fragments.any(code.contains)) continue;
        offenders.add('$path:${i + 1}  ${code.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Show an amount with Units.volumeText / volumeNumber, or — if it is '
            'right in millilitres — add it to `allowed` with the reason:\n'
            '${offenders.join('\n')}');
  });

  test('every allowed fragment is still there (a stale entry hides nothing)', () {
    for (final entry in allowed.entries) {
      final text = File(entry.key).readAsStringSync();
      for (final fragment in entry.value.keys) {
        expect(text.contains(fragment), isTrue,
            reason: '${entry.key} no longer contains "$fragment"; drop the entry');
      }
    }
  });

  test('the guard really sees a raw amount', () {
    // Mutation check built in: if the pattern stopped matching, the first test would
    // pass on any file.
    expect(rawMl.hasMatch("'\${goal}ml'"), isTrue);
    expect(rawMl.hasMatch("'\$goal ml'"), isTrue);
    expect(rawMl.hasMatch("'250 ml'"), isTrue);
    expect(rawMl.hasMatch("'250ml'"), isTrue);
    expect(rawMl.hasMatch("'ml left'"), isFalse);
    expect(rawMl.hasMatch("'Amount (ml)'"), isFalse);
  });
}
