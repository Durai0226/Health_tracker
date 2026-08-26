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

  /// Where the separator starts. Defaults to [AppRowMetrics.textInset],
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
    final indent = separatorIndent ?? AppRowMetrics.textInset;

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
                  endIndent: AppRowMetrics.horizontalPadding,
                  color: ext.outline,
                ),
              )
            : children,
      ),
    );
  }
}
