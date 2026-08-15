import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every literal the device suites assert on must still exist in `lib/`.
///
/// **The defect this closes.** Four integration suites asserted strings that
/// had been deleted from the app months earlier:
///
///   'Save Reminder'   'Medicine Tracker'   'Water Tracker'
///   'What would you like to add?'   'Add Medicine'   'AI Assistant'
///   "Today's Progress"   'Notes'   'Finance'
///
/// Zero hits in `lib/`, every one of them. The suites either failed for a
/// reason nobody read, or — worse — passed anyway because the assertion was
/// wrapped in `if (finder.evaluate().isNotEmpty)`.
///
/// A device run costs a gradle build plus minutes on an emulator, so nobody ran
/// them often enough to notice. This test does the same job in well under a
/// second, headless, on every `flutter test`. The day someone renames a
/// heading, this names the constant.
///
/// It reads the registry off disk rather than importing it, for the same reason
/// `test/health/no_generative_ai_guard_test.dart` does: an import proves the
/// constant compiles, not that the string is still in the product.
void main() {
  final root = Directory.current.path;
  final registry = File('$root/integration_test/support/app_strings.dart');

  late Map<String, String> constants; // name -> literal
  late String libCorpus;

  setUpAll(() {
    expect(registry.existsSync(), isTrue,
        reason: 'app_strings.dart is the contract this test enforces');

    // One `const kFoo = '...';` per line, by construction (see the file's docs).
    final re = RegExp(r"^const\s+(\w+)\s*=\s*'(.*)';", multiLine: true);
    constants = {
      for (final m in re.allMatches(registry.readAsStringSync()))
        m.group(1)!: m.group(2)!,
    };

    final buf = StringBuffer();
    for (final f in Directory('$root/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      buf.writeln(f.readAsStringSync());
    }
    libCorpus = buf.toString();
  });

  test('the registry is not empty and parsed correctly', () {
    // Guards the guard: a regex that matches nothing would make every
    // assertion below vacuously true. This is the exact failure mode recorded
    // in test/support/counting_executor.dart:9-13 — a matcher that matched
    // nothing, counted zero, and passed with the bug restored.
    expect(constants.length, greaterThan(20),
        reason: 'Parsed only ${constants.length} constants from '
            'app_strings.dart. Either the file shrank or the parser broke — '
            'and a broken parser makes this whole suite pass vacuously.');
    expect(constants['kLogSheetTitle'], 'Log something',
        reason: 'sanity anchor: the parser reads values, not just names');
  });

  test('every registered string still exists in lib/', () {
    final missing = <String>[];
    constants.forEach((name, literal) {
      if (!libCorpus.contains("'$literal'")) missing.add("$name = '$literal'");
    });

    expect(
      missing,
      isEmpty,
      reason: 'These strings are asserted by the device suites but no longer '
          'appear anywhere in lib/. Either the UI was renamed (update the '
          'constant AND its assertions) or the feature was deleted (delete '
          'the constant AND its assertions). Leaving them is how four suites '
          'rotted into uselessness:\n  ${missing.join('\n  ')}',
    );
  });

  test('device suites assert through the registry, not raw literals', () {
    // A raw literal in a suite is invisible to the check above, so it is the
    // one way this guard can be bypassed by accident.
    final offenders = <String>[];
    final dir = Directory('$root/integration_test');
    if (!dir.existsSync()) return;

    for (final f in dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))) {
      final name = f.uri.pathSegments.last;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Skip comments, or these rules fire on their own documentation.
        final code = lines[i].split('//').first;
        // A NEGATIVE assertion names a string that must NOT be in the product
        // (`find.text('User')` proving the placeholder is gone). Registering it
        // would be self-contradictory: the registry demands its entries EXIST
        // in lib/. Opt out per line, with a reason.
        // Look back a few lines: an `expect(...)` spans several, so the marker
        // usually sits above the whole call rather than on the finder itself.
        final window = lines.sublist((i - 3).clamp(0, i), i + 1);
        if (window.any((l) => l.contains('e2e-absent-ok:'))) continue;
        for (final m in RegExp(r"find\.text\(\s*'([^']{2,})'").allMatches(code)) {
          offenders.add("$name:${i + 1} find.text('${m.group(1)}')");
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'find.text() with a raw literal bypasses the registry, so '
          'nothing notices when the UI renames it. Move the string into '
          'integration_test/support/app_strings.dart and reference the '
          'constant — or annotate `// e2e-absent-ok: <reason>` if the '
          'assertion proves the string is ABSENT:\n  ${offenders.join('\n  ')}',
    );
  });
}
