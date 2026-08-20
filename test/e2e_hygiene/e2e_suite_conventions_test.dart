import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mechanical enforcement of the five rules that keep a device suite able to
/// FAIL. Every rule here exists because a real suite in this repo broke it and
/// went green anyway.
///
/// Same on-disk-grep idiom as `test/health/no_generative_ai_guard_test.dart`,
/// and for the same reason: this is a property of the source text, so checking
/// the text is the honest check.
void main() {
  final root = Directory.current.path;
  final dir = Directory('$root/integration_test');

  List<File> testsUnder(Directory d) => !d.existsSync()
      ? <File>[]
      : d
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .toList();

  /// Device suites. The five original rules below are all about *device*
  /// failure modes, so they stay scoped here.
  List<File> suites() => testsUnder(dir);

  /// Headless unit/widget suites. Only the rules that are equally true off-device
  /// are applied to these — see `unitRuleScope` below for which, and why not the
  /// others.
  ///
  /// This file excludes itself: its own rule regexes are code, not comments, so
  /// `RegExp(r'Icons\.')` would be reported as a violation of the rule it
  /// implements.
  List<File> unitSuites() => testsUnder(Directory('$root/test'))
      .where((f) => !f.path.endsWith('e2e_suite_conventions_test.dart'))
      .toList();

  String rel(File f) => f.path.replaceFirst('$root/', '');

  /// Drops the comment tail of a line, respecting quotes.
  ///
  /// Load-bearing, not tidiness. Without it these rules fire on their OWN
  /// documentation — a comment reading "was `pumpAndSettle`, now settle()" is
  /// reported as a violation, so the honest explanation of a fix becomes
  /// indistinguishable from the defect. Every rule below scans code only.
  String codeOf(String line) {
    var inSingle = false, inDouble = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == r'\') {
        i++;
        continue;
      }
      if (c == "'" && !inDouble) {
        inSingle = !inSingle;
      } else if (c == '"' && !inSingle) {
        inDouble = !inDouble;
      } else if (c == '/' &&
          !inSingle &&
          !inDouble &&
          i + 1 < line.length &&
          line[i + 1] == '/') {
        return line.substring(0, i);
      }
    }
    return line;
  }

  /// Reports `path:line  <text>` for every CODE line matching [re].
  ///
  /// An opt-out marker is honoured on the offending line or the one above it,
  /// and is looked for in the RAW line — the marker lives in a comment.
  List<String> scan(RegExp re, {String? optOut, List<File>? files}) {
    final hits = <String>[];
    for (final f in files ?? suites()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = codeOf(lines[i]);
        if (!re.hasMatch(code)) continue;
        // Look back a few lines, not one: an opt-out worth writing usually
        // needs a sentence, and a two-line comment would otherwise fall
        // outside the window and be silently ignored.
        final window = lines.sublist((i - 3).clamp(0, i), i + 1);
        if (optOut != null && window.any((l) => l.contains(optOut))) continue;
        hits.add('${rel(f)}:${i + 1}  ${lines[i].trim()}');
      }
    }
    return hits;
  }

  test('the scanner sees the suites at all', () {
    // Without this, an empty glob would make every rule below pass vacuously.
    expect(suites(), isNotEmpty,
        reason: 'Found no *_test.dart under integration_test/ — the rules '
            'below would all pass having checked nothing.');
  });

  test('no conditional assertions', () {
    final hits = scan(RegExp(r'evaluate\(\)\.is(Not)?Empty'),
        optOut: 'e2e-conditional-ok:');
    expect(
      hits,
      isEmpty,
      reason: 'An assertion guarded by "is this widget present?" can only run '
          'when it would pass — it is a tautology, not a test. This idiom is '
          'why relaxation_music_e2e_test.dart could navigate nowhere and '
          'still report 39 passing assertions. Use E2E.at(marker, where:) '
          'instead, or annotate the line `// e2e-conditional-ok: <reason>` if '
          'it is genuinely a measurement and not an assertion:\n  '
          '${hits.join('\n  ')}',
    );
  });

  test('no pumpAndSettle', () {
    final hits = scan(RegExp(r'\bpumpAndSettle\b'), optOut: 'e2e-settle-ok:');
    expect(
      hits,
      isEmpty,
      reason: 'This app runs continuous animations (nav orb, loading '
          'skeletons, ad views), so pumpAndSettle never returns — it TIMES '
          'OUT. integration_test sets defaultTestTimeout = Timeout.none, so '
          'each one burns ten real minutes and --timeout cannot shorten it. '
          'medication_water_e2e_test.dart had 24 of them. Use settle(t):\n  '
          '${hits.join('\n  ')}',
    );
  });

  test('no find.byIcon(Icons.*) — the app uses Symbols.*', () {
    final hits = scan(RegExp(r'Icons\.'), optOut: 'e2e-icons-ok:');
    expect(
      hits,
      isEmpty,
      reason: 'IconData equality compares codePoint AND fontFamily AND '
          'fontPackage. This app draws Symbols.* from the '
          'material_symbols_icons package (app_icons.dart), so '
          'find.byIcon(Icons.foo) is a PERMANENT ZERO MATCH — it can never '
          'find anything, in any build. Four such assertions shipped in the '
          'old suites. Use Symbols.*:\n  ${hits.join('\n  ')}',
    );
  });

  test('app.main() is called only from support/e2e.dart', () {
    final hits = scan(RegExp(r'\bapp\.main\(\)'));
    expect(
      hits,
      isEmpty,
      reason: 'Launching the app directly skips the FlutterError collector '
          'that E2E.launch() installs, so the test silently loses the ability '
          'to see framework errors — the exact defect that made every suite '
          'unfailable. Use E2E.launch(tester):\n  ${hits.join('\n  ')}',
    );
  });

  test('every testWidgets body contains at least one expect()', () {
    final offenders = <String>[];
    for (final f in suites()) {
      final src = f.readAsStringSync();
      // Split on test declarations; each chunk is one test body (plus trailing
      // text, which is fine — we only ask whether an expect appears at all).
      final chunks = src.split(RegExp(r'testWidgets\s*\('));
      for (var i = 1; i < chunks.length; i++) {
        final body = chunks[i];
        // `E2E.assertClean` and `E2E.at` are assertions — they wrap `expect`.
        // Counting only the literal token would push suites back toward
        // inlining assertions instead of using the shared, well-worded ones.
        if (body.contains('expect(') ||
            body.contains('E2E.assertClean(') ||
            body.contains('E2E.at(')) {
          continue;
        }
        if (body.contains('e2e-measure-only:')) continue;
        final title =
            RegExp(r"^\s*'([^']*)'").firstMatch(body)?.group(1) ?? '<unnamed>';
        offenders.add('${rel(f)}  testWidgets("$title")');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'A testWidgets with no expect() is a report generator wearing a '
          "test's clothes: it runs, prints, and always passes. perf_e2e_test "
          'had four. Annotate `// e2e-measure-only: <reason>` if a harness is '
          'genuinely measurement-only:\n  ${offenders.join('\n  ')}',
    );
  });

  test('no markTestSkipped without a written reason', () {
    final hits = scan(RegExp(r'markTestSkipped'), optOut: 'e2e-skip-ok:');
    expect(
      hits,
      isEmpty,
      reason: 'Skipping on a missing finder converts "the feature is broken" '
          'into a green run. Annotate `// e2e-skip-ok: <reason>` if the skip '
          'is genuinely about an absent platform capability:\n  '
          '${hits.join('\n  ')}',
    );
  });

  // ---------------------------------------------------------------------------
  // Rules that hold for the HEADLESS suites too.
  //
  // Only two of the five above generalise, and the reasoning matters because
  // over-extending them would have made this file useless:
  //
  //   * pumpAndSettle — NOT extended. It is banned on device because
  //     integration_test sets `defaultTestTimeout = Timeout.none`, so a
  //     never-settling animation burns ten real minutes. Under `flutter test`
  //     it is the normal, correct idiom, and there are 86 legitimate uses in
  //     test/. Banning it there would be cargo-culting the rule past its reason.
  //   * app.main() — NOT extended. Meaningless off-device.
  //   * markTestSkipped — NOT extended. Headless suites legitimately skip on
  //     absent platform capabilities.
  //   * every-testWidgets-has-an-expect — NOT extended, reluctantly. Three
  //     headless harnesses deliberately collect across many surfaces and gate
  //     once in `tearDownAll` (see responsive_overflow_test.dart, which
  //     documents why), so the assertion is real but lives outside the test
  //     body. Extending this rule would flag three correct harnesses and teach
  //     people to annotate rather than to think.
  // ---------------------------------------------------------------------------

  test('the unit scanner sees the suites at all', () {
    // Same vacuous-pass guard as above, for the second scope.
    expect(unitSuites(), isNotEmpty,
        reason: 'Found no *_test.dart under test/ — the unit rules below would '
            'pass having checked nothing.');
  });

  test('no find.byIcon(Icons.*) in headless suites either', () {
    // This one is not device-specific at all: IconData equality compares
    // codePoint AND fontFamily AND fontPackage, so `find.byIcon(Icons.foo)`
    // against a widget tree that draws `Symbols.foo` is a permanent zero match
    // in EVERY harness. It stayed invisible for months because the rule that
    // catches it only ever scanned integration_test/.
    final hits = scan(RegExp(r'Icons\.'),
        optOut: 'e2e-icons-ok:', files: unitSuites());
    expect(
      hits,
      isEmpty,
      reason: 'The app draws Symbols.* (app_icons.dart), so these finders can '
          'never match, in any build — and a finder that matches nothing makes '
          'the assertion after it unreachable rather than failing:\n  '
          '${hits.join('\n  ')}',
    );
  });

  test('no two tests in the same group share a title', () {
    // Two same-named tests in one scope are a merge artifact, and the framework
    // runs both without complaint. focus_feature_e2e_test.dart shipped a pair
    // named 'DetailedStatsScreen builds without errors' with contradictory
    // expectations ('Focus Statistics' vs 'Detailed Statistics') — both wrong,
    // both invisible behind a skip. When one of a same-named pair fails, the
    // report names a title matching two bodies, so the failure is ambiguous to
    // read as well as ambiguous to fix.
    //
    // Keyed by GROUP + title, not title alone. The same leaf name under two
    // different groups is a good, common pattern — vitals_tombstone_test.dart
    // has `test('blood pressure')` under both 'delete hides the reading' and
    // 'Undo re-saves the same id', and those full names are distinct. A rule
    // that flagged them would be punishing correct code, which is how lints get
    // switched off.
    //
    // The group is approximated as the nearest preceding `group(` declaration
    // rather than by parsing brace scope. That is exact for the parallel-group
    // and same-group cases this rule is about; a top-level test declared after a
    // group could in principle be mis-attributed, hence the opt-out marker.
    final decl = RegExp(
        r'''\b(group|testWidgets|test)\s*\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''');
    final offenders = <String>[];
    for (final f in [...suites(), ...unitSuites()]) {
      final src = f.readAsStringSync();
      final seen = <String>{};
      final dupes = <String>{};
      var group = '<top level>';
      for (final m in decl.allMatches(src)) {
        final title = m.group(2) ?? m.group(3)!;
        if (m.group(1) == 'group') {
          group = title;
          continue;
        }
        // Generated titles (e.g. '$name fits every supported phone') are
        // distinct per iteration at run time even though the literal repeats.
        if (title.contains(r'$')) continue;
        if (src.contains('$title\', // dupe-title-ok:')) continue;
        if (!seen.add('$group $title')) dupes.add('$group > $title');
      }
      for (final d in dupes) {
        offenders.add('${rel(f)}  duplicate: "$d"');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Two tests in one group share a name. Rename one of each pair so '
          'a failure names exactly one body:\n  ${offenders.join('\n  ')}',
    );
  });
}
