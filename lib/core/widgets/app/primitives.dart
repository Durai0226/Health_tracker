import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import 'app_button.dart';
import 'app_switch.dart';

/// Flat scaffold on the token background.
///
/// ## It also owns the status-bar glyph colour
///
/// `AppBarTheme.systemOverlayStyle` used to be the only place in the app that
/// set it, and a theme only reaches screens that actually build an `AppBar` —
/// eleven of them. The other ~60 compose `AppScaffold` + `AppHeader` and
/// declared nothing, so their glyph colour was whatever the last `AppBar`
/// screen left behind, or the platform default on a cold start.
///
/// That default is white glyphs: neither `values/styles.xml` nor
/// `values-night/styles.xml` sets `windowLightStatusBar`. And the app targets
/// SDK 36, where **edge-to-edge is enforced and cannot be opted out of** — so
/// the light `background` is drawn behind the status bar rather than a dark
/// system strip sitting above it. White clock, wifi and battery on a white
/// background, on Home.
///
/// This is the same defect `AppBarTheme`'s comment records fixing on three
/// water screens; it was simply never true for the rest of the app. Declaring
/// it here means every screen states its own, from its own theme, with no
/// dependence on whether it happens to build an `AppBar`.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  /// Inset the body from display cutouts. **On by default**, and the name is a
  /// historical misnomer: it is not about the top.
  ///
  /// `AppHeader` applies its own `SafeArea`, and `SafeArea` removes what it
  /// consumes from the `MediaQuery` it passes down, so nesting is a no-op at
  /// the top. What this actually buys is the LEFT and RIGHT insets, which the
  /// body below the header does not otherwise get and which matter on a notched
  /// device in landscape.
  ///
  /// It used to default to false, and 20 of 66 screens opted in — so 46 screens
  /// had a body that ran under the cutout in landscape while their neighbours
  /// did not. An inset that is correct for a screen is correct for all of them;
  /// the only reason to pass `false` is a body that is deliberately full-bleed.
  final bool safeTop;

  /// Tapping empty space dismisses the keyboard (on by default). This is the
  /// app-wide fix so every form built on AppScaffold closes the keyboard when
  /// the user taps outside a field — a no-op when nothing is focused.
  final bool dismissKeyboardOnTap;

  const AppScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.safeTop = true,
    this.dismissKeyboardOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    Widget content = safeTop ? SafeArea(bottom: false, child: body) : body;
    if (dismissKeyboardOnTap) {
      // translucent → children (buttons, lists, fields) still receive taps;
      // only taps that land on empty space trigger the unfocus.
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: content,
      );
    }
    // Derived from the resolved tokens rather than passed in: a screen cannot
    // get this wrong, and a screen that changes its background gets the right
    // glyphs for free. `SystemUiOverlayStyle.dark` means DARK GLYPHS — it is
    // named for the content, not the background it sits on.
    final overlay = ext.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        // Both bars must be transparent under enforced edge-to-edge; setting a
        // colour is a no-op on API 35+ and a mismatched strip below that.
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        // The gesture pill sits over the app's own background too, so it needs
        // the same treatment as the status bar and for the same reason.
        systemNavigationBarIconBrightness:
            ext.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ext.background,
        extendBody: extendBody,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        body: content,
      ),
    );
  }
}

/// Accent icon-chip + title + optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AccentSwatch? accent;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(icon, size: 16, color: s.onContainer),
            ),
            const SizedBox(width: 10),
          ],
          // `header: true` inside the shared widget, not at each call site.
          //
          // A heading is what lets VoiceOver's rotor and TalkBack's
          // heading-navigation jump between sections instead of swiping through
          // every row of every list. Doing it here makes every section header in
          // the app navigable in one change; doing it per call site guarantees
          // that most of them never get it.
          //
          // The Text stays inside the Semantics rather than the other way
          // round, so the header node carries the title as its label and the
          // action button beside it remains a separate, operable node.
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: tt.headlineMedium),
            ),
          ),
          if (actionLabel != null && onAction != null)
            // Flexible, because this button is INFLEXIBLE and grows with
            // Dynamic Type. The title beside it is Expanded so it yields, but a
            // Row only overflows on its non-flex children: at 2.0x on a 320pt
            // phone the icon (28) + gap (10) + a scaled-up action label ran the
            // header 10px over. Flexible lets the label ellipsize instead;
            // `fit: loose` keeps it at its natural width whenever there is room,
            // so nothing changes at ordinary text sizes.
            Flexible(
              child: TextButton(
              onPressed: onAction,
              // Explicit 44pt floor. The app theme trims TextButton's tap
              // target, so every section action ("Customize", "Edit", "See
              // all"...) rendered 40pt tall — under Apple's comfort minimum, on
              // a control that sits at the top-right of a scrolling list where
              // a missed tap is most annoying. Shared widget, so this is one
              // change for every section header in the app.
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Text(actionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(color: ext.mark(s))),
            ),
            ),
        ],
      ),
    );
  }
}

