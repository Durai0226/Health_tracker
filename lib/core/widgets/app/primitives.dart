import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';

/// Flat scaffold on the token background.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBody;
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
    this.safeTop = false,
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
    return Scaffold(
      backgroundColor: ext.background,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
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
          Expanded(child: Text(title, style: tt.headlineMedium)),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

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
