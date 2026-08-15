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

  List<File> suites() => !dir.existsSync()
      ? <File>[]
      : dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
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
  List<String> scan(RegExp re, {String? optOut}) {
    final hits = <String>[];
    for (final f in suites()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = codeOf(lines[i]);
        if (!re.hasMatch(code)) continue;
        final prev = i > 0 ? lines[i - 1] : '';
        if (optOut != null &&
            (lines[i].contains(optOut) || prev.contains(optOut))) {
          continue;
        }
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
}
