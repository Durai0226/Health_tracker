/// The one definition of "this FlutterError is a layout overflow".
///
/// Lives here because both responsive harnesses have to agree on the answer and
/// disagree about what to DO with it. `responsive_overflow_test` collects
/// overflows and gates on them. `touch_target_audit_test` ignores them —
/// pricing one overflow as two findings helps nobody — and gates on every OTHER
/// error instead, which is how it tells a screen it measured from a screen that
/// never rendered. Two copies of the predicate is how those two halves would
/// drift apart, and an error neither harness counts is an error nobody sees.
library;

/// True for a RenderFlex/RenderBox overflow, false for every other failure.
bool isOverflowError(Object e) {
  final s = e.toString();
  return s.contains('overflowed by') || s.contains('A RenderFlex overflowed');
}
