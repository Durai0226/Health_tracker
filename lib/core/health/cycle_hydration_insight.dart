/// Hydration guidance for the luteal phase.
///
/// ## Why this is an insight and NOT a goal change
///
/// The physiology is real and specific. Basal plasma osmolality is genuinely
/// lower in the luteal phase (281 ± 1 mOsm/kgH2O) than the follicular phase
/// (286 ± 1), and the osmotic thresholds for BOTH thirst and vasopressin
/// release shift about 5 mOsm/kg lower — an oestrogen- and progesterone-driven
/// leftward reset of the whole osmoregulatory set point.
///
/// But a 5 mOsm/kg shift in a *threshold* is not a measured change in daily
/// fluid requirement, and no authority publishes a luteal-phase intake figure.
/// Turning it into millilitres would mean inventing a coefficient and dressing
/// it as science — exactly what the body-weight formula this app just removed
/// was doing.
///
/// So the target does not move. What the user gets is the explanation: thirst
/// arrives differently in this phase, which is worth knowing precisely because
/// it makes thirst a less reliable guide than usual.
///
/// Deliberately NOT surfaced under a fluid restriction: someone on a prescribed
/// ceiling does not need a nudge about drinking to thirst.
library;

import '../../features/period/models/cycle_phase.dart';
import 'insight.dart';

class CycleHydrationInsight {
  const CycleHydrationInsight._();

  static Insight? forPhase(CyclePhase? phase, {bool isRestricted = false}) {
    if (isRestricted) return null;
    if (phase != CyclePhase.luteal) return null;

    return Insight(
      id: 'hydration_luteal_phase',
      feature: InsightFeature.crossCutting,
      severity: InsightSeverity.info,
      title: 'Thirst reads differently this week',
      detail: 'In the luteal phase the body holds fluid at a slightly lower '
          'concentration, and the point at which you feel thirsty shifts with '
          'it. Your target has not changed — but thirst is a less reliable '
          'guide than usual, so going by the numbers beats going by feel.',
      metric: 'Luteal',
      why: 'Basal plasma osmolality is lower in the luteal phase '
          '(281 mOsm/kg) than the follicular phase (286 mOsm/kg), and the '
          'osmotic thresholds for thirst and vasopressin release are both '
          'about 5 mOsm/kg lower. No authority publishes a luteal-phase intake '
          'figure, so the daily target is deliberately left alone.',
      // Below the actionable water insights — this is context, not a task.
      rank: 30,
    );
  }
}
