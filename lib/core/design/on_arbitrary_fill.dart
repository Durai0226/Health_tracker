import 'dart:math' as math;
import 'dart:ui';

/// Foreground for text or a glyph drawn on an ARBITRARY fill.
///
/// For anything token-based use `AppColorsExt.fillFg(swatch)` — those pairs are
/// AA-verified. This is for the handful of places where the fill is a value the
/// user picked (a medicine colour, a custom cup) and no token can be resolved
/// ahead of time.
///
/// ## Why this file exists
///
/// Two copies of this helper judged brightness with the **YIQ/NTSC** formula —
/// `(0.299R + 0.587G + 0.114B) / 255` on gamma-encoded bytes — and returned
/// white below 0.5. YIQ is a 1950s luma approximation for analogue television;
/// WCAG contrast is defined on *relative luminance*, which linearises each
/// channel first and weights green far more heavily. They disagree, and on
/// this app's own medicine palette they disagreed on five of nineteen colours:
///
/// | pill      | YIQ chose | with white | with black |
/// |-----------|-----------|-----------:|-----------:|
/// | Blue      | white     |     3.12:1 |     6.72:1 |
/// | Red       | white     |     3.68:1 |     5.70:1 |
/// | Teal      | white     |     3.67:1 |     5.72:1 |
/// | Pink      | white     |     4.35:1 |     4.83:1 |
/// | Blue-grey | white     |     4.37:1 |     4.80:1 |
///
/// Every one of those is a legible imprint rendered illegibly by a helper whose
/// entire job was legibility.
///
/// Rather than pick a threshold, this measures BOTH candidates and returns the
/// better one, so the result is the best available by construction. The same
/// approach as `AquaTheme.onBeverage`.
Color onArbitraryFill(Color fill) =>
    contrastRatio(fill, _white) >= contrastRatio(fill, _nearBlack)
        ? _white
        : _nearBlack;

/// The WCAG 2.1 contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a), lb = _relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const Color _white = Color(0xFFFFFFFF);

/// PURE black, and the "negligible" softening it replaced was not negligible.
///
/// A first version used `#111111` on the reasoning that a hairline of lift
/// reads as part of the object rather than a hole punched in it. Measured, that
/// cost ~0.5:1 — enough to flip two of the nineteen medicine colours to the
/// wrong side of the AA line and, worse, to make them fail with EITHER
/// foreground: Pink is 4.35:1 on white and 4.34:1 on `#111111`, and Blue-grey
/// 4.37 / 4.32. Against pure black the same two clear at 4.83 and 4.80.
///
/// A pill imprint that cannot be read is not a styling preference.
const Color _nearBlack = Color(0xFF000000);

double _channel(int v) {
  final c = v / 255.0;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color c) =>
    0.2126 * _channel(c.red) +
    0.7152 * _channel(c.green) +
    0.0722 * _channel(c.blue);