/// Small pill — filter/status/selectable chip.
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final AccentSwatch? accent;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    // Premium chip: a defined bordered pill (not a flat grey fill). At rest the
    // glyph carries a spot of the feature accent so the chip reads coloured and
    // tactile; selected fills with the accent container + an accent ring.
    final bg = selected ? s.container : ext.surface;
    final fgText = selected ? s.onContainer : ext.textPrimary;
    final fgIcon = selected ? s.onContainer : ext.mark(s);
    final borderColor = selected ? ext.mark(s) : ext.outline;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brFull,
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Actionable chips get a >=44px hit target (Apple/Material floor) while
        // the pill stays visually compact and HUGS its content. NB: no
        // `alignment:` here — a Container with alignment expands to fill bounded
        // width, which would stretch chips full-width inside a Wrap/stretch
        // column. The minHeight + the Row's default vertical centering are
        // enough to size and centre the pill.
        child: Container(
          constraints:
              BoxConstraints(minHeight: onTap != null ? 44 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fgIcon),
                const SizedBox(width: 7),
              ],
              // Flexible + ellipsis so a chip in a bounded Row degrades
              // gracefully at large text sizes instead of overflowing — the
              // focus "0 coins" chip used to clip mid-word to "0 coi".
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                        color: fgText,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Count pill (nav badges, "3 today").
class CountBadge extends StatelessWidget {
  final int count;
  final AccentSwatch? accent;
  const CountBadge({super.key, required this.count, this.accent});

  @override
  Widget build(BuildContext context) {
    final s = accent ?? AccentScope.swatchOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: s.container, borderRadius: AppRadius.brFull),
      child: Text(
        '$count',
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: s.onContainer, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Calm empty state — icon + title + optional message/action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final AccentSwatch? accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    // FittedBox(scaleDown), not a bare Center.
    //
    // A 72pt medallion plus a headline and a message that both wrap does not
    // fit a 320pt phone at 2.0x Dynamic Type — steps_history overflowed by
    // 184px there, and by 24px at 360pt, clipping the very sentence that tells
    // the user what to do next.
    //
    // scaleDown NEVER enlarges, so at ordinary text sizes this renders exactly
    // as before; only the cases that would clip are shrunk. Same idiom as
    // StepActivityRing, which had the identical problem.
    //
    // A SingleChildScrollView would be better a11y — the user keeps their full
    // chosen text size and scrolls — and it was tried first. It introduces a
    // Viewport, and EmptyState appears on ~30 screens: three focus suites crash
    // traversing an unlaid-out viewport ("Null check operator used on a null
    // value" in _ViewportElement.debugVisitOnstageChildren), and screens that
    // place an EmptyState in an unbounded-height parent threw "BoxConstraints
    // forces an infinite height". Shrinking to ~0.75 at the worst case (2.0x on
    // a 320pt phone, i.e. still an effective 1.5x) beats clipping, and beats
    // destabilising every empty state in the app.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                      children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: s.container, shape: BoxShape.circle),
                    child: Icon(icon, size: 34, color: s.onContainer),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(title, style: tt.headlineSmall, textAlign: TextAlign.center),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(message!,
                        style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                        textAlign: TextAlign.center),
                  ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
      ),
    );
  }
}

