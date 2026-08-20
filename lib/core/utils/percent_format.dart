/// Percent labels that never contradict the shape they sit inside.
///
/// A ring is a picture of a fraction and its centre label is a caption for that
/// picture, so the two must agree at the only two values a user actually reads
/// as absolute: **100%** must mean the arc is closed, and **0%** must mean
/// nothing has been done. Plain `(f * 100).round()` breaks both ends — 0.996
/// captions a visibly open ring "100%", and 0.004 captions a visibly started
/// one "0%" — and "the ring says 100% but a dose is still pending" is exactly
/// the kind of number a health app cannot be caught getting wrong.
class Pct {
  const Pct._();

  /// [fraction] in 0..1 → an integer percent that reads 100 **only** when the
  /// fraction is genuinely complete, and 0 **only** when it is genuinely zero.
  /// Everything in between rounds normally, then gets pinned off the endpoints.
  static int of(num fraction) {
    final f = fraction.toDouble();
    if (f.isNaN) return 0;
    if (f <= 0) return 0;
    if (f >= 1) return 100;
    final rounded = (f * 100).round();
    if (rounded >= 100) return 99; // 0.996 → "99%", not a lying "100%"
    if (rounded <= 0) return 1; //    0.004 → "1%",  not a lying "0%"
    return rounded;
  }

  /// [of], formatted for display.
  static String text(num fraction) => '${of(fraction)}%';

  /// The same guarantee for a count: [done] of [total]. Returns 100 only when
  /// [done] has actually reached [total]. A zero [total] is "nothing to do",
  /// which is complete rather than undefined — the caller decides whether to
  /// show it at all.
  static int ofCount(int done, int total) {
    if (total <= 0) return 100;
    return of(done / total);
  }
}
