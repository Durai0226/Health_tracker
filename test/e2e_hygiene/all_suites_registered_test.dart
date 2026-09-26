import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every device suite must be reachable from `all_e2e_test.dart`.
///
/// This has now silently happened **twice**: `e01_focus_e2e_test.dart` and then
/// `c01_water_e2e_test.dart` were both written, both committed, and neither was
/// imported into the aggregator — so the device pass ran every suite except the
/// feature it had just been written for. Nothing fails when a suite is missing;
/// the run simply reports success for less work, which is the worst shape a gap
/// can take.
///
/// `flutter test integration_test/` starts the app once per FILE, and each start
/// costs a gradle assemble and install, so the aggregator is not an optional
/// convenience — a suite outside it effectively never runs.
void main() {
  test('every e2e suite is imported into all_e2e_test.dart', () {
    final dir = Directory('integration_test');
    final suites = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('_e2e_test.dart'))
        .where((n) => n != 'all_e2e_test.dart')
        .toList()
      ..sort();

    expect(suites, isNotEmpty, reason: 'no e2e suites found — wrong path?');

    final aggregator = _codeOnly(
      File('integration_test/all_e2e_test.dart').readAsStringSync(),
    );

    // Match real import DIRECTIVES in CODE, not in the raw file text. Two
    // distinct ways a substring search goes vacuous here, both of which this
    // aggregator can produce:
    //
    //  * the filename appears in prose — the aggregator's comments discuss
    //    suites by name, so `contains('d02_smart_add_e2e_test.dart')` is
    //    satisfied by a `// TODO: re-register …` note;
    //  * the directive itself is COMMENTED OUT — `// import '…' as d02;` is
    //    the ordinary shape of this regression, and it still matches a regex
    //    run over the raw text.
    //
    // `_codeOnly` removes comments first, so neither survives. Verified by
    // mutation in both forms.
    final imported = RegExp(r"^\s*import '([^']+_e2e_test\.dart)'", multiLine: true)
        .allMatches(aggregator)
        .map((m) => m.group(1)!)
        .toSet();

    // Suites that mutate shared state destructively run standalone against a
    // hermetic database — the aggregator's own doc explains why. They are listed
    // here explicitly so "not registered" always means a deliberate choice
    // rather than an oversight.
    //
    // EMPTY, and that is the point. It used to hold b01, b02, c05 and d02 under
    // the "destructive" heading, and none of the four is destructive: b01
    // deletes every medicine it creates, b02's subject IS Undo (stock and log
    // both restored), c05 deletes its crisis reading as the second half of its
    // own assertion, and d02 stops at the prefilled form without ever saving.
    // All four end on `E2E.assertClean`. So the exemption was not a deliberate
    // choice about shared state — it was this test's own escape hatch, and it
    // kept four of eleven suites, including the drug-interaction safety dialog,
    // out of every device run while reporting success.
    //
    // Add an entry only with a reason that names the shared state the suite
    // destroys.
    const intentionallyStandalone = <String>{};

    final missing = <String>[];
    for (final suite in suites) {
      if (intentionallyStandalone.contains(suite)) continue;
      if (!imported.contains(suite)) missing.add(suite);
    }

    expect(
      missing,
      isEmpty,
      reason: 'These suites exist but the device pass never runs them:\n'
          '  ${missing.join('\n  ')}\n'
          'Either import them into all_e2e_test.dart, or add them to '
          'intentionallyStandalone in this test with a reason.',
    );
  });

  test('every import in the aggregator is also invoked', () {
    // Importing a suite without calling its main() is the same gap wearing a
    // disguise — the file compiles, the alias is used by nothing, and the tests
    // never run.
    final src = _codeOnly(
      File('integration_test/all_e2e_test.dart').readAsStringSync(),
    );
    final aliases = RegExp(
      r"^\s*import '[^']+_e2e_test\.dart' as (\w+);",
      multiLine: true,
    ).allMatches(src).map((m) => m.group(1)!).toList();

    expect(aliases, isNotEmpty);
    // The invocation must be CODE too: `// d02.main();` one line below a
    // commented-out import is how this pair of guards would otherwise agree
    // that a suite it no longer runs is still registered.
    final invoked = RegExp(r'^\s*(\w+)\.main\(\);', multiLine: true)
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
    for (final alias in aliases) {
      expect(invoked, contains(alias),
          reason: '$alias is imported but its main() is never called');
    }
  });
}

/// Dart source with comments removed, so a guard that scans for directives
/// cannot be satisfied by a directive that has been commented out.
///
/// Deliberately simple: block comments, then whole-line and trailing `//`
/// comments. It is not a Dart parser — it would mangle a `//` inside a string
/// literal — but the aggregator it reads holds only import directives and
/// `main()` calls, neither of which contains one.
String _codeOnly(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return withoutBlocks
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');
}
