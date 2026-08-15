import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the lines a paragraph ACTUALLY rendered, on the real device.
///
/// Mirrors `test/support/text_layout.dart`. The duplication is deliberate:
/// `test/` is not on the import path for `integration_test/`, and the headless
/// copy cannot answer this question anyway — it lays out in the square-em test
/// font, while the defect this catches is a function of Nunito's real advance
/// widths at the device's real width and Dynamic Type setting.
///
/// `didExceedMaxLines` is no use here: it is `maxLines != null && …`, so it is
/// false by construction for an unclamped `Text` — precisely the widget that
/// wraps. Re-laying the paragraph's own text with its own style and constraints
/// and reading `computeLineMetrics().length` is the only honest measurement.
List<String> wrappedTextUnder(Finder scope) {
  final offenders = <String>[];
  for (final element
      in find.descendant(of: scope, matching: find.byType(RichText)).evaluate()) {
    final p = element.renderObject;
    if (p is! RenderParagraph || !p.hasSize || p.size.isEmpty) continue;
    final allowed = p.maxLines ?? 1;
    final painter = TextPainter(
      text: p.text,
      textDirection: p.textDirection,
      textAlign: p.textAlign,
      textScaler: p.textScaler,
      maxLines: p.maxLines,
      strutStyle: p.strutStyle,
      textWidthBasis: p.textWidthBasis,
      locale: p.locale,
    )..layout(maxWidth: p.size.width);
    final actual = painter.computeLineMetrics().length;
    painter.dispose();
    if (actual > allowed) {
      offenders.add('"${p.text.toPlainText()}" rendered $actual lines '
          '(allowed $allowed) in ${p.size.width.toStringAsFixed(0)}pt');
    }
  }
  return offenders;
}
