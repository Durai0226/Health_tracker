/// The chart-mark palette, gated in Dart instead of remembered.
///
/// These are the same three checks the dataviz validator runs — OKLab lightness
/// band, OKLab chroma floor, WCAG contrast against the real card surface —
/// reimplemented here so they run on every `flutter test` instead of living in a
/// shell command somebody has to remember. The validator numbers are pinned as
/// test vectors below, so this file is checked against it rather than trusted.
///
/// What it caught when written: the charts were drawing marks with
/// `AppColorsExt.mark()`, which is `strong` on light and `base` on dark. Measured:
///
///   light  brand  #00695C  chroma 0.084  — reads GRAY as a mark
///   light  water  #0E7490  chroma 0.094  — reads GRAY as a mark
///   dark   all seven feature accents at L 0.68–0.80, band is 0.48–0.67
///   dark   brand  #4DB6AC  chroma 0.098  — reads GRAY as a mark
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';
import 'package:tablet_remainder/core/design/app_palette.dart';

// ---------------------------------------------------------------- colour math

double _srgbToLinear(int v) {
  final c = v / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// (L, chroma) in OKLab / OKLCh.
({double l, double c}) _oklch(Color color) {
  final r = _srgbToLinear((color.r * 255).round());
  final g = _srgbToLinear((color.g * 255).round());
  final b = _srgbToLinear((color.b * 255).round());

  final lp = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final mp = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final sp = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

  double cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
  final l_ = cbrt(lp), m_ = cbrt(mp), s_ = cbrt(sp);

  final l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
  final a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
  final bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;

  return (l: l, c: math.sqrt(a * a + bb * bb));
}

double _relLum(Color color) =>
    0.2126 * _srgbToLinear((color.r * 255).round()) +
    0.7152 * _srgbToLinear((color.g * 255).round()) +
    0.0722 * _srgbToLinear((color.b * 255).round());

double _contrast(Color a, Color b) {
  final la = _relLum(a), lb = _relLum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// -------------------------------------------------------------- the contract

/// Light plot surfaces are white cards; dark plot surfaces are `#171B22`.
const _lightSurface = AppPalette.surfaceL;
const _darkSurface = AppPalette.surfaceD;

// Bands from the dataviz method. Dark is narrower because a dark plot surface
// gives a mark less room in both directions.
const _lightBand = (lo: 0.43, hi: 0.77);
const _darkBand = (lo: 0.48, hi: 0.67);
const _chromaFloor = 0.1;
const _contrastFloor = 3.0;

String _hex(Color c) =>
    '#${((c.a * 255).round() << 24 | (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

void main() {
  // ------------------------------------------------------------ test vectors

  group('the colour math agrees with the validator', () {
    // If these drift, every assertion below is measuring the wrong thing. The
    // expected values are the validator's own output, quoted.
    test('OKLCh matches the validator on known slots', () {
      final brandLight = _oklch(const Color(0xFF00695C));
      expect(brandLight.c, closeTo(0.084, 0.002),
          reason: 'validator reported chroma 0.084 for #00695C');

      final brandDark = _oklch(const Color(0xFF4DB6AC));
      expect(brandDark.l, closeTo(0.712, 0.003),
          reason: 'validator reported L 0.712 for #4DB6AC');
      expect(brandDark.c, closeTo(0.098, 0.002),
          reason: 'validator reported chroma 0.098 for #4DB6AC');

      final waterLight = _oklch(const Color(0xFF0E7490));
      expect(waterLight.c, closeTo(0.094, 0.002));

      final stepsDark = _oklch(const Color(0xFF4ADE80));
      expect(stepsDark.l, closeTo(0.800, 0.003));
    });
  });

  // -------------------------------------------------------------- the gate

  /// Every accent whose `chart` role is actually used to draw a series.
  ///
  /// Status swatches are excluded on purpose: `success` is used for the healthy
  /// BAND behind a line, a low-opacity fill rather than a mark, and re-tinting
  /// good/bad to satisfy a plot band would be a semantic change.
  List<(String, AccentSwatch)> features(AppColorsExt ext) => [
        ('brand', ext.brand),
        ('medicine', ext.medicine),
        ('water', ext.water),
        ('focus', ext.focus),
        ('reminders', ext.reminders),
        ('period', ext.period),
        ('steps', ext.steps),
        ('sleep', ext.sleep),
      ];

  for (final (mode, ext, surface, band) in [
    ('light', AppColorsExt.light, _lightSurface, _lightBand),
    ('dark', AppColorsExt.dark, _darkSurface, _darkBand),
  ]) {
    group('$mode chart marks', () {
      test('sit inside the lightness band', () {
        final bad = <String>[];
        for (final (name, s) in features(ext)) {
          final l = _oklch(s.chart).l;
          if (l < band.lo || l > band.hi) {
            bad.add('$name ${_hex(s.chart)} L=${l.toStringAsFixed(3)}');
          }
        }
        expect(bad, isEmpty,
            reason: 'outside L ${band.lo}–${band.hi} on $mode: $bad');
      });

      test('clear the chroma floor — none of them reads gray', () {
        final bad = <String>[];
        for (final (name, s) in features(ext)) {
          final c = _oklch(s.chart).c;
          if (c < _chromaFloor) {
            bad.add('$name ${_hex(s.chart)} C=${c.toStringAsFixed(3)}');
          }
        }
        expect(bad, isEmpty, reason: 'below chroma $_chromaFloor on $mode: $bad');
      });

      test('reach 3:1 against the card surface', () {
        final bad = <String>[];
        for (final (name, s) in features(ext)) {
          final r = _contrast(s.chart, surface);
          if (r < _contrastFloor) {
            bad.add('$name ${_hex(s.chart)} ${r.toStringAsFixed(2)}:1');
          }
        }
        expect(bad, isEmpty,
            reason: 'below $_contrastFloor:1 vs ${_hex(surface)}: $bad');
      });
    });
  }

  // --------------------------------------------------- what mark() cannot do

  group('this is why chartMark exists', () {
    // Not a tautology check — these assertions FAIL if someone "simplifies"
    // chartMark back into mark(), because they pin the specific measured
    // reasons that swap is wrong.
    test('mark() would put dark marks outside the band', () {
      final ext = AppColorsExt.dark;
      final offenders = <String>[];
      for (final (name, s) in features(ext)) {
        final l = _oklch(ext.mark(s)).l;
        if (l < _darkBand.lo || l > _darkBand.hi) offenders.add(name);
      }
      expect(offenders.length, greaterThanOrEqualTo(7),
          reason: 'the whole reason a separate dark chart set exists is that '
              'mark() fails the band for essentially every feature. If this '
              'ever stops being true, the accents themselves changed and this '
              'palette should be re-derived. Offenders: $offenders');
    });

    test('mark() would put light brand and water below the chroma floor', () {
      final ext = AppColorsExt.light;
      expect(_oklch(ext.mark(ext.brand)).c, lessThan(_chromaFloor));
      expect(_oklch(ext.mark(ext.water)).c, lessThan(_chromaFloor));
      // …and the fixed values do not.
      expect(_oklch(ext.brand.chart).c, greaterThanOrEqualTo(_chromaFloor));
      expect(_oklch(ext.water.chart).c, greaterThanOrEqualTo(_chromaFloor));
    });

    test('chart is a distinct role, not an alias', () {
      // If every chart value equalled mark(), the role would be dead weight and
      // the next person would delete it.
      final light = AppColorsExt.light;
      final dark = AppColorsExt.dark;
      final differs = [
        ...features(light).where((e) => e.$2.chart != light.mark(e.$2)),
        ...features(dark).where((e) => e.$2.chart != dark.mark(e.$2)),
      ];
      expect(differs, isNotEmpty);
    });
  });

  // ------------------------------------------------------------ the warning

  test('the indigo family is NOT separable — documented, not fixed', () {
    // medicine, focus and sleep are all indigo-violet, app-wide identity
    // colours this palette has no business redefining. In small-multiple cards
    // that costs nothing: each card has its own icon and title, so colour is
    // never the identity channel.
    //
    // But it means the palette is invalid for a chart that puts two features in
    // ONE plot. This test states the fact so the next person meets it as a
    // measurement rather than discovering it in a screenshot.
    double deltaE(Color a, Color b) {
      final x = _oklch(a), y = _oklch(b);
      // Rough OKLab ΔE on the L/C plane — enough to show these are the same
      // colour to a reader, which is the only claim being made.
      return math.sqrt(math.pow((x.l - y.l) * 100, 2) +
              math.pow((x.c - y.c) * 100, 2))
          .toDouble();
    }

    final ext = AppColorsExt.dark;
    expect(deltaE(ext.medicine.chart, ext.focus.chart), lessThan(8.0),
        reason: 'if this ever exceeds 8 the families diverged and the warning '
            'in app_palette.dart should be revisited');
    expect(deltaE(ext.medicine.chart, ext.sleep.chart), lessThan(8.0));
  });
}