/// Settings/action row: accent icon chip + title + subtitle + trailing.
///
/// For a SWITCH row use [switchValue] / [onSwitchChanged] rather than putting an
/// [AppSwitch] in [trailing]. Four rows did the latter — `settings_screen`'s
/// "Cloud sync", both of `sleep_schedule_settings_screen`'s, and
/// `steps_goal_settings_screen`'s "Daily step reminder" — and all four broke the
/// same two rules:
///
///  * **Tapping the row did nothing.** 23 `SettingsTile` switch rows toggle on
///    row-tap and it is the documented house rule; counting the hand-rolled
///    copies, 28 rendered rows did not, so the rule was the minority behaviour.
///  * **A screen reader announced a bare "switch, on"** with no idea what it
///    governs, because the row and the control were two separate nodes.
///
/// Two sites keep `trailing: AppSwitch(...)` deliberately —
/// `connected_devices_screen` and `app_allow_list_screen` — and their comments
/// say why: merging the row into one node breaks screen-reader navigation there.
/// This is additive, so those are untouched.
class AppListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AccentSwatch? accent;
  final Color? iconColor;
  final Color? titleColor;

  /// A switch row. The widget builds the [AppSwitch], wires the row tap to it
  /// and merges the semantics.
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  const AppListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.accent,
    this.iconColor,
    this.titleColor,
    this.switchValue,
    this.onSwitchChanged,
  }) : assert(switchValue == null || trailing == null,
            'a switch row cannot also supply its own trailing'),
        assert(switchValue == null || onTap == null,
            'a row is either navigational or a toggle, never both — one InkWell '
            'spans the whole row, so a miss-tap does the other thing');

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    final ic = iconColor ?? s.onContainer;

    final isSwitch = switchValue != null;
    final Widget? switchWidget = isSwitch
        ? AppSwitch(
            value: switchValue!, onChanged: onSwitchChanged, accent: accent)
        : null;
    // Row-tap toggles, which is the house rule and was the minority behaviour.
    final VoidCallback? effectiveOnTap = isSwitch
        ? (onSwitchChanged == null
            ? null
            : () => onSwitchChanged!(!switchValue!))
        : onTap;

    // No chevron without an `onTap`.
    //
    // This was `trailing ?? Icon(chevron)`, ungated — so 14 call sites that
    // pass neither rendered an arrow that does nothing. Twelve of them are on
    // `health_privacy_screen`, the Play-required health disclosure screen,
    // where every row invites a tap it will not answer.
    //
    // It also retires the `trailing: SizedBox.shrink()` workaround, which four
    // sites used to suppress the arrow and which rendered 14 rows carrying an
    // invisible widget purely to defeat a default.
    final Widget? effectiveTrailing = switchWidget ??
        trailing ??
        (onTap != null
            ? Icon(Symbols.chevron_right_rounded,
                size: AppRowMetrics.chevronSize, color: ext.textTertiary)
            : null);
    Widget row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: AppRadius.brMd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppRowMetrics.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppRowMetrics.horizontalPadding,
                vertical: AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (iconColor ?? s.base).withOpacity(0.12),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Icon(icon, size: AppRowMetrics.glyphSize, color: ic),
                  ),
                  const SizedBox(width: AppRowMetrics.iconGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: tt.titleLarge
                              ?.copyWith(color: titleColor ?? ext.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: tt.bodyMedium
                                ?.copyWith(color: ext.textSecondary),
                            // Two lines, matching the title above it.
                            //
                            // At one line this cut real copy on a 411dp phone
                            // at DEFAULT text size — found on device, not in
                            // the harness: "General reference for common
                            // condit…". 27 subtitles in lib/ are long enough to
                            // cut, and the two that matter most explain
                            // irreversible actions — "Erase your account and
                            // all cloud copies, including backups" lost the
                            // word "backups", and "Permanently erase everything
                            // on this device" was also over.
                            //
                            // The row only grows when the text actually needs
                            // the second line, so short subtitles are unchanged.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (effectiveTrailing != null) ...[
                    // Gap and cap, neither of which this row had. With the
                    // trailing unconstrained and non-flex, a long
                    // `trailing: Text(...)` took its full intrinsic width
                    // first: at 360pt the title column measured 0.0 and the
                    // row threw `A RenderFlex overflowed by 188 pixels`.
                    const SizedBox(width: AppRowMetrics.trailingGap),
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
                        child: effectiveTrailing,
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
    // One node, announced as title + subtitle + state. WCAG 2.2 SC 4.1.2, and
    // simply how a settings row should read — the same treatment SettingsTile
    // applies, scoped the same way (never over a custom `trailing`, which may
    // hold its own interactive widget).
    if (isSwitch) row = MergeSemantics(child: row);
    return row;
  }
}

