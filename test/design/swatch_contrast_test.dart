/// Every accent swatch's FILL PAIR must clear AA, in both themes.
///
/// `ext.fillBg(s)` / `ext.fillFg(s)` are documented as "AA-safe" and are used
/// for filled controls all over the app, so a swatch whose pair does not
/// actually clear 4.5:1 makes every consumer wrong at once and looks correct in
/// review — the caller is using the right token.
///
/// That is exactly what happened to `success`: its DARK swatch borrowed
/// `onSuccessContainer` (a container colour, not a fill foreground), giving
/// #065F46 on #34D399 = 4.00:1. Every `fillFg(success)` label in dark mode
/// failed AA, including the "Goal reached" readout on the water hero gauge —
/// which a conformance pass had just reported as fixed. Every other swatch has
/// a dedicated near-black `on…Dark`; success was the outlier.
///
/// A per-swatch loop rather than a spot check, because the next swatch added
/// will have the same trap available to it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';

double _lin(int channel) {
  final v = channel / 255.0;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _lin(c.red) + 0.7152 * _lin(c.green) + 0.0722 * _lin(c.blue);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(Color c) =>
    '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

void main() {
  /// Named so a failure says WHICH swatch, not just "expected >= 4.5".
  Map<String, AccentSwatch> swatchesOf(AppColorsExt e) => {
        'brand': e.brand,
        'medicine': e.medicine,
        'water': e.water,
        'focus': e.focus,
        'reminders': e.reminders,
        'period': e.period,
        'steps': e.steps,
        'sleep': e.sleep,
        'success': e.success,
        'warning': e.warning,
        'error': e.error,
        'info': e.info,
      };

  for (final entry in {'light': AppColorsExt.light, 'dark': AppColorsExt.dark}
      .entries) {
    final themeName = entry.key;
    final ext = entry.value;

    group('$themeName theme fill pairs', () {
      swatchesOf(ext).forEach((name, swatch) {
        test('$name clears AA for small text', () {
          final bg = ext.fillBg(swatch);
          final fg = ext.fillFg(swatch);
          final ratio = contrast(bg, fg);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '$themeName $name: ${_hex(fg)} on ${_hex(bg)} is '
                  '${ratio.toStringAsFixed(2)}:1. fillBg/fillFg are documented '
                  'AA-safe and are used for filled controls app-wide, so this '
                  'is wrong for every caller at once.');
        });
      });
    });
  }

  test('the success regression specifically: dark success is not 4.00:1', () {
    // Pinned by value as well as by rule, because this one shipped: the dark
    // swatch borrowed onSuccessContainer instead of a dedicated dark
    // foreground, and 4.00:1 is close enough to the 4.5 floor to look fine.
    final ratio =
        contrast(AppColorsExt.dark.fillBg(AppColorsExt.dark.success),
            AppColorsExt.dark.fillFg(AppColorsExt.dark.success));
    expect(ratio, greaterThan(4.5));
    expect(ratio, greaterThan(7.0),
        reason: 'the near-black foreground the other green (steps) uses gives '
            '7.75:1 — anything much lower means the borrow is back');
  });
}
