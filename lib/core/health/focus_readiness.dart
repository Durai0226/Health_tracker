/// Focus readiness: the honest version of a "how ready are you" signal.
///
/// ## What this is not
///
/// **There is no score here, and that is the design.** Opal ships an "Opal
/// Score" that combines sleep, focus and rest into one number, and its opacity
/// is the single most-criticised thing about it. Three independent reasons not to
/// copy it, any one sufficient:
///
///  1. **It cannot satisfy the `why` contract.** Every `Insight` in this app
///     carries a `why` naming the exact rule and the real numbers. A weighted
///     composite of three z-scores has no such sentence.
///  2. **A daily number you can be bad at is streak anxiety in a new costume.**
///     The CHI 2020 finding — rigid-streak users 63% more likely to quit after
///     one missed day — is about any daily scalar judgement, not streaks
///     specifically. Jomo's explicit rejection of "guilt scores" is the correct
///     read of this category.
///  3. **It is a health claim.** Apple 1.4.1 requires disclosed, validated
///     methodology behind accuracy claims; Play's Health Content policy
///     prohibits claims contradicting medical consensus. A number labelled
///     "focus capacity" derived from unvalidated consumer wrist HRV is exactly
///     what `focus_guards_test` exists to keep out.
///
/// ## What it is instead
///
/// One signal, named, against the user's OWN baseline, adjusting a *number*
/// rather than delivering a verdict. It reports two of the user's own figures and
/// offers a smaller session. That is the whole defensible surface.
library;

/// A single readiness observation. Never more than one signal.
class FocusReadinessNote {
  /// One sentence, in the user's own numbers. Never a diagnosis or a prediction.
  final String line;

  /// The exact rule and the real figures behind [line], for the `why` chip.
  final String why;

  /// A shorter suggested session, or null when there is nothing to suggest.
  final int? adjustedMinutes;

  /// Which signal fired — for tests and telemetry, never shown to the user.
  final FocusReadinessSignal signal;

  const FocusReadinessNote({
    required this.line,
    required this.why,
    required this.signal,
    this.adjustedMinutes,
  });
}

enum FocusReadinessSignal { sleep, hrv, restingHr }

class FocusReadiness {
  const FocusReadiness._();

  /// Minimum nights/days of history before any signal may fire.
  ///
  /// The same threshold `CorrelationResult.minPerGroup` and
  /// `FocusInsights.suggestedMinutes` use. Consistency matters more than the
  /// exact number: a user should not find one part of the app confident on four
  /// data points and another silent on nine.
  static const int minHistory = 5;

  /// Sleep deficit that counts, in minutes.
  ///
  /// The literature's headline is that ~16 minutes less sleep than usual
  /// measurably raises next-day cognitive interference. That is a real finding
  /// and it is the wrong threshold to ship: it is a population effect measured in
  /// a lab, and 16 minutes sits comfortably inside the night-to-night error of
  /// consumer sleep staging. Firing on it would mean firing about half of all
  /// days on noise. 45 minutes is the smallest delta that survives that error.
  ///
  /// The citation belongs in this comment and never in the UI.
  static const int sleepDeficitMinutes = 45;

  /// Fractional HRV drop that counts (10% below the personal baseline).
  static const double hrvDropFraction = 0.10;

  /// Resting-HR rise that counts, in bpm.
  static const int restingHrRiseBpm = 5;