/// Themed text input — the single form primitive for every feature.
///
/// Wraps [TextFormField] with Calm Clarity styling: a filled
/// [AppColorsExt.surfaceVariant] background, a subtle unfocused outline that
/// animates to the [accent] mark on focus, and dark-mode-correct label / hint /
/// error typography. Pass [maxLines] > 1 (or null) for a multiline note field.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;

  /// Focus-border / label accent. Defaults to the shell brand swatch.
  final AccentSwatch? accent;

  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;
  final AutovalidateMode? autovalidateMode;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.accent,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? ext.brand;
    final tt = Theme.of(context).textTheme;
    final focusColor = ext.mark(s);
    final errorColor = ext.error.strong;
    final bool multiline = (maxLines == null) || (maxLines! > 1);

    OutlineInputBorder borderOf(Color color, double width) => OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: tt.labelLarge?.copyWith(
              color: enabled ? ext.textSecondary : ext.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          // Flutter's DEFAULT onTapOutside keeps the keyboard open on iOS/Android
          // (it only dismisses on desktop). Override it so tapping outside any
          // field closes the keyboard — the reported bug. Tapping another field
          // still moves focus (that field claims it after this fires).
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          keyboardType: keyboardType ??
              (multiline ? TextInputType.multiline : TextInputType.text),
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          enabled: enabled,
          autofocus: autofocus,
          autovalidateMode: autovalidateMode,
          cursorColor: focusColor,
          style: tt.bodyLarge?.copyWith(
            color: enabled ? ext.textPrimary : ext.textDisabled,
          ),
          decoration: InputDecoration(
            isDense: false,
            filled: true,
            fillColor: enabled ? ext.surfaceVariant : ext.surface,
            hintText: hint,
            hintStyle: tt.bodyLarge?.copyWith(color: ext.textTertiary),
            errorText: errorText,
            errorStyle: tt.bodySmall?.copyWith(color: errorColor),
            helperText: helperText,
            helperStyle: tt.bodySmall?.copyWith(color: ext.textTertiary),
            helperMaxLines: 2,
            errorMaxLines: 2,
            alignLabelWithHint: multiline,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: ext.textTertiary),
            suffixIcon: suffix,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: multiline ? AppSpacing.lg : AppSpacing.md + 2,
            ),
            enabledBorder: borderOf(ext.outline, 1),
            disabledBorder: borderOf(ext.outline.withOpacity(0.5), 1),
            focusedBorder: borderOf(focusColor, 1.6),
            errorBorder: borderOf(errorColor, 1),
            focusedErrorBorder: borderOf(errorColor, 1.6),
          ),
        ),
      ],
    );
  }
}

/// Shimmer loading placeholder.
/// A page-shaped placeholder built from [LoadingSkeleton] blocks.
///
/// The point is not "show something while loading" — it is that the placeholder
/// must occupy the **same** rhythm as the loaded page, or the swap jumps and the
/// skeleton has made the wait feel worse rather than better. So the padding and
/// separator sizes here are the ones real bodies use
/// (`AppSpacing.gutter` horizontal, `AppSpacing.lg` between cards), and callers
/// pass the real card height.
///
/// Two named constructors cover the shapes this app actually needs. Add a third
/// only when a third page genuinely differs — a parameter per screen defeats the
/// purpose.
///
/// Caveat inherited from [LoadingSkeleton]: while one of these is mounted,
/// `pumpAndSettle` never returns. Tests must use an explicit `pump(Duration)`.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({
    super.key,
    this.headerLines = 0,
    this.cards = 3,
    this.cardHeight = 96,
    this.rows = 0,
    this.padding,
  });

  /// A hero block plus stacked cards — a report or dashboard.
  const PageSkeleton.report({super.key})
      : headerLines = 2,
        cards = 3,
        cardHeight = 208,
        rows = 0,
        padding = null;

  /// A short intro plus list rows — a settings-shaped or registry-shaped page.
  const PageSkeleton.list({super.key, this.rows = 6})
      : headerLines = 2,
        cards = 0,
        cardHeight = 96,
        padding = null;

  /// Full-width lines above the content, for an intro paragraph.
  final int headerLines;

  /// Large blocks, sized by [cardHeight].
  final int cards;
  final double cardHeight;

  /// List-row-height blocks.
  final int rows;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var i = 0; i < headerLines; i++) {
      children.add(LoadingSkeleton.line(
        // Ragged widths read as text; equal widths read as a table.
        width: i.isEven ? 260 : 180,
      ));
      children.add(const SizedBox(height: AppSpacing.sm));
    }
    if (headerLines > 0) {
      children.add(const SizedBox(height: AppSpacing.md));
    }

    for (var i = 0; i < cards; i++) {
      children.add(LoadingSkeleton(
        width: double.infinity,
        height: cardHeight,
        radius: AppRadius.card,
      ));
      if (i != cards - 1) {
        children.add(const SizedBox(height: AppSpacing.lg));
      }
    }

    if (cards > 0 && rows > 0) {
      children.add(const SizedBox(height: AppSpacing.lg));
    }

    for (var i = 0; i < rows; i++) {
      children.add(const LoadingSkeleton(
        width: double.infinity,
        height: 64,
        radius: AppRadius.card,
      ));
      if (i != rows - 1) {
        children.add(const SizedBox(height: AppSpacing.sm));
      }
    }

    return ListView(
      padding: padding ??
          const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
              AppSpacing.gutter, AppSpacing.xxl),
      children: children,
    );
  }
}

