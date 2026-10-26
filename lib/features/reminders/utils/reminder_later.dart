/// Where "Later" sends a reminder.
///
/// Swiping a reminder to the left is "not now, but don't lose it". The answer is
/// not a fixed hour from now (an hour later is usually just as inconvenient) but
/// the next time the person is likely to be free: this evening if there is
/// still some of the day left, otherwise tomorrow morning.
class ReminderLater {
  const ReminderLater._();

  /// Evening slot, local time.
  static const int eveningHour = 18;

  /// Before this hour "later" means this evening; from it on, tomorrow. Leaves
  /// a clear gap so a reminder swiped at 17:50 is not pushed to 18:00.
  static const int eveningCutoffHour = 17;

  static const int morningHour = 9;
  static const int morningMinute = 30;

  /// The time to move a reminder to, from [now].
  ///
  /// Built through the `DateTime` constructor rather than by adding a
  /// `Duration`, so the wall-clock time survives a DST change.
  static DateTime from(DateTime now) {
    if (now.hour < eveningCutoffHour) {
      return DateTime(now.year, now.month, now.day, eveningHour);
    }
    return DateTime(now.year, now.month, now.day + 1, morningHour, morningMinute);
  }

  /// "this evening" or "tomorrow morning", for the confirmation.
  static String label(DateTime now) =>
      now.hour < eveningCutoffHour ? 'this evening' : 'tomorrow morning';
}
