/// The step counts a reminder can wait for before it ticks itself off.
///
/// A short list rather than a free number: a typo of 80000 would make a
/// reminder that can never complete, and nothing tells a person why. Pure Dart —
/// the model reads it when a backup or a stored row hands back a number.
class ReminderStepTargets {
  const ReminderStepTargets._();

  /// Today's steps a reminder can be set to wait for, in the order the sheet
  /// lists them.
  static const List<int> options = [1000, 2000, 5000, 8000, 10000];

  static bool isKnown(int? steps) => steps != null && options.contains(steps);

  /// The value to keep, or null for "only a person ticks it off". A number no
  /// sheet offers (a hand-edited backup) is dropped, never rounded into one.
  static int? clean(Object? raw) {
    if (raw is! num || !raw.isFinite || raw != raw.truncate()) return null;
    final steps = raw.toInt();
    return isKnown(steps) ? steps : null;
  }

  static String _thousands(int n) =>
      n >= 1000 ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}' : '$n';

  /// "5,000 steps".
  static String labelFor(int steps) => '${_thousands(steps)} steps';
}
