import 'dart:convert';

/// Severity, using the vocabulary this repo already speaks
/// (`docs/ui-audit.md`): P0 broken · P1 clearly poor · P2 polish.
enum Sev { p0, p1, p2 }

extension SevCost on Sev {
  /// Deduction from a starting 100.
  ///
  /// The arithmetic encodes the rule rather than special-casing it: a single
  /// P0 is -40, so it caps a feature at exactly 60 = grade C no matter how
  /// clean everything else is. Two P0s put it in F. A weighted average of
  /// milliseconds, widget counts and read counts would let a P0 be diluted
  /// away by good scores elsewhere, which is precisely wrong for "broken".
  int get deduction => switch (this) { Sev.p0 => 40, Sev.p1 => 15, Sev.p2 => 5 };

  String get label => switch (this) { Sev.p0 => 'P0', Sev.p1 => 'P1', Sev.p2 => 'P2' };
}

/// One measured defect against one feature.
class Finding {
  final String feature;
  final String screen;

  /// Which dimension fired, e.g. `duplicate-reads`, `element-budget`.
  final String dimension;
  final Sev sev;

  /// The measured numbers. Every finding must carry them — the standard set in
  /// `docs/ux-review.md`: "Not a taste review."
  final String detail;

  /// Where the threshold comes from. Either a published standard (WCAG 2.2 SC
  /// 2.5.8) or, honestly, this repo's own measured baseline. Never blank: a
  /// threshold nobody can trace is an opinion wearing a number.
  final String source;

  const Finding({
    required this.feature,
    required this.screen,
    required this.dimension,
    required this.sev,
    required this.detail,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'screen': screen,
        'dimension': dimension,
        'sev': sev.label,
        'detail': detail,
        'source': source,
      };
}

/// Emits one machine-readable line per finding.
///
/// `flutter test` runs every `*_test.dart` in its OWN isolate, so a static
/// collector cannot span the harnesses. Aggregation therefore has to happen
/// outside the test process, and stdout is the only channel that crosses it.
void emitFinding(Finding f) {
  // ignore: avoid_print
  print('PERF|${jsonEncode(f.toJson())}');
}

/// Announce that [dimensions] were actually MEASURED, whatever the outcome.
///
/// ## Why a clean run has to say something
///
/// `emitFinding` only prints when something is wrong, so a dimension that found
/// nothing and a dimension that never ran produce **byte-identical output**:
/// silence. Everything downstream inherited that ambiguity. `tool/rate.dart`
/// claimed in its own header to "REFUSE to print a score when a declared
/// dimension never reported", and `rating/manifest.json` and `docs/rating.md`
/// repeated the claim — but it was never implemented, because with only `PERF|`
/// lines to read it was not implementable. Pointing all seven harness paths at
/// nonexistent files printed **100/100, grade A, 5.00/5, `manifest OK`, exit 0**
/// with zero dimensions measured.
///
/// This is the missing half of the protocol: one beacon per dimension, emitted
/// unconditionally, so "measured and clean" and "never measured" are finally
/// different bytes.
///
/// Call it from `tearDownAll` and **before** the gating `expect`s, for the same
/// reason findings are emitted first: `expect` throws, and a harness that dies
/// before reporting contributes nothing — which is precisely how a broken
/// instrument reads as a clean one.
/// [samples] is how many things were actually inspected, and it is the half that
/// makes a beacon mean anything.
///
/// A bare beacon certifies that the FILE ran, not that the dimension was
/// measured. `screen_build_cost_test.dart` proved it: run with only its `warmup`
/// test it emitted all four of its beacons, zero findings, exit 0, and printed its
/// cost table with a header and no data rows — output byte-identical to an honest
/// 29-screen run. Every gate in it passes vacuously over an empty sample, and one
/// actively hardens the empty case (`elementCounts.isEmpty ? 1`). So a harness that
/// measured nothing certified itself clean, which is the same hole the beacon was
/// added to close, one level in.
///
/// `tool/rate.dart` treats a reported count of zero as UNMEASURED. Omit [samples]
/// only where "how many" genuinely has no meaning.
void reportMeasured(Iterable<String> dimensions, {int? samples}) {
  for (final d in dimensions) {
    // ignore: avoid_print
    print(samples == null ? 'DIM|$d' : 'DIM|$d|$samples');
  }
}

/// Grade bands. `≤` is meaningful — see [scoreOf].
String gradeFor(int score) {
  if (score >= 90) return 'A';
  if (score >= 75) return 'B';
  if (score >= 60) return 'C';
  if (score >= 40) return 'D';
  return 'F';
}

/// 100 minus every deduction, floored at 0.
int scoreOf(Iterable<Finding> findings) {
  final total = findings.fold<int>(0, (a, f) => a + f.sev.deduction);
  return total >= 100 ? 0 : 100 - total;
}

/// Renders the gate table, in the shape `docs/ux-review.md` already uses.
///
/// [deviceMeasured] must be false whenever the on-device frame-timing half has
/// not run. Device dimensions can only ever ADD deductions, so a headless-only
/// number is a strict upper bound and is printed as `≤ B`, never `B`. Never
/// impute a device number from host wall-clock — the build-cost harness
/// disclaims that it can represent device raster time, and it is right to.
String renderRatingTable(
  List<Finding> findings, {
  required bool deviceMeasured,
}) {
  final byFeature = <String, List<Finding>>{};
  for (final f in findings) {
    byFeature.putIfAbsent(f.feature, () => []).add(f);
  }

  final b = StringBuffer()
    ..writeln('\n===== PER-FEATURE PERFORMANCE RATING =====')
    ..writeln(deviceMeasured
        ? 'coverage: headless + device frame timing'
        : 'coverage: HEADLESS ONLY — frame build/raster time not measured.\n'
            'Scores are UPPER BOUNDS. Device dimensions can only lower them.')
    ..writeln('')
    ..writeln('${'feature'.padRight(14)}${'score'.padLeft(6)}'
        '${'grade'.padLeft(7)}   findings');

  final names = byFeature.keys.toList()..sort();
  for (final name in names) {
    final fs = byFeature[name]!;
    final score = scoreOf(fs);
    final grade = deviceMeasured ? gradeFor(score) : '≤ ${gradeFor(score)}';
    final counts = <String, int>{};
    for (final f in fs) {
      counts[f.sev.label] = (counts[f.sev.label] ?? 0) + 1;
    }
    final summary =
        (counts.entries.toList()..sort((x, y) => x.key.compareTo(y.key)))
            .map((e) => '${e.value}x${e.key}')
            .join(' ');
    b.writeln('${name.padRight(14)}${score.toString().padLeft(6)}'
        '${grade.padLeft(7)}   $summary');
  }

  b.writeln('');
  for (final name in names) {
    for (final f in byFeature[name]!) {
      b.writeln('  [${f.sev.label}] $name/${f.screen} · ${f.dimension}');
      b.writeln('        ${f.detail}');
      b.writeln('        source: ${f.source}');
    }
  }
  b.writeln('==========================================\n');
  return b.toString();
}
