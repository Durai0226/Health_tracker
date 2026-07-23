/// A qualitative, non-shaming reading of bedtime regularity.
///
/// We deliberately avoid a naked percentage or the word "poor": consistency is
/// framed as a behavioural *rhythm* the user can build, never a health grade or
/// a mortality claim. The gentlest downside word we ever use is "variable".
enum SleepConsistency {
  /// Not enough logged nights yet to say anything honest.
  building,

  /// Bedtimes vary a lot (the softest downside label we allow).
  variable,

  fairlyRegular,

  veryRegular;

  /// Classify from a [regularityIndex] (0..1) given how many nights fed it.
  ///
  /// [sampleSize] below 3 → [building] (mirrors [SleepService.regularityIndex]'s
  /// neutral floor, so we never present the 0.75 placeholder as a real reading).
  static SleepConsistency fromIndex(double index, {required int sampleSize}) {
    if (sampleSize < 3) return SleepConsistency.building;
    if (index >= 0.80) return SleepConsistency.veryRegular; // std ≲ 18 min
    if (index >= 0.55) return SleepConsistency.fairlyRegular; // std ≲ 40 min
    return SleepConsistency.variable;
  }

  /// The friendly headline label (never a percent, never "poor").
  String get label {
    switch (this) {
      case SleepConsistency.building:
        return 'Building your rhythm';
      case SleepConsistency.variable:
        return 'Variable';
      case SleepConsistency.fairlyRegular:
        return 'Fairly regular';
      case SleepConsistency.veryRegular:
        return 'Very regular';
    }
  }

  /// One calm, behavioural line — never medical, never a mortality claim.
  String get why {
    switch (this) {
      case SleepConsistency.building:
        return 'Log a few nights to see your bedtime rhythm.';
      case SleepConsistency.variable:
        return 'Your bedtimes vary a lot lately — a steadier time can help you rest.';
      case SleepConsistency.fairlyRegular:
        return 'Fairly steady bedtimes. A little more consistency helps.';
      case SleepConsistency.veryRegular:
        return 'Steady bedtimes — great for falling asleep faster.';
    }
  }

  /// False only in the [building] cold-start state.
  bool get hasEnoughData => this != SleepConsistency.building;
}
