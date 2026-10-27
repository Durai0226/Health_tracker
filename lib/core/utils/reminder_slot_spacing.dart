/// How far apart two reminders' notification ids have to sit.
///
/// A reminder is armed under its slot, and — when it repeats on chosen days
/// (weekdays, weekends, custom) — also under `slot + 1 … slot + 7`, one
/// notification per weekday. The OS keeps ONE pending notification per id, so
/// slots handed out a single number apart let a weekday reminder's Tuesday land
/// on the next reminder's slot: whichever was armed second replaced the first,
/// and one of the two never fired, with nothing on screen to say so.
///
/// So a reminder owns [span] ids, not one, and a new slot is only ever handed
/// out where all of them are free.
class ReminderSlotSpacing {
  const ReminderSlotSpacing._();

  /// The slot itself and the seven weekday sub-ids after it.
  static const int span = 8;

  /// Whether a reminder at [a] and one at [b] would share an id.
  static bool overlap(int a, int b) => (a - b).abs() < span;

  /// The lowest slot in `[base, base + capacity)` whose whole [span] is clear of
  /// every slot in [taken], or null when the block has no such place left.
  ///
  /// Lowest-free rather than after-the-highest, so deleting a reminder gives its
  /// place back and churn does not walk off the end of the block.
  static int? lowestFree(
    Iterable<int> taken, {
    required int base,
    required int capacity,
  }) {
    final sorted = taken.toList()..sort();
    var candidate = base;
    for (final t in sorted) {
      if (t <= candidate - span) continue; // wholly before this candidate
      if (t >= candidate + span) break; // and so is everything after it
      candidate = t + span;
    }
    return candidate + span <= base + capacity ? candidate : null;
  }

  /// The items in [items] whose slot shares an id with an earlier item's, in the
  /// order given. The first of a clashing group keeps its place and the rest
  /// move: how a pile of slots handed out one apart is put right, oldest first
  /// so the reminder that has been armed longest is the one left alone.
  static List<T> clashing<T>(Iterable<T> items, int Function(T) slotOf) {
    final kept = <int>[];
    final moved = <T>[];
    for (final item in items) {
      final slot = slotOf(item);
      if (kept.any((k) => overlap(k, slot))) {
        moved.add(item);
      } else {
        kept.add(slot);
      }
    }
    return moved;
  }
}
