import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Which feature's accent to resolve. `home`/shell chrome uses the brand teal.
enum FeatureAccent { brand, medicine, water, focus, reminders, period, steps, sleep }

/// A complete accent role-set. Pick the right role for the right context:
/// - [base]   : fill / graphical (rings, chart bars, filled chips).
/// - [on]     : text/icon placed ON a [base] fill.
/// - [strong] : the accent as a small text/icon ON a light/app surface
///              (cyan & amber `base` fail contrast as marks — always use [strong]).
/// - [container]   : subtle tinted background (chips, tracks, icon badges).
/// - [onContainer] : text/icon on a [container].
@immutable
class AccentSwatch {
  final Color base;
  final Color on;
  final Color strong;
  final Color container;
  final Color onContainer;

  const AccentSwatch({
    required this.base,
    required this.on,
    required this.strong,
    required this.container,
    required this.onContainer,
  });

  static AccentSwatch lerp(AccentSwatch a, AccentSwatch b, double t) => AccentSwatch(
        base: Color.lerp(a.base, b.base, t)!,
        on: Color.lerp(a.on, b.on, t)!,
        strong: Color.lerp(a.strong, b.strong, t)!,
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );
}

/// The single dark-aware token source consumed by every widget:
/// `Theme.of(context).extension<AppColorsExt>()!`.
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  // surfaces
  final Color background, surface, surfaceVariant, surfaceElevated, outline, outlineStrong;
  // text
  final Color textPrimary, textSecondary, textTertiary, textDisabled;
  // brand
  final AccentSwatch brand;
  final Color brandText, brandPressed;
  // feature accents
  final AccentSwatch medicine, water, focus, reminders;
  final AccentSwatch period, steps, sleep;
  // semantic
  final AccentSwatch success, warning, error, info;
  final bool isDark;

  const AppColorsExt({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.brand,
    required this.brandText,
    required this.brandPressed,
    required this.medicine,
    required this.water,
    required this.focus,
    required this.reminders,
    required this.period,
    required this.steps,
    required this.sleep,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  AccentSwatch accent(FeatureAccent a) {
    switch (a) {
      case FeatureAccent.brand:
        return brand;
      case FeatureAccent.medicine:
        return medicine;
      case FeatureAccent.water:
        return water;
      case FeatureAccent.focus:
        return focus;
      case FeatureAccent.reminders:
        return reminders;
      case FeatureAccent.period:
        return period;
      case FeatureAccent.steps:
        return steps;
      case FeatureAccent.sleep:
        return sleep;
    }
  }

  static AppColorsExt of(BuildContext context) =>
      Theme.of(context).extension<AppColorsExt>() ?? light;

  /// AA-safe accent color for a foreground MARK (icon/text/thin stroke) drawn
  /// on the app/card surface. Light → darkened `strong`; dark → vivid `base`.
  Color mark(AccentSwatch s) => isDark ? s.base : s.strong;

  /// AA-safe background for a FILLED control (primary button). Pairs with [fillFg].
  Color fillBg(AccentSwatch s) => isDark ? s.base : s.strong;

  /// Foreground for a control filled with [fillBg].
  Color fillFg(AccentSwatch s) => isDark ? s.on : Colors.white;

  static const AppColorsExt light = AppColorsExt(
    isDark: false,
    background: AppPalette.backgroundL,
    surface: AppPalette.surfaceL,
    surfaceVariant: AppPalette.surfaceVariantL,
    surfaceElevated: AppPalette.surfaceElevatedL,
    outline: AppPalette.outlineL,
    outlineStrong: AppPalette.outlineStrongL,
    textPrimary: AppPalette.textPrimaryL,
    textSecondary: AppPalette.textSecondaryL,
    textTertiary: AppPalette.textTertiaryL,
    textDisabled: AppPalette.textDisabledL,
    brandText: AppPalette.brandText,
    brandPressed: AppPalette.brandPressed,
    brand: AccentSwatch(
      base: AppPalette.brand,
      on: AppPalette.onBrand,
      strong: AppPalette.brandText,
      container: AppPalette.brandContainer,
      onContainer: AppPalette.onBrandContainer,
    ),
    medicine: AccentSwatch(
      base: AppPalette.medicine,
      on: AppPalette.onMedicine,
      strong: AppPalette.medicineStrong,
      container: AppPalette.medicineContainer,
      onContainer: AppPalette.onMedicineContainer,
    ),
    water: AccentSwatch(
      base: AppPalette.water,
      on: AppPalette.onWater,
      strong: AppPalette.waterStrong,
      container: AppPalette.waterContainer,
      onContainer: AppPalette.onWaterContainer,
    ),
    focus: AccentSwatch(
      base: AppPalette.focus,
      on: AppPalette.onFocus,
      strong: AppPalette.focusStrong,
      container: AppPalette.focusContainer,
      onContainer: AppPalette.onFocusContainer,
    ),
    reminders: AccentSwatch(
      base: AppPalette.reminders,
      on: AppPalette.onReminders,
      strong: AppPalette.remindersStrong,
      container: AppPalette.remindersContainer,
      onContainer: AppPalette.onRemindersContainer,
    ),
    period: AccentSwatch(
      base: AppPalette.period,
      on: AppPalette.onPeriod,
      strong: AppPalette.periodStrong,
      container: AppPalette.periodContainer,
      onContainer: AppPalette.onPeriodContainer,
    ),
    steps: AccentSwatch(
      base: AppPalette.steps,
      on: AppPalette.onSteps,
      strong: AppPalette.stepsStrong,
      container: AppPalette.stepsContainer,
      onContainer: AppPalette.onStepsContainer,
    ),
    sleep: AccentSwatch(
      base: AppPalette.sleep,
      on: AppPalette.onSleep,
      strong: AppPalette.sleepStrong,
      container: AppPalette.sleepContainer,
      onContainer: AppPalette.onSleepContainer,
    ),
    success: AccentSwatch(
      base: AppPalette.success,
      on: Colors.white,
      strong: AppPalette.successStrong,
      container: AppPalette.successContainer,
      onContainer: AppPalette.onSuccessContainer,
    ),
    warning: AccentSwatch(
      base: AppPalette.warning,
      on: AppPalette.onReminders,
      strong: AppPalette.warningStrong,
      container: AppPalette.warningContainer,
      onContainer: AppPalette.onWarningContainer,
    ),
    error: AccentSwatch(
      base: AppPalette.error,
      on: Colors.white,
      strong: AppPalette.errorStrong,
      container: AppPalette.errorContainer,
      onContainer: AppPalette.onErrorContainer,
    ),
    info: AccentSwatch(
      base: AppPalette.info,
      on: Colors.white,
      strong: AppPalette.infoStrong,
      container: AppPalette.infoContainer,
      onContainer: AppPalette.onInfoContainer,
    ),
  );

  static const AppColorsExt dark = AppColorsExt(
    isDark: true,
    background: AppPalette.backgroundD,
    surface: AppPalette.surfaceD,
    surfaceVariant: AppPalette.surfaceVariantD,
    surfaceElevated: AppPalette.surfaceElevatedD,
    outline: AppPalette.outlineD,
    outlineStrong: AppPalette.outlineStrongD,
    textPrimary: AppPalette.textPrimaryD,
    textSecondary: AppPalette.textSecondaryD,
    textTertiary: AppPalette.textTertiaryD,
    textDisabled: AppPalette.textDisabledD,
    brandText: AppPalette.brandTextDark,
    brandPressed: AppPalette.brandPressedDark,
    brand: AccentSwatch(
      base: AppPalette.brandDark,
      on: AppPalette.onBrandDark,
      strong: AppPalette.brandTextDark,
      container: AppPalette.brandContainerDark,
      onContainer: AppPalette.onBrandContainerDark,
    ),
    medicine: AccentSwatch(
      base: AppPalette.medicineDark,
      on: AppPalette.onMedicineDark,
      strong: AppPalette.medicineStrongDark,
      container: AppPalette.medicineContainerDark,
      onContainer: AppPalette.onMedicineContainerDark,
    ),
    water: AccentSwatch(
      base: AppPalette.waterDark,
      on: AppPalette.onWaterDark,
      strong: AppPalette.waterStrongDark,
      container: AppPalette.waterContainerDark,
      onContainer: AppPalette.onWaterContainerDark,
    ),
    focus: AccentSwatch(
      base: AppPalette.focusDark,
      on: AppPalette.onFocusDark,
      strong: AppPalette.focusStrongDark,
      container: AppPalette.focusContainerDark,
      onContainer: AppPalette.onFocusContainerDark,
    ),
    reminders: AccentSwatch(
      base: AppPalette.remindersDark,
      on: AppPalette.onRemindersDark,
      strong: AppPalette.remindersStrongDark,
      container: AppPalette.remindersContainerDark,
      onContainer: AppPalette.onRemindersContainerDark,
    ),
    period: AccentSwatch(
      base: AppPalette.periodDark,
      on: AppPalette.onPeriodDark,
      strong: AppPalette.periodStrongDark,
      container: AppPalette.periodContainerDark,
      onContainer: AppPalette.onPeriodContainerDark,
    ),
    steps: AccentSwatch(
      base: AppPalette.stepsDark,
      on: AppPalette.onStepsDark,
      strong: AppPalette.stepsStrongDark,
      container: AppPalette.stepsContainerDark,
      onContainer: AppPalette.onStepsContainerDark,
    ),
    sleep: AccentSwatch(
      base: AppPalette.sleepDark,
      on: AppPalette.onSleepDark,
      strong: AppPalette.sleepStrongDark,
      container: AppPalette.sleepContainerDark,
      onContainer: AppPalette.onSleepContainerDark,
    ),
    success: AccentSwatch(
      base: AppPalette.successDark,
      on: AppPalette.onSuccessContainer,
      strong: AppPalette.successDark,
      container: AppPalette.onSuccessContainer,
      onContainer: AppPalette.successContainer,
    ),
    warning: AccentSwatch(
      base: AppPalette.warningDark,
      on: AppPalette.onRemindersDark,
      strong: AppPalette.warningDark,
      container: AppPalette.remindersContainerDark,
      onContainer: AppPalette.onRemindersContainerDark,
    ),
    error: AccentSwatch(
      base: AppPalette.errorDark,
      on: AppPalette.onErrorContainer,
      strong: AppPalette.errorDark,
      container: AppPalette.onErrorContainer,
      onContainer: AppPalette.errorContainer,
    ),
    info: AccentSwatch(
      base: AppPalette.infoDark,
      on: AppPalette.onInfoContainer,
      strong: AppPalette.infoDark,
      container: AppPalette.onInfoContainer,
      onContainer: AppPalette.infoContainer,
    ),
  );

  @override
  AppColorsExt copyWith() => this; // tokens are fixed per brightness

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      brandPressed: Color.lerp(brandPressed, other.brandPressed, t)!,
      brand: AccentSwatch.lerp(brand, other.brand, t),
      medicine: AccentSwatch.lerp(medicine, other.medicine, t),
      water: AccentSwatch.lerp(water, other.water, t),
      focus: AccentSwatch.lerp(focus, other.focus, t),
      reminders: AccentSwatch.lerp(reminders, other.reminders, t),
      period: AccentSwatch.lerp(period, other.period, t),
      steps: AccentSwatch.lerp(steps, other.steps, t),
      sleep: AccentSwatch.lerp(sleep, other.sleep, t),
      success: AccentSwatch.lerp(success, other.success, t),
      warning: AccentSwatch.lerp(warning, other.warning, t),
      error: AccentSwatch.lerp(error, other.error, t),
      info: AccentSwatch.lerp(info, other.info, t),
    );
  }
}
