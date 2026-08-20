// One command, one number, the same number every time.
//
//   dart run tool/rate.dart
//
// ## Why this exists
//
// The rating used to be produced by ONE test file, in its own `tearDownAll`,
// over 25 of the app's ~81 screens. The responsive sweep and the touch-target
// audit could turn the build red and still leave the score at 100, because
// neither ever constructed a `Finding`. And "no device" was a hardcoded
// `false`. So the number depended on which command someone happened to type,
// and a clean run was indistinguishable from a run that measured nothing.
//
// This aggregates every harness's `PERF|` lines, validates them against
// `rating/manifest.json`, and REFUSES to print a score when a declared
// dimension never reported. `100 / 5.0` and `INVALID` are now different
// outputs, which is the entire point.
//
// Exit codes: 0 clean · 1 findings · 2 invalid (a harness did not report).
import 'dart:convert';
import 'dart:io';

const _flutter = '/Users/duraisingh/flutter/bin/flutter';

Future<void> main(List<String> args) async {
  exitCode = await _run();
}

Future<int> _run() async {
  final root = Directory.current.path;

  final manifestFile = File('$root/rating/manifest.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('rating/manifest.json is missing — it IS the contract.');
    return 2;
  }
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final dimensions = (manifest['dimensions'] as List).cast<Map<String, dynamic>>();

  // Only the harnesses that own a scored dimension. Naming them explicitly
  // (rather than running everything) is what makes "this dimension never
  // reported" a detectable state instead of a silent zero.
  const harnessPaths = <String, String>{
    'screen_build_cost': 'test/performance/screen_build_cost_test.dart',
    'responsive_overflow': 'test/responsive/responsive_overflow_test.dart',
    'touch_target_audit': 'test/responsive/touch_target_audit_test.dart',
    // Focus-specific gates. Registered here so they SCORE rather than merely
    // gate: tool/rate.dart refuses to print a number if a declared dimension
    // never reported, which is what makes "did not run" distinguishable from
    // "found nothing".
    'focus_dark_mode': 'test/features/focus/focus_dark_mode_test.dart',
    'focus_geometry': 'test/features/focus/focus_screen_geometry_test.dart',
    // The experience half. Without these the number is blind to whether the app
    // can be used without sight, used without motion, entered by a new user, or
    // whether finishing a session feels like anything at all.
    'focus_a11y': 'test/features/focus/focus_a11y_test.dart',
    'focus_first_run': 'test/features/focus/focus_first_run_test.dart',
  };

  final findings = <Map<String, dynamic>>[];

  /// Dimensions that announced themselves via a `DIM|` beacon.
  ///
  /// This is the whole reason the header's promise is now true. `emitFinding`
  /// only prints when something is WRONG, so before beacons existed a dimension
  /// that found nothing and a dimension that never ran emitted byte-identical
  /// output — silence. Every check below that claimed to catch "declared but
  /// never reported" was therefore decoration: pointing all seven harness paths
  /// at nonexistent files printed 100/100, grade A, 5.00/5, `manifest OK`,
  /// exit 0, with sixteen dimensions unmeasured.
  final measured = <String>{};

  /// dimension id -> how many things its harness actually inspected.
  ///
  /// A bare beacon certifies that the FILE ran, not that the dimension was
  /// MEASURED. `screen_build_cost` proved it: running it with only its `warmup`
  /// test produced 4 beacons, 0 findings, exit 0 and a printed cost table with
  /// zero data rows — byte-identical to an honest 29-screen run, because every
  /// gate passes vacuously on an empty sample and one of them explicitly hardens
  /// the empty case (`elementCounts.isEmpty ? 1`). A count makes the difference
  /// visible.
  final samples = <String, int>{};
  final crashed = <String, int>{};

  /// Harnesses that exited 1 without emitting a single finding.
  final redButUnpriced = <String>[];

  /// Harnesses that printed a `PERF|` line this tool could not parse.
  final malformedLines = <String, int>{};

  for (final entry in harnessPaths.entries) {
    stdout.writeln('· ${entry.key}');
    final r = await Process.run(_flutter, ['test', entry.value, '--reporter=compact'],
        workingDirectory: root);
    final out = '${r.stdout}\n${r.stderr}';

    var emitted = 0;
    var beacons = 0;
    var malformed = 0;
    for (final line in const LineSplitter().convert(out)) {
      final b = line.indexOf('DIM|');
      if (b >= 0) {
        // `DIM|<id>` or `DIM|<id>|<sampleCount>`. The count is what stops a
        // beacon from certifying merely that the FILE ran — see [samples].
        final parts = line.substring(b + 4).trim().split('|');
        final id = parts.first.trim();
        measured.add(id);
        if (parts.length > 1) {
          final n = int.tryParse(parts[1].trim());
          if (n != null) samples[id] = (samples[id] ?? 0) + n;
        }
        beacons++;
        continue;
      }
      final i = line.indexOf('PERF|');
      if (i < 0) continue;
      try {
        findings.add(jsonDecode(line.substring(i + 5)) as Map<String, dynamic>);
        emitted++;
      } catch (_) {
        // A truncated or malformed line is NOT "not a finding" — it is a finding
        // this tool failed to read, and silently dropping it lowers the score's
        // deductions while the beacon still reports the dimension as measured.
        malformed++;
      }
    }
    if (malformed > 0) {
      malformedLines[entry.key] = malformed;
    }
    // Exit codes, both halves.
    //
    // `> 1` is a flutter-tool level failure. Exit **1** is the subtle one: it is
    // what a harness returns both when it found something (its `expect`s threw)
    // AND when a gate went red that emits no finding at all — `couldNotBuild`,
    // `motionRemoved`, the `seen > 0` vacuity guards, the geometry header floor.
    // Those gate the build and are invisible to the score, so a red harness with
    // zero findings used to print as perfectly clean. Exit 1 with no findings now
    // means "something failed that this tool cannot price".
    if (r.exitCode > 1) {
      crashed[entry.key] = r.exitCode;
    } else if (r.exitCode == 1 && emitted == 0) {
      redButUnpriced.add(entry.key);
    }
    stdout.writeln('  exit ${r.exitCode}, $emitted finding(s), '
        '$beacons dimension(s) measured'
        '${malformed > 0 ? ', $malformed UNREADABLE' : ''}');
  }

  // ---- validate -------------------------------------------------------------
  final problems = <String>[];

  // THE check this tool has always claimed to make. A dimension with no beacon
  // was not measured, whatever its harness's exit code said.
  for (final d in dimensions) {
    final id = d['id'] as String;
    if (!measured.contains(id)) {
      problems.add('"$id" (harness ${d['harness']}) never reported — it is '
          'UNMEASURED, which is not the same as clean');
    }
  }
  for (final d in dimensions) {
    final id = d['id'] as String;
    if (!measured.contains(id)) continue;
    // Only checked when a harness chose to report a count. Beaconing without one
    // is still allowed for dimensions where "how many" is not meaningful.
    if (samples.containsKey(id) && samples[id]! <= 0) {
      problems.add('"$id" (harness ${d['harness']}) beaconed but inspected '
          'NOTHING — a dimension measured over an empty sample is unmeasured');
    }
  }
  for (final h in crashed.keys) {
    problems.add('$h exited ${crashed[h]} — a flutter-tool level failure, so '
        'anything it did not beacon is unmeasured');
  }
  for (final h in redButUnpriced) {
    problems.add('$h exited 1 with ZERO findings — a gate went red that this '
        'tool cannot price, so the score does not reflect it');
  }
  for (final h in malformedLines.keys) {
    problems.add('$h printed ${malformedLines[h]} unparseable PERF| line(s) — '
        'findings this tool could not read must not be dropped silently');
  }

  // Every manifest severity must be one this tool can price. Otherwise
  // `cost[...] ?? 0` prices a real defect at zero and prints "1 finding(s):"
  // with nothing under it.
  const priceable = {'P0', 'P1', 'P2'};
  for (final d in dimensions) {
    final sev = (d['sev'] as String).toUpperCase();
    if (!priceable.contains(sev)) {
      problems.add('manifest prices "${d['id']}" as "${d['sev']}", which is not '
          'one of ${priceable.join('/')} — it would be scored as zero');
    }
  }

  // Severity comes from the MANIFEST, not from the finding.
  //
  // "a harness cannot invent a severity" was asserted here and never enforced:
  // `d['sev']` was never read, so a harness emitting `Sev.p2` for a dimension the
  // manifest prices at P1 silently repriced its own defect. The manifest stores
  // severities lowercase and findings emit uppercase, so both are normalised.
  final sevOf = {
    for (final d in dimensions)
      d['id'] as String: (d['sev'] as String).toUpperCase(),
  };
  for (final f in findings) {
    final d = f['dimension'];
    if (!sevOf.containsKey(d)) {
      problems.add('finding reports dimension "$d", which the manifest does '
          'not price — a harness cannot invent a dimension');
      continue;
    }
    final declared = sevOf[d]!;
    final claimed = (f['sev'] as String?)?.toUpperCase();
    if (claimed != declared) {
      problems.add('finding on "$d" claims $claimed but the manifest prices it '
          '$declared — a harness cannot invent a severity');
    }
  }

  final deviceDims =
      dimensions.where((d) => d['device'] == true).map((d) => d['id']).toList();

  if (problems.isNotEmpty) {
    stdout.writeln('\n=========== APP QUALITY RATING ===========');
    stdout.writeln('SCORE   INVALID');
    stdout.writeln('STATUS  the measurement did not complete:');
    for (final p in problems) {
      stdout.writeln('        · $p');
    }
    stdout.writeln('\nA score is only meaningful when every declared dimension');
    stdout.writeln('reported. "Nothing found" and "nothing measured" are');
    stdout.writeln('different answers and must not print the same number.');
    stdout.writeln('==========================================');
    return 2;
  }

  // ---- score ----------------------------------------------------------------
  const cost = {'P0': 40, 'P1': 15, 'P2': 5};
  // Priced from the manifest's severity for the finding's dimension. Validation
  // above has already rejected any finding whose dimension is unknown or whose
  // claimed severity disagrees, so this cannot silently fail open the way
  // `cost[f['sev']] ?? 0` did.
  final deductions = findings.fold<int>(
      0, (a, f) => a + (cost[sevOf[f['dimension']]] ?? 0));
  final score = deductions >= 100 ? 0 : 100 - deductions;
  final grade = score >= 90
      ? 'A'
      : score >= 75
          ? 'B'
          : score >= 60
              ? 'C'
              : score >= 40
                  ? 'D'
                  : 'F';
  final outOf5 = (score / 20).toStringAsFixed(2);

  stdout.writeln('\n=========== APP QUALITY RATING ===========');
  stdout.writeln('SCORE   $score / 100      GRADE  $grade      $outOf5 / 5');
  stdout.writeln('STATUS  UPPER BOUND — ${deviceDims.length} device dimension(s) '
      'not scored by design.');
  stdout.writeln('        Frame timing is measured on device and REPORTED, not');
  stdout.writeln('        scored: an emulator GPU is the host GPU, and every');
  stdout.writeln('        scored dimension here is a count, a boolean, or a');
  stdout.writeln('        within-run ratio — so this number is reproducible.');
  stdout.writeln('COVERAGE  ${dimensions.length} dimensions · '
      '${harnessPaths.length} harnesses · manifest OK');

  if (findings.isEmpty) {
    stdout.writeln('\nNo findings on any priced dimension.');
  } else {
    stdout.writeln('\n${findings.length} finding(s):');
    // Grouped by the MANIFEST severity, not the raw `f['sev']`. Grouping by the
    // raw value while iterating the uppercase literals below meant a finding
    // priced correctly could still render as an invisible one — "1 finding(s):"
    // followed by nothing.
    final bySev = <String, List<Map<String, dynamic>>>{};
    for (final f in findings) {
      bySev.putIfAbsent(sevOf[f['dimension']] ?? '?', () => []).add(f);
    }
    for (final sev in const ['P0', 'P1', 'P2']) {
      for (final f in bySev[sev] ?? const []) {
        stdout.writeln('  [$sev] ${f['screen']} · ${f['dimension']}');
        stdout.writeln('        ${f['detail']}');
        stdout.writeln('        source: ${f['source']}');
      }
    }
  }
  stdout.writeln('\n4.5/5 requires score >= 90: zero P0, zero P1, at most two P2.');
  stdout.writeln('==========================================');

  return findings.isEmpty ? 0 : 1;
}