class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  const LoadingSkeleton.card({super.key})
      : width = double.infinity,
        height = 96,
        radius = AppRadius.card;

  const LoadingSkeleton.line({super.key, this.width})
      : height = 14,
        radius = AppRadius.sm;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  /// Whether the shimmer is currently running, so a dependency change does not
  /// restart an already-running repeat.
  bool _animating = false;

  /// The shimmer starts here, not in the field initialiser, because
  /// `MediaQuery.disableAnimationsOf` needs a context — and it used to call
  /// `..repeat(reverse: true)` unconditionally, so a skeleton kept a ticker
  /// spinning forever even with reduce-motion on. That is both an accessibility
  /// problem (a pulsing block is a vestibular trigger) and a test hazard: any
  /// harness asserting `transientCallbackCount` settles to zero sees a
  /// perpetually-animating widget.
  ///
  /// Note the animation is a COLOUR lerp, so the widget count still stabilises —
  /// `pumpAndSettle` will nonetheless hang while one is mounted. Use an explicit
  /// `pump(Duration)` in tests.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      if (_animating) {
        _c.stop();
        _animating = false;
      }
      // Sit at the midpoint so the block still reads as a placeholder rather
      // than as surfaceVariant-coloured empty space.
      _c.value = 0.5;
    } else if (!_animating) {
      _animating = true;
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(ext.surfaceVariant, ext.outline, _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// The section "eyebrow" — a small uppercase label sitting above a heading
/// ("PERSONAL BEST", "LAST 7 DAYS", "BREATHING").
///
/// Thirteen sites compose this shape, in two spellings that differ only in
/// tracking: `tt.labelSmall?.copyWith(letterSpacing: 0.6)` and the same thing
/// at 0.5. (Two more, a raw `TextStyle(fontSize: 11, fontWeight: w700)` in
/// `vitavibe_settings_screen`, went with that screen — being raw they were
/// also in a different family, since `labelSmall` is Inter and a bare
/// `TextStyle` falls back to the platform default.) 0.6 is the one kept; the
/// difference is a tenth of a point and invisible. The point is that there is
/// now one of them.
///
/// Three adopters so far — `PersonalBestCard`, `KpiCell` and `InsightCard`,
/// the ones that live in this kit. Ten remain hand-rolled in `lib/features`,
/// across nine files; at 0.6: `trends_dashboard_screen`, `weekly_recap_screen`,
/// `sleep_consistency_card`, `prediction_card`, `sleep_dashboard_screen`,
/// `steps_dashboard_screen`; at 0.5: `nunito_medication_detail_screen`,
/// `sleep_score_ring`, and `home_dashboard` **twice** ('UP NEXT · …' and
/// 'OF 4'). `_eyebrowBudget` in `design_tokens_guard_test.dart` holds the same
/// census and says which of the ten want a `color:` rather than the default.
///
/// ## Why the default colour is secondary, not tertiary
///
/// Six of the ten use `ext.textTertiary`, and at 11pt that is measurably
/// below AA: 3.50:1 on the light background, 3.78:1 on a light card, 3.85:1 on
/// a dark card, 4.16:1 on the dark background — where normal text needs 4.5:1
/// and 11pt is nowhere near the 18pt/14pt-bold exemption. `ext.textSecondary`
/// clears it in every combination (5.53 / 5.98 / 7.71 / 8.32:1) and is still
/// plainly a de-emphasised label. So migrating a call site here will darken
/// its eyebrow slightly; that is the fix, not a side-effect.
///
/// [color] exists for the one eyebrow drawn on an accent fill rather than a
/// surface (`weekly_recap_screen` passes `on.withOpacity(0.7)`), where the
/// token would be the wrong contrast reference entirely — and for the two that
/// draw an accent on a surface (`home_dashboard`'s 'UP NEXT · …' in
/// `ext.mark(accent)`, `sleep_score_ring`'s score band), where the colour is
/// carrying meaning rather than de-emphasis.
class AppEyebrow extends StatelessWidget {
  final String text;

  /// Overrides the AA-safe default. Only for an eyebrow that is NOT on a
  /// surface — see the class doc.
  final Color? color;

  /// Forwarded to [Text] unchanged, all four defaulting to null so an eyebrow
  /// that passes none renders exactly as a bare `Text` does.
  ///
  /// They exist because two of the hand-rolled copies are constrained rather
  /// than free-flowing: `KpiCell`'s label sits in a 4-up row (~70pt a cell on a
  /// 320pt screen) inside a `FittedBox`, where "REMINDERS" broke as
  /// "REMINDE / RS" until it was clamped to one unwrapped line; `InsightCard`'s
  /// overline sits in an `Expanded` and ellipsizes. A widget that could not
  /// express either would have left both sites hand-rolled.
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const AppEyebrow(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Text(
      // Idempotent, so a call site that already passes 'PERSONAL BEST' renders
      // identically to one that passes 'Personal best'.
      text.toUpperCase(),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color ?? ext.textSecondary,
            letterSpacing: 0.6,
          ),
    );
  }
}

/// The −/+ value stepper: two icon buttons around a large number.
///
/// Three copies of this had drifted apart — `aqua_water_dashboard`,
/// `aqua_quick_add_grid` and `hydration_profile_screen` — with icon padding of
/// 10 against 8, value type of `displayLarge` against a raw
/// `TextStyle(fontSize: 28)`, and **no `tooltip:` on any of the six
/// `IconButton`s**, so a screen reader announced each of them as an unlabelled
/// "button". Hence [decrementTooltip] / [incrementTooltip] being required
/// rather than optional: the reason the copies had none is that nothing asked.
///
/// The value shrinks to fit rather than wrapping or clipping. A stepper is a
/// fixed row — two 44pt targets and two gaps — so on a 320pt phone at 2.0×
/// Dynamic Type a 28pt number has ~200pt to live in, and `scaleDown` never
/// enlarges, so a value that already fits is unchanged.
///
/// Must be laid out with a bounded width (the value takes the remaining
/// space); inside a sheet, card or column body that is always true.
class AppStepper extends StatelessWidget {
  /// The formatted value, e.g. `'2000ml'`.
  final String value;

  /// Optional second line under [value], e.g. `'8 glasses'`.
  final String? subLabel;

  /// Null disables the button — at a clamp boundary, say.
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  final String decrementTooltip;
  final String incrementTooltip;

  final AccentSwatch? accent;

  /// Defaults to `displayMedium` (28) — the size two of the three copies drew.
  /// Pass `displayLarge` for a hero stepper.
  final TextStyle? valueStyle;

  const AppStepper({
    super.key,
    required this.value,
    required this.decrementTooltip,
    required this.incrementTooltip,
    this.onDecrement,
    this.onIncrement,
    this.subLabel,
    this.accent,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        AppIconButton(
          icon: Symbols.remove_rounded,
          tooltip: decrementTooltip,
          onPressed: onDecrement,
          accent: s,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: (valueStyle ?? tt.displayMedium)
                      ?.copyWith(color: ext.mark(s)),
                ),
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        AppIconButton(
          icon: Symbols.add_rounded,
          tooltip: incrementTooltip,
          onPressed: onIncrement,
          accent: s,
        ),
      ],
    );
  }
}
