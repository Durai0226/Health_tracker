import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';

import '../models/cycle_phase.dart';

/// Maps cycle domain concepts onto the Calm Clarity design tokens. The feature
/// chrome uses the `period` accent; each phase gets its own role so the wheel
/// and calendar read as one system in light + dark.
///
/// menstrual → period · follicular → info · ovulation → reminders · luteal → focus
class PeriodTheme {
  const PeriodTheme._();

  static AccentSwatch phaseSwatch(AppColorsExt ext, CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return ext.period;
      case CyclePhase.follicular:
        return ext.info;
      case CyclePhase.ovulation:
        return ext.reminders;
      case CyclePhase.luteal:
        return ext.focus;
    }
  }

  static AccentSwatch of(BuildContext context, CyclePhase phase) =>
      phaseSwatch(AppColorsExt.of(context), phase);

  static IconData phaseIcon(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return Symbols.water_drop_rounded;
      case CyclePhase.follicular:
        return Symbols.spa_rounded;
      case CyclePhase.ovulation:
        return Symbols.egg_alt_rounded;
      case CyclePhase.luteal:
        return Symbols.nightlight_round_rounded;
    }
  }

  /// Accent used for the fertile-window band (a hopeful "reminders" role, kept
  /// distinct from the period accent).
  static AccentSwatch fertileSwatch(AppColorsExt ext) => ext.reminders;
}
