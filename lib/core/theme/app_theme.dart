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

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: ext.background,
      canvasColor: ext.surface,
      cardColor: ext.surface,
      dividerColor: ext.outline,
      splashColor: ext.brand.base.withOpacity(0.08),
      highlightColor: ext.brand.base.withOpacity(0.04),
      extensions: [ext],
      textTheme: textTheme,

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          backgroundColor: ext.brandPressed,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          side: BorderSide(color: ext.outlineStrong),
          foregroundColor: ext.textPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ext.brandText,
          textStyle: textTheme.labelLarge,
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
