import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';

/// Calm Clarity theme — one token-driven [ThemeData] pair.
///
/// Colors come from [AppPalette]/[AppColorsExt], type from [AppType]
/// (Inter + Plus Jakarta Sans), radii/shadows/motion from the design tokens.
/// The per-feature accents live in the registered [AppColorsExt] extension;
/// the [ColorScheme] stays brand-teal chrome only.
class AppTheme {
  static final ThemeData lightTheme = _build(Brightness.light, AppColorsExt.light);
  static final ThemeData darkTheme = _build(Brightness.dark, AppColorsExt.dark);

  static ThemeData _build(Brightness b, AppColorsExt ext) {
    final isLight = b == Brightness.light;

    final scheme = ColorScheme(
      brightness: b,
      primary: ext.brand.base,
      onPrimary: ext.brand.on,
      primaryContainer: ext.brand.container,
      onPrimaryContainer: ext.brand.onContainer,
      secondary: ext.brand.base,
      onSecondary: ext.brand.on,
      secondaryContainer: ext.brand.container,
      onSecondaryContainer: ext.brand.onContainer,
      error: ext.error.base,
      onError: Colors.white,
      errorContainer: ext.error.container,
      onErrorContainer: ext.error.onContainer,
      surface: ext.surface,
      onSurface: ext.textPrimary,
      surfaceContainerHighest: ext.surfaceVariant,
      onSurfaceVariant: ext.textSecondary,
      outline: ext.outline,
      outlineVariant: ext.outlineStrong,
      shadow: Colors.black,
    );

    final textTheme = AppType.textTheme(ext.textPrimary, ext.textSecondary);

    // Pressed/hovered paint nothing; FOCUSED still paints a ring.
    //
    // This distinction is load-bearing. InkResponse resolves
    //   overlayColor?.resolve(focused) ?? focusColor ?? theme.focusColor
    // so a flat `WidgetStatePropertyAll(Colors.transparent)` short-circuits
    // focusColor and silently removes the keyboard/switch-control focus
    // indicator from every button and every InkWell in the app — WCAG 2.4.7
    // Focus Visible. Stripping tap feedback is a design choice; stripping the
    // focus ring is a conformance failure, so the two are separated here.
    final noOverlay = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.focused)
          ? ext.brand.base.withOpacity(0.12)
          : Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: ext.background,
      canvasColor: ext.surface,
      cardColor: ext.surface,
      dividerColor: ext.outline,
      // NO INK. Every tap responds by changing state immediately rather than
      // by animating a ripple outward.
      //
      // Three separate mechanisms have to be defeated, which is why this is not
      // just `splashColor: transparent`:
      //   * `splashFactory` builds the expanding circle,
      //   * `highlightColor` is the separate flat wash that stays for as long as
      //     the finger is down (NoSplash does not remove it),
      //   * M3 buttons and TabBar ignore both of the above and use a
      //     `WidgetStateProperty overlayColor` instead — handled per-theme below.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      extensions: [ext],
      textTheme: textTheme,

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // M3 buttons ignore the top-level splash/highlight and use these.
          splashFactory: NoSplash.splashFactory,

          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          backgroundColor: ext.brandPressed,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ).copyWith(overlayColor: noOverlay),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // M3 buttons ignore the top-level splash/highlight and use these.
          splashFactory: NoSplash.splashFactory,

          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          side: BorderSide(color: ext.outlineStrong),
          foregroundColor: ext.textPrimary,
          textStyle: textTheme.labelLarge,
        ).copyWith(overlayColor: noOverlay),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // M3 buttons ignore the top-level splash/highlight and use these.
          splashFactory: NoSplash.splashFactory,

          foregroundColor: ext.brandText,
          textStyle: textTheme.labelLarge,
        ).copyWith(overlayColor: noOverlay),
      ),
      // Every raw Material IconButton, at Apple's 44pt comfort minimum.
      //
      // The default lands at 40x40 (24pt icon + 8pt padding), which is above
      // WCAG's 24pt floor but below the size at which people reliably hit a
      // target one-handed. It showed up on the month-navigation chevrons of
      // both calendars and on the water dashboard's header actions — small
      // icon-only controls, which are the worst case for a near-miss.
      //
      // Theme-level so it holds for IconButtons added later, rather than
      // needing to be remembered at each of the ~40 call sites. AppIconButton
      // already defaults to 44 and is unaffected.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: ext.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: ext.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: ext.brand.base, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: ext.error.base),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: textTheme.bodyMedium?.copyWith(color: ext.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: ext.textTertiary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: ext.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brCard),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ext.brand.base,
        foregroundColor: ext.brand.on,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ext.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ext.textPrimary),
        actionsIconTheme: IconThemeData(color: ext.textPrimary),
        titleTextStyle: textTheme.headlineSmall,
        // Pin the status-bar glyphs to the THEME's brightness. Without this
        // Flutter derives them from the AppBar's backgroundColor via
        // estimateBrightnessForColor — and three water screens override that
        // to Colors.transparent, whose luminance is 0, so it was read as a
        // dark bar and forced WHITE glyphs over a light scaffold. The clock,
        // wifi and battery were effectively invisible.
        systemOverlayStyle: b == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: ext.outline, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: ext.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSheet),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ext.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ext.surfaceElevated,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.topSheet),
        dragHandleColor: ext.outlineStrong,
        dragHandleSize: const Size(40, 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? ext.textPrimary : ext.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? ext.surface : ext.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ext.surfaceVariant,
        selectedColor: ext.brand.container,
        disabledColor: ext.surfaceVariant,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: ext.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        side: BorderSide(color: ext.outline),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? ext.brand.base : ext.textTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
            ? ext.brand.base.withOpacity(0.45)
            : ext.surfaceVariant),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ext.brand.base,
        inactiveTrackColor: ext.surfaceVariant,
        thumbColor: ext.brand.base,
        overlayColor: ext.brand.base.withOpacity(0.15),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ext.brand.base,
        linearTrackColor: ext.surfaceVariant,
        circularTrackColor: ext.surfaceVariant,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ext.brand.base,
        unselectedLabelColor: ext.textSecondary,
        indicatorColor: ext.brand.base,
        dividerColor: ext.outline,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        // TabBar draws its own ink and reads `overlayColor`, not the
        // top-level splash/highlight — both are needed to silence it.
        splashFactory: NoSplash.splashFactory,
        overlayColor: noOverlay,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ext.textSecondary,
        textColor: ext.textPrimary,
        titleTextStyle: textTheme.titleLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: ext.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ext.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        textStyle: textTheme.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ext.textPrimary,
          borderRadius: AppRadius.brSm,
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: ext.surface),
      ),
      // Material Symbols (variable font): render filled at a medium weight by
      // default so the app keeps its solid, confident icon identity. Surfaces
      // that want an outline-at-rest affordance set `fill: 0` explicitly (e.g.
      // the nav bar's inactive tabs). MaterialIcons glyphs ignore these axes.
      iconTheme: IconThemeData(
        color: ext.textPrimary,
        size: 24,
        fill: 1,
        weight: 500,
        opticalSize: 24,
      ),
    );
  }
}
