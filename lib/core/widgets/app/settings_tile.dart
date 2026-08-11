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
          indent: 58, // aligns to the label past the 32 tile + 12 pad + 14 gap
          endIndent: 12,
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
          Icon(Symbols.chevron_right_rounded, size: 22, color: ext.textTertiary),
        ],
      );
    } else if (onTap != null) {
      trailingWidget =
          Icon(Symbols.chevron_right_rounded, size: 22, color: ext.textTertiary);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effectiveOnTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Uniform neutral tile — the fix for the per-row rainbow.
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ext.surfaceVariant,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, size: 18, color: ext.textSecondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: tt.bodyMedium
                              ?.copyWith(color: ext.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 12),
                Flexible(flex: 2, child: trailingWidget),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
