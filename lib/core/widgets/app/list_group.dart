/// A card of list rows with hairline separators between them.
///
/// Four call sites across three screens had written this by hand, byte-identical
/// down to the card padding:
///
/// ```dart
/// AppCard(
///   padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
///   child: Column(children: _withDividers(ext, tiles)),
/// )
/// ```
///
/// …plus a private `_withDividers` copied into each of the three files. They all
/// carried the same geometry bug, because they were all copies of the same
/// original.
library;

import 'package:flutter/material.dart';

import '../../design/app_design.dart';
import 'app_card.dart';

/// [AppListTile]'s real layout, as numbers instead of guesses.
///
/// The hand-written dividers used `indent: 52, endIndent: 8`. Neither number
/// matches the tile:
///
/// * **Left.** The tile pads 12, then draws a 36pt icon chip (a 20pt glyph with
///   8pt of padding on each side), then a 14pt gap — so its TEXT starts at 62.
///   A divider indented 52 begins 10pt to the left of the text it is supposed to
///   align with, which is what makes those lists read as slightly crooked.
/// * **Right.** The tile pads 12, but the divider stopped 8 short — so it
///   overshot the content by 4pt at the other end.
///
/// Deriving the inset here means a change to the tile's padding cannot silently
/// leave every divider in the app misaligned again.
class AppListTileMetrics {
  const AppListTileMetrics._();

  /// [AppListTile]'s own horizontal padding.
  static const double horizontalPadding = 12;

  /// The accent icon chip: a 20pt glyph inside 8pt of padding on each side.
  static const double iconBox = 20 + 8 * 2;

  /// Between the icon chip and the text column.
  static const double iconGap = 14;

  /// Where a tile's text column starts, and therefore where a separator
  /// between two tiles must start. 12 + 36 + 14 = 62.
  static const double textInset = horizontalPadding + iconBox + iconGap;
}

/// Interleaves [separator] between [children] — and nowhere else.
///
/// The bug this prevents is the off-by-one at the end. Every hand-rolled copy
/// got the guard right, but it is the kind of loop that gets it wrong once and
/// then leaves a stray rule under the last row of a card forever.
List<Widget> separatedBy(List<Widget> children, Widget separator) {
  if (children.length < 2) return children;
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(separator);
    out.add(children[i]);
  }
  return out;
}

class AppListGroup extends StatelessWidget {
  final List<Widget> children;

  /// Where the separator starts. Defaults to [AppListTileMetrics.textInset],
  /// which is right for a group of [AppListTile]s. Pass 0 for a group of rows
  /// that have no leading icon — a full-width rule is correct there, and an
  /// inset one would look like a mistake.
  final double? separatorIndent;

  /// Card padding. The default matches what all four original call sites used.
  final EdgeInsetsGeometry padding;

  /// Draw no separators at all — for a single-row group, or one whose rows
  /// already carry their own edges.
  final bool separated;

  const AppListGroup({
    super.key,
    required this.children,
    this.separatorIndent,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    this.separated = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final indent = separatorIndent ?? AppListTileMetrics.textInset;

    return AppCard(
      padding: padding,
      child: Column(
        children: separated
            ? separatedBy(
                children,
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: indent,
                  // Symmetric with the tile's own right padding, rather than
                  // the 8 that made the rule overshoot the content.
                  endIndent: AppListTileMetrics.horizontalPadding,
                  color: ext.outline,
                ),
              )
            : children,
      ),
    );
  }
}
