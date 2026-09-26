/// Foreground choice on a user-picked fill must be measured, not guessed.
///
/// Two copies of this helper judged brightness with the YIQ/NTSC luma formula
/// — a 1950s analogue-television approximation — and returned white below 0.5.
/// WCAG contrast is defined on *relative luminance*, which linearises each
/// channel and weights green far more heavily, so the two disagree. On this
/// app's own nineteen medicine colours they disagreed on five, and every
/// disagreement went the wrong way: white at 3.12–4.37:1 where black scored
/// 4.80–6.72:1. A helper whose entire job is legibility was rendering pill
/// imprints illegibly.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/design/on_arbitrary_fill.dart';
import 'package:tablet_remainder/features/medication/theme/nunito_theme.dart';

void main() {
  test('it returns whichever candidate actually measures higher', () {
    // The property, stated directly: for ANY fill, no other choice beats it.
    for (final fill in [
      const Color(0xFF2196F3), // the worst YIQ miss
      const Color(0xFFF44336),
      const Color(0xFF009688),
      const Color(0xFFE91E63),
      const Color(0xFF607D8B),
      const Color(0xFFFFEB3B), // one YIQ got right
      const Color(0xFF000000),
      const Color(0xFFFFFFFF),
    ]) {
      final chosen = onArbitraryFill(fill);
      final other = chosen == const Color(0xFFFFFFFF)
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF);
      expect(contrastRatio(fill, chosen),
          greaterThanOrEqualTo(contrastRatio(fill, other)),
          reason: 'a helper that picks the WORSE of two options is the bug');
    }
  });

  test('negative: the five colours YIQ got wrong now pick black', () {
    // Pinned individually, because "picks the better one" would still pass if
    // the formula regressed to YIQ *and* the candidates were swapped.
    for (final entry in {
      'Blue': const Color(0xFF2196F3),
      'Red': const Color(0xFFF44336),
      'Teal': const Color(0xFF009688),
      'Pink': const Color(0xFFE91E63),
      'BlueGrey': const Color(0xFF607D8B),
    }.entries) {
      expect(onArbitraryFill(entry.value), const Color(0xFF000000),
          reason: '${entry.key}: YIQ chose white at '
              '${contrastRatio(entry.value, const Color(0xFFFFFFFF)).toStringAsFixed(2)}:1');
    }
  });

  test('every medicine colour clears AA for its imprint', () {
    // The real payload: the imprint is text on the pill, so 4.5:1.
    final failures = <String>[];
    for (var i = 0; i < NunitoTheme.pillColors.length; i++) {
      final fill = NunitoTheme.pillColors[i];
      final r = contrastRatio(fill, onArbitraryFill(fill));
      if (r < 4.5) failures.add('pill[$i] ${r.toStringAsFixed(2)}:1');
    }
    expect(failures, isEmpty,
        reason: 'a pill imprint the user cannot read is the whole defect: '
            '${failures.join(', ')}');
  });

  test('neither helper computes brightness by hand any more', () {
    // The formula, not the outcome — two copies drifted from each other once.
    for (final path in const [
      'lib/features/medication/widgets/nunito_pill_visual.dart',
      'lib/features/medication/screens/nunito_add_medication_flow.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('0.299 *'), isFalse,
          reason: '$path is computing YIQ luma again');
    }
  });
}
