import 'package:flutter/material.dart';

/// The ONLY place raw color hex lives. Brightness-agnostic constants.
///
/// Everything else (AppColors shim, AppColorsExt, AppTheme) selects from here.
/// Contrast ratios are WCAG 2.1, verified against light card `#FFFFFF` /
/// background `#F5F6F8` and the dark surfaces below.
class AppPalette {
  AppPalette._();

  // ── Brand — Teal (app-wide chrome: Home, shell, nav, primary actions) ──
  static const brand = Color(0xFF00897B);
  static const brandDark = Color(0xFF4DB6AC);
  static const brandPressed = Color(0xFF00796B); // AA fill for small labels
  static const brandPressedDark = Color(0xFF26A69A);
  static const onBrand = Color(0xFFFFFFFF);
  static const onBrandDark = Color(0xFF00382E);
  static const brandText = Color(0xFF00695C); // teal text/icon on light
  static const brandTextDark = Color(0xFF4DB6AC);
  static const brandContainer = Color(0xFFB2DFDB);
  static const brandContainerDark = Color(0xFF00504A);
  static const onBrandContainer = Color(0xFF00201C);
  static const onBrandContainerDark = Color(0xFFB2DFDB);

  // ── Feature accent: MEDICINE — Indigo ──
  static const medicine = Color(0xFF6366F1);
  static const medicineDark = Color(0xFF818CF8);
  static const onMedicine = Color(0xFFFFFFFF);
  static const onMedicineDark = Color(0xFF1E1B4B);
  static const medicineStrong = Color(0xFF4F46E5); // small text/icon on light
  static const medicineStrongDark = Color(0xFFA5B4FC);
  static const medicineContainer = Color(0xFFEAECFE);
  static const medicineContainerDark = Color(0xFF2E2A6B);
  static const onMedicineContainer = Color(0xFF3730A3);
  static const onMedicineContainerDark = Color(0xFFC7D2FE);

  // ── Feature accent: WATER — Cyan (never `base` as small fg on light) ──
  static const water = Color(0xFF06B6D4);
  static const waterDark = Color(0xFF22D3EE);
  static const onWater = Color(0xFF063842); // near-black; white fails on cyan
  static const onWaterDark = Color(0xFF042F38);
  static const waterStrong = Color(0xFF0E7490);
  static const waterStrongDark = Color(0xFF67E8F9);
  static const waterContainer = Color(0xFFCFF3FA);
  static const waterContainerDark = Color(0xFF164E63);
  static const onWaterContainer = Color(0xFF083344);
  static const onWaterContainerDark = Color(0xFFA5F0FC);

  // ── Feature accent: FOCUS — Violet ──
  static const focus = Color(0xFF8B5CF6);
  static const focusDark = Color(0xFFA78BFA);
  static const onFocus = Color(0xFFFFFFFF);
  static const onFocusDark = Color(0xFF2E1065);
  static const focusStrong = Color(0xFF7C3AED);
  static const focusStrongDark = Color(0xFFC4B5FD);
  static const focusContainer = Color(0xFFEDE9FE);
  static const focusContainerDark = Color(0xFF4C1D95);
  static const onFocusContainer = Color(0xFF5B21B6);
  static const onFocusContainerDark = Color(0xFFDDD6FE);

  // ── Feature accent: REMINDERS — Amber (never `base` as small fg on light) ──
  static const reminders = Color(0xFFF59E0B);
  static const remindersDark = Color(0xFFFBBF24);
  static const onReminders = Color(0xFF3A2A00); // near-black; white fails
  static const onRemindersDark = Color(0xFF422006);
  static const remindersStrong = Color(0xFFB45309);
  static const remindersStrongDark = Color(0xFFFCD34D);
  static const remindersContainer = Color(0xFFFEF0C7);
  static const remindersContainerDark = Color(0xFF78350F);
  static const onRemindersContainer = Color(0xFF92400E);
  static const onRemindersContainerDark = Color(0xFFFDE68A);

