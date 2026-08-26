import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import 'app_card.dart';
import 'app_switch.dart';

/// iOS grouped-list container: a quiet neutral caption + a rounded [AppCard] of
/// rows with auto-inserted inset dividers + an optional gray footer caption.
///
/// The inter-group gap (~[AppSpacing.xl]) is supplied by the caller between
/// consecutive sections — this widget owns only the caption / card / footer.
class SettingsSection extends StatelessWidget {
  /// Neutral (textSecondary) caption above the card.
  final String? title;

  /// Gray (textTertiary) explanatory caption under the card.
  final String? footer;

  final List<Widget> children;

  const SettingsSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    // Interleave hairline inset dividers between rows (never leading/trailing).
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: 1,
          // Was a hardcoded 58, derived from a 32pt icon chip this row no
          // longer has. `AppListGroup` derived 62 from the same anatomy, so
          // `health_privacy_screen.dart` — which puts AppListTiles inside
          // SettingsSections — drew eight rules 4pt left of the text they
          // align to. One source now, so they cannot disagree again.
          indent: AppRowMetrics.textInset,
          endIndent: AppRowMetrics.horizontalPadding,
          color: ext.outline,
        ));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              title!,
              style: tt.labelLarge
                  ?.copyWith(color: ext.textSecondary, letterSpacing: 0.4),
            ),
          ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.sm, left: AppSpacing.xs, right: AppSpacing.xs),
            child: Text(
              footer!,
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ),
      ],
    );
  }
}

/// One cohesive settings row. Exactly one trailing mode is used:
///   - [switchValue] set  -> trailing [AppSwitch] (teal); whole row toggles it.
///   - [value] set        -> right-aligned value text + chevron (nav / picker).
///   - [onTap] only       -> action row with a plain chevron.
///
/// The leading glyph uses ONE neutral treatment on every row — a 32px
/// [AppColorsExt.surfaceVariant] tile with a [AppColorsExt.textSecondary]
/// glyph — so callers cannot reintroduce a per-row color zoo. [accent] tints
/// the switch only; the tile always stays neutral.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AccentSwatch? accent;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.switchValue,
    this.onSwitchChanged,
    this.value,
    this.trailing,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    Widget? trailingWidget;
    VoidCallback? effectiveOnTap = onTap;

    if (trailing != null) {
      trailingWidget = trailing;
    } else if (switchValue != null) {
      trailingWidget = AppSwitch(
        value: switchValue!,
        onChanged: onSwitchChanged,
        accent: accent,
      );
      // Whole-row tap toggles the switch (unless disabled).
      effectiveOnTap = onSwitchChanged == null
          ? null
          : () => onSwitchChanged!(!switchValue!);
    } else if (value != null) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible + ellipsis: at accessibility text sizes an unconstrained
          // value took whatever width it wanted and squeezed the title column
          // down to one character per line.
          // `maxLines: 2` here was a mistake: in a starved slot Flutter broke
          // the value mid-word ("Medicin" / "e time") on every row, which reads
          // as a rendering fault. A trailing value must stay on ONE line and
          // shrink to fit — scaleDown never enlarges, so rows with room look
          // exactly as before.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value!,
                style: tt.bodyLarge?.copyWith(color: ext.textSecondary),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.end,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Symbols.chevron_right_rounded,
              size: AppRowMetrics.chevronSize, color: ext.textTertiary),
        ],
      );
    } else if (onTap != null) {
      trailingWidget = Icon(Symbols.chevron_right_rounded,
          size: AppRowMetrics.chevronSize, color: ext.textTertiary);
    }

    // A switch row is TWO tap targets: this `InkWell`, which a screen reader
    // names from the title text inside it, and the `AppSwitch`, which has no text
    // of its own and so is announced as a bare "switch, on" — the user is told a
    // control exists and not what it governs. Merging makes the row one node,
    // announced as title + subtitle + state, which is both the WCAG 2.2 SC 4.1.2
    // requirement and simply how a settings row should read.
    //
    // Scoped to the switch case on purpose: a custom `trailing` may hold its own
    // interactive widget, and merging would swallow it.
    Widget tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effectiveOnTap,
        child: ConstrainedBox(
          // A floor, never a fixed height: the title may take a second line at
          // large type and the row has to be free to grow with it.
          constraints: const BoxConstraints(minHeight: AppRowMetrics.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppRowMetrics.horizontalPadding,
                vertical: AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  // Uniform neutral chip — the fix for the per-row rainbow.
                  // 36 rather than 32, matching AppListTile, so one divider
                  // inset serves both.
                  Container(
                    width: AppRowMetrics.iconBox,
                    height: AppRowMetrics.iconBox,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ext.surfaceVariant,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Icon(icon,
                        size: AppRowMetrics.glyphSize,
                        color: ext.textSecondary),
                  ),
                  const SizedBox(width: AppRowMetrics.iconGap),
                  // Plain `Expanded`, and the trailing OUTSIDE the flex.
                  //
                  // This was `Expanded(flex: 3)` against `Flexible(flex: 2)`:
                  // a tight 60% for the text and a loose 40% for the trailing,
                  // so whatever the trailing did not use was never handed back.
                  // At 393pt that reserved 108.4pt beside a 60pt switch and
                  // left 48.4pt of every row blank while the title wrapped in
                  // 162.6. The title column measured 118.8pt at 320.
                  //
                  // Now the trailing takes its intrinsic width and the text
                  // takes the rest: 172pt at 320 for a chevron row, 134 for a
                  // switch row.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Two lines, then ellipsis. Android's settings guidance:
                        // "If titles are long, they can continue on the next
                        // line instead of being truncated."
                        Text(
                          title,
                          style: tt.titleLarge?.copyWith(color: ext.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          // ONE line. Same guidance: "The subtext should be
                          // only one line. Additional text gets truncated with
                          // an ellipsis." The subtitle is a status, and a
                          // status that needs four lines is not a status.
                          Text(
                            subtitle!,
                            style: tt.bodyMedium
                                ?.copyWith(color: ext.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: AppRowMetrics.trailingGap),
                    // Capped, so an intrinsically wide custom `trailing` cannot
                    // do to this row what it does to AppListTile, where an
                    // unconstrained trailing collapsed the title column to
                    // 0.0pt and threw a 188px overflow.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: math.max(AppRowMetrics.trailingFloor,
                              c.maxWidth * AppRowMetrics.trailingShare)),
                      // A cap alone is not enough: a trailing that CANNOT
                      // shrink — `settings_screen.dart`'s "Haptix" row is a
                      // Row holding a switch AND a label — overflows the
                      // ConstrainedBox instead of fitting it (+12px at 428pt in
                      // the sweep). `scaleDown` never enlarges, so every row
                      // with room renders byte-identically and only an
                      // over-stuffed trailing is touched.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: trailingWidget,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (switchValue != null) tile = MergeSemantics(child: tile);
    return tile;
  }
}