  /// The one thing worth saying about today, or null.
  ///
  /// Priority is sleep → HRV → resting HR, and **exactly one signal is ever
  /// named**. "Three of your metrics are down" is a composite in disguise and it
  /// multiplies the false-positive rate: three independent noisy tests fire far
  /// more often than one.
  ///
  /// Null on: missing permission, thin history, mixed HRV metrics, only a derived
  /// resting HR, or every delta inside its threshold. Callers render nothing —
  /// silence is the correct output, the same standard
  /// `FocusInsights.suggestedMinutes` already holds.
  static FocusReadinessNote? assess({
    int? lastNightMinutes,
    int? sleepMedianMinutes,
    int loggedNights = 0,
    double? hrvLastNightMs,
    double? hrvBaselineMs,
    int hrvNights = 0,
    bool hrvMetricConsistent = true,
    int? restingHr,
    int? restingHrMedian,
    int rhrDays = 0,
    bool restingHrDerived = false,
    int? suggestedMinutes,
  }) {
    // ---- sleep ----
    if (lastNightMinutes != null &&
        sleepMedianMinutes != null &&
        loggedNights >= minHistory) {
      final deficit = sleepMedianMinutes - lastNightMinutes;
      if (deficit >= sleepDeficitMinutes) {
        final adjusted = _shorten(suggestedMinutes);
        return FocusReadinessNote(
          signal: FocusReadinessSignal.sleep,
          line: adjusted == null
              ? 'You slept ${_approx(deficit)} less than usual last night.'
              : 'You slept ${_approx(deficit)} less than usual last night. '
                  'A $adjusted-minute session might land better than '
                  '$suggestedMinutes — your call.',
          why: 'Last night: ${_hm(lastNightMinutes)} asleep vs your '
              '${_hm(sleepMedianMinutes)} median, across $loggedNights logged '
              'nights.',
          adjustedMinutes: adjusted,
        );
      }
    }

    // ---- HRV ----
    //
    // `hrvMetricConsistent` is a required guard, not a nicety: HealthKit reports
    // SDNN and Health Connect reports RMSSD, and comparing across them invents a
    // step change out of a unit difference.
    if (hrvMetricConsistent &&
        hrvLastNightMs != null &&
        hrvBaselineMs != null &&
        hrvBaselineMs > 0 &&
        hrvNights >= minHistory) {
      final drop = (hrvBaselineMs - hrvLastNightMs) / hrvBaselineMs;
      if (drop >= hrvDropFraction) {
        final adjusted = _shorten(suggestedMinutes);
        return FocusReadinessNote(
          signal: FocusReadinessSignal.hrv,
          line: adjusted == null
              ? 'Your overnight heart-rate variability is below your usual range.'
              : 'Your overnight heart-rate variability is below your usual '
                  'range. A $adjusted-minute session might suit today better.',
          why: 'Last night: ${hrvLastNightMs.round()} ms vs your '
              '${hrvBaselineMs.round()} ms baseline, across $hrvNights nights.',
          adjustedMinutes: adjusted,
        );
      }
    }

    // ---- resting heart rate ----
    //
    // Derived values are excluded outright. `BiometricDay.restingHrDerived` marks
    // a figure INFERRED from the night's HR distribution rather than reported by
    // the device — and a night the watch came off looks identical to a genuinely
    // elevated resting rate.
    if (!restingHrDerived &&
        restingHr != null &&
        restingHrMedian != null &&
        rhrDays >= minHistory) {
      final rise = restingHr - restingHrMedian;
      if (rise >= restingHrRiseBpm) {
        final adjusted = _shorten(suggestedMinutes);
        return FocusReadinessNote(
          signal: FocusReadinessSignal.restingHr,
          line: adjusted == null
              ? 'Your resting heart rate is a little above your usual.'
              : 'Your resting heart rate is a little above your usual. '
                  'A $adjusted-minute session might be the easier win today.',
          why: 'Today: $restingHr bpm vs your $restingHrMedian bpm median, '
              'across $rhrDays days.',
          adjustedMinutes: adjusted,
        );
      }
    }

    return null;
  }

  /// A shorter session: 70% of the usual, rounded to 5, floored at 10.
  ///
  /// Returns null when there is no established length yet — suggesting a specific
  /// smaller number against no evidence would be inventing both halves.
  ///
  /// **There is deliberately no counterpart that suggests a LONGER session.** The
  /// evidence that sleep loss degrades next-day prefrontal function is far
  /// stronger than any dose-response claim that extra sleep grants extra
  /// capacity, so "you're primed — try 90 minutes!" would be over-claiming, and
  /// it sets the user up to fail a target the app invented. Silence on good days
  /// is correct.
  static int? _shorten(int? suggestedMinutes) {
    if (suggestedMinutes == null) return null;
    final shorter = ((suggestedMinutes * 0.7) / 5).round() * 5;
    final floored = shorter < 10 ? 10 : shorter;
    // If shortening would not actually change anything, there is nothing to say.
    return floored >= suggestedMinutes ? null : floored;
  }

  /// "about an hour", "about 50 minutes" — vague on purpose.
  ///
  /// The underlying figure comes from consumer sleep staging, which is not
  /// accurate to the minute. Rendering "you slept 47 minutes less" would claim a
  /// precision the measurement has not got.
  static String _approx(int minutes) {
    if (minutes >= 105) return 'about ${(minutes / 60).round()} hours';
    if (minutes >= 50) return 'about an hour';
    return 'about ${(minutes / 10).round() * 10} minutes';
  }

  static String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
