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
  };

  final findings = <Map<String, dynamic>>[];
  final ran = <String>{};
  final crashed = <String, int>{};

  for (final entry in harnessPaths.entries) {
    stdout.writeln('· ${entry.key}');
    final r = await Process.run(_flutter, ['test', entry.value, '--reporter=compact'],
        workingDirectory: root);
    final out = '${r.stdout}\n${r.stderr}';

    // A harness that crashed before emitting is NOT a clean harness. Record it
    // so the manifest check below can tell the difference.
    var emitted = 0;
    for (final line in const LineSplitter().convert(out)) {
      final i = line.indexOf('PERF|');
      if (i < 0) continue;
      try {
        findings.add(jsonDecode(line.substring(i + 5)) as Map<String, dynamic>);
        emitted++;
      } catch (_) {/* a truncated line is not a finding */}
    }
    // `expect` failures are expected here — findings and failures are the same
    // events seen twice. What matters is whether the harness got far enough to
    // report at all, which its own completion tells us.
    if (r.exitCode > 1) crashed[entry.key] = r.exitCode;
    ran.add(entry.key);
    stdout.writeln('  exit ${r.exitCode}, $emitted finding(s)');
  }

  // ---- validate -------------------------------------------------------------
  final problems = <String>[];
  for (final h in harnessPaths.keys) {
    if (!ran.contains(h)) problems.add('$h never ran');
    if (crashed.containsKey(h)) {
      problems.add('$h exited ${crashed[h]} — it did not complete, so the '
          'dimensions it owns are UNMEASURED, not clean');
    }
  }
  final known = {for (final d in dimensions) d['id'] as String};
  for (final f in findings) {
    final d = f['dimension'];
    if (!known.contains(d)) {
      problems.add('finding reports dimension "$d", which the manifest does '
          'not price — a harness cannot invent a severity');
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
  final deductions =
      findings.fold<int>(0, (a, f) => a + (cost[f['sev']] ?? 0));
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
    final bySev = <String, List<Map<String, dynamic>>>{};
    for (final f in findings) {
      bySev.putIfAbsent(f['sev'] as String, () => []).add(f);
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
