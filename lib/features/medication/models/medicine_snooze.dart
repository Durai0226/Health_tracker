/// How long a medicine's Snooze waits, when the person has chosen a length for
/// that medicine rather than following the Notifications setting.
///
/// The lengths are the ones Notifications already offers, so there is one set of
/// numbers to understand. Pure Dart: the alarm isolate reads it too.
class MedicineSnooze {
  const MedicineSnooze._();

  /// Minutes a medicine can ask for, in the order the sheet lists them.
  static const List<int> options = [1, 5, 10, 15, 30];

  /// False for null and for any number a stored value or a hand-edited backup
  /// might carry that no sheet offers — those fall back to the phone-wide
  /// length, so a corrupt value can never make a snooze 0 or 10,000 minutes.
  static bool isKnown(int? minutes) => minutes != null && options.contains(minutes);

  /// The value to keep, or null for "follow the Notifications setting".
  static int? clean(Object? raw) {
    // JSON may hand a whole number back as a double (15.0); a fraction (15.5) or
    // NaN is not a length anyone chose, and must not be rounded into one.
    if (raw is! num || !raw.isFinite || raw != raw.truncate()) return null;
    final minutes = raw.toInt();
    return isKnown(minutes) ? minutes : null;
  }

  /// What a Snooze waits for: this medicine's own choice, else the length set in
  /// Notifications.
  static int effective(int? override, int phoneWide) =>
      isKnown(override) ? override! : phoneWide;

  static String labelFor(int? minutes) =>
      isKnown(minutes) ? '$minutes min' : 'Same as Notifications';
}