  // ── Feature accent: PERIOD — Rose/Pink ──
  static const period = Color(0xFFEC4899);
  static const periodDark = Color(0xFFF472B6);
  static const onPeriod = Color(0xFFFFFFFF);
  static const onPeriodDark = Color(0xFF4A0E27);
  static const periodStrong = Color(0xFFBE185D); // small text/icon on light
  static const periodStrongDark = Color(0xFFF9A8D4);
  static const periodContainer = Color(0xFFFCE7F3);
  static const periodContainerDark = Color(0xFF831843);
  static const onPeriodContainer = Color(0xFF9D174D);
  static const onPeriodContainerDark = Color(0xFFFBCFE8);

  // ── Feature accent: STEPS — Green (never `base` as small fg on light) ──
  static const steps = Color(0xFF22C55E);
  static const stepsDark = Color(0xFF4ADE80);
  static const onSteps = Color(0xFF052E16); // near-black; white fails on green
  static const onStepsDark = Color(0xFF052E16);
  static const stepsStrong = Color(0xFF15803D);
  static const stepsStrongDark = Color(0xFF86EFAC);
  static const stepsContainer = Color(0xFFDCFCE7);
  static const stepsContainerDark = Color(0xFF14532D);
  static const onStepsContainer = Color(0xFF166534);
  static const onStepsContainerDark = Color(0xFFBBF7D0);

  // ── Feature accent: SLEEP — Indigo-violet "night" ──
  static const sleep = Color(0xFF7C6FF0);
  static const sleepDark = Color(0xFFA5B4FC);
  static const onSleep = Color(0xFFFFFFFF);
  static const onSleepDark = Color(0xFF1E1B4B);
  static const sleepStrong = Color(0xFF5B4BD6);
  static const sleepStrongDark = Color(0xFFC7D2FE);
  static const sleepContainer = Color(0xFFECE9FD);
  static const sleepContainerDark = Color(0xFF312B6B);
  static const onSleepContainer = Color(0xFF4338CA);
  static const onSleepContainerDark = Color(0xFFDDD6FE);

  // ── Surfaces ──
  static const backgroundL = Color(0xFFF5F6F8);
  static const backgroundD = Color(0xFF0F1319);
  static const surfaceL = Color(0xFFFFFFFF);
  static const surfaceD = Color(0xFF171B22);
  static const surfaceVariantL = Color(0xFFEDEFF2);
  static const surfaceVariantD = Color(0xFF222831);
  static const surfaceElevatedL = Color(0xFFFFFFFF);
  static const surfaceElevatedD = Color(0xFF1E242C);
  static const outlineL = Color(0xFFE2E6EB);
  static const outlineD = Color(0xFF2B323C);
  static const outlineStrongL = Color(0xFFD1D7DE);
  static const outlineStrongD = Color(0xFF3A424E);

  // ── Text ──
  static const textPrimaryL = Color(0xFF1A1D21);
  static const textPrimaryD = Color(0xFFF2F4F7);
  static const textSecondaryL = Color(0xFF5B6472);
  static const textSecondaryD = Color(0xFFA5AEBC);
  static const textTertiaryL = Color(0xFF7A8494);
  static const textTertiaryD = Color(0xFF6E7885);
  static const textDisabledL = Color(0xFFB4BCC7);
  static const textDisabledD = Color(0xFF454D58);

  // ── Semantic (one set — Tailwind family) ──
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF34D399);
  static const successStrong = Color(0xFF047857); // AA fill / small text
  static const successContainer = Color(0xFFD1FAE5);
  static const onSuccessContainer = Color(0xFF065F46);

  static const warning = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFFBBF24);
  static const warningStrong = Color(0xFFB45309);
  static const warningContainer = Color(0xFFFEF0C7);
  static const onWarningContainer = Color(0xFF92400E);

  static const error = Color(0xFFEF4444);
  static const errorDark = Color(0xFFF87171);
  static const errorStrong = Color(0xFFDC2626);
  static const errorContainer = Color(0xFFFEE2E2);
  static const onErrorContainer = Color(0xFF991B1B);

  static const info = Color(0xFF3B82F6);
  static const infoDark = Color(0xFF60A5FA);
  static const infoStrong = Color(0xFF1D4ED8);
  static const infoContainer = Color(0xFFDBEAFE);
  static const onInfoContainer = Color(0xFF1E40AF);
}
