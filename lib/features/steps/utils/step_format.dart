/// Number formatting shared across the steps feature.
///
/// Six byte-identical copies of the same StringBuffer loop had accumulated —
/// `_fmt` in the dashboard, the goal settings screen, the history screen, the
/// activity ring and the service, plus `_formatUnsigned` in the manual-entry
/// sheet — and the weekly chart grew a seventh shape, `_short`, for the same
/// numbers in a narrower space. `NumberFormat` is not used for this anywhere
/// in `lib`, so the hand-rolled loop stays; it just has one home now.
library;

/// `4321` → `"4,321"`, `-900` → `"-900"`, `0` → `"0"`.
///
/// Comma-grouped, three digits at a time. The separator is fixed rather than
/// locale-derived because every other number in this app is formatted the same
/// way and a mixed page reads as a bug.
String formatThousands(int n) {
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${n < 0 ? '-' : ''}$buf';
}

/// `850` → `"850"`, `4321` → `"4.3k"`, `12500` → `"13k"`.
///
/// For chips and badges, where the full grouped number would outrun the space
/// it has: one decimal below 10k, none above, so the label keeps a uniform
/// scannable width. Below 1000 — negatives included — the raw number is
/// already short enough, which is also what the weekly chart's `_short` did.
String formatCompactSteps(int n) {
  if (n < 1000) return '$n';
  final k = n / 1000.0;
  return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
}
