/// The four canonical phases of a menstrual cycle.
///
/// Pure Dart — NO Flutter imports — so it can be shared with the unit-testable
/// [CyclePredictor]. The per-phase accent colour ("color role") is resolved in
/// `theme/period_theme.dart` (which owns all Flutter/design imports); here we
/// only name the role via [accentName] so this file stays dependency-free.
enum CyclePhase { menstrual, follicular, ovulation, luteal }

extension CyclePhaseX on CyclePhase {
  /// Human title, e.g. "Follicular".
  String get label {
    switch (this) {
      case CyclePhase.menstrual:
        return 'Menstrual';
      case CyclePhase.follicular:
        return 'Follicular';
      case CyclePhase.ovulation:
        return 'Ovulation';
      case CyclePhase.luteal:
        return 'Luteal';
    }
  }

  /// Compact label for tight chips ("Ovul.").
  String get shortLabel {
    switch (this) {
      case CyclePhase.menstrual:
        return 'Period';
      case CyclePhase.follicular:
        return 'Follicular';
      case CyclePhase.ovulation:
        return 'Ovulation';
      case CyclePhase.luteal:
        return 'Luteal';
    }
  }

  /// One-line, honest description of what the phase means.
  String get description {
    switch (this) {
      case CyclePhase.menstrual:
        return 'Your period — the uterine lining sheds.';
      case CyclePhase.follicular:
        return 'Post-period build-up before ovulation.';
      case CyclePhase.ovulation:
        return 'Estimated fertile peak around egg release.';
      case CyclePhase.luteal:
        return 'Post-ovulation wind-down toward the next period.';
    }
  }

  /// The design-system accent role this phase maps to. Resolved to an
  /// [AccentSwatch] in `period_theme.dart` — kept as a plain string here so the
  /// predictor stays Flutter-free.
  ///
  /// menstrual → period · follicular → info · ovulation → reminders · luteal → focus.
  String get accentName {
    switch (this) {
      case CyclePhase.menstrual:
        return 'period';
      case CyclePhase.follicular:
        return 'info';
      case CyclePhase.ovulation:
        return 'reminders';
      case CyclePhase.luteal:
        return 'focus';
    }
  }
}
