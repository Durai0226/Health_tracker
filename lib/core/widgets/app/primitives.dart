import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';

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
            TextButton(
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
                  style: tt.labelLarge?.copyWith(color: ext.mark(s))),
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
    return Center(
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
    );
  }
}

/// Settings/action row: accent icon chip + title + subtitle + trailing.
class AppListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AccentSwatch? accent;
  final Color? iconColor;
  final Color? titleColor;

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
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    final ic = iconColor ?? s.onContainer;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? s.base).withOpacity(0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, size: 20, color: ic),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleLarge
                            ?.copyWith(color: titleColor ?? ext.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
            ],
          ),
        ),
      ),
    );
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
