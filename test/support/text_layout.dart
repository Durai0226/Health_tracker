import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Measures how many lines a `Text` **actually rendered**.
///
/// This exists because the responsive harness could not see the bug it was
/// built to catch. `responsive_overflow_test.dart` matches `RenderFlex`/
/// `RenderBox` overflow exceptions, but a `Text` with no `maxLines` that
/// soft-wraps to three lines in a starved column is, to Flutter, a completely
/// legal layout. Nothing throws. So a header that looked broken on a real phone
/// passed 564 automated device/text-scale combinations.
///
/// Two obvious approaches do NOT work here:
///
///  * `RenderParagraph.didExceedMaxLines` only reports against an explicit
///    `maxLines`. The bug was an *unclamped* `Text`, so this is always `false`
///    — it answers "did I truncate", not "did I wrap".
///  * `getBoxesForSelection` returns one box per style run, not per line, so a
///    single-line string with mixed styling counts as several.
///
/// Re-laying-out a `TextPainter` with the render object's own text, style,
/// scaler and width and reading `computeLineMetrics().length` is exact, and it
/// is what Flutter itself uses to lay the paragraph out.
int renderedLineCount(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: finder,
      matching: find.byType(RichText),
      matchRoot: true,
    ),
  );

  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textAlign: paragraph.textAlign,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    locale: paragraph.locale,
  )..layout(maxWidth: paragraph.size.width);

  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

/// Every `Text` under [scope] that rendered more lines than it declared.
///
/// Returns descriptions rather than asserting, so a sweep can collect across
/// many screens and gate once at the end.
///
/// A `Text` with `maxLines == null` is held to [defaultAllowance]. "Unbounded"
/// is not a design decision for header chrome — it is an omission, and it is
/// exactly what let the Home greeting run to three lines.
List<String> collectWrappedText(
  WidgetTester tester,
  Finder scope, {
  int defaultAllowance = 1,
}) {
  final offenders = <String>[];
  for (final element
      in find.descendant(of: scope, matching: find.byType(RichText)).evaluate()) {
    final p = element.renderObject;
    if (p is! RenderParagraph || !p.hasSize || p.size.isEmpty) continue;

    final allowed = p.maxLines ?? defaultAllowance;
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
      final raw = p.text.toPlainText();
      final s = raw.length > 44 ? '${raw.substring(0, 44)}…' : raw;
      offenders.add('"$s" rendered $actual lines (allowed $allowed) '
          'in ${p.size.width.toStringAsFixed(0)}pt');
    }
  }
  return offenders;
}

/// Asserts [finder]'s text occupies exactly one line.
///
/// Use for anything that is chrome rather than content — a greeting, a title, a
/// chip label. Failure prints the string and the width it was given, because
/// "wrapped to 3 lines" is meaningless without knowing how much room it had.
void expectSingleLine(
  WidgetTester tester,
  Finder finder, {
  required String label,
}) {
  final lines = renderedLineCount(tester, finder);
  final width = tester
      .renderObject<RenderBox>(
        find.descendant(
            of: finder, matching: find.byType(RichText), matchRoot: true),
      )
      .size
      .width;

  expect(
    lines,
    1,
    reason: '$label wrapped to $lines lines in ${width.toStringAsFixed(1)}pt. '
        'Header text must never wrap — it is chrome, not content. This is the '
        'exact failure the user screenshotted: a greeting across three lines, '
        'physically larger than the title beneath it.',
  );
}


/// Every `Text` under [scope] that was CUT OFF with an ellipsis.
///
/// Different signal from [collectWrappedText]. Wrapping is text with no
/// `maxLines` running onto extra lines; truncation is text that hit its
/// `maxLines` and got clipped — and for that case `didExceedMaxLines` IS the
/// right answer, because `maxLines` is non-null by definition.
///
/// Truncation is not always a defect: a user's own medicine name can be
/// arbitrarily long and an ellipsis is the correct handling. What is a defect
/// is a **developer-authored string** that never fits — "Ready to focus?"
/// rendering as "Ready to foc…", or "Add reminder" as "Add remi…". Those are
/// layout bugs wearing an ellipsis, and the fix is shorter copy or a wider
/// slot, never a narrower font.
///
/// Returns descriptions so a sweep can collect across screens and report once.
List<String> collectTruncatedText(WidgetTester tester, Finder scope) {
  final out = <String>[];
  for (final element
      in find.descendant(of: scope, matching: find.byType(RichText)).evaluate()) {
    final p = element.renderObject;
    if (p is! RenderParagraph || !p.hasSize || p.size.isEmpty) continue;
    if (!p.didExceedMaxLines) continue;
    final raw = p.text.toPlainText();
    out.add('"$raw" truncated at ${p.size.width.toStringAsFixed(0)}pt '
        '(maxLines ${p.maxLines})');
  }
  return out;
}
