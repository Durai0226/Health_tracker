/// Which card on Today goes first.
///
/// Today is a stack of cards in an order the person chose (Customize). That
/// order is right most of the day and wrong exactly when it matters: with a
/// dose overdue, the Medicine card sits under Water because that is where it was
/// dragged on a quiet morning. So ONE card, the one that wants the person now,
/// is lifted to the top and everything else keeps the order they gave it.
///
/// Pure Dart and deterministic; the screen supplies the numbers.
library;

/// The ids of Today's cards, in the order a person starts with.
const List<String> todayCardIds = ['medicine', 'water', 'weekly', 'activity'];

/// What on Today wants the person right now.
class TodayNeeds {
  /// Doses overdue, or due within [TodayOrder.soonMinutes]. A dose already
  /// marked missed is not "now" any more: it has its own recovery path.
  final int dosesDue;

  /// Reminders that came due inside [TodayOrder.remindersWindow] and are still
  /// open.
  final int remindersOverdue;

  /// How far behind an even pace through the waking day, in ml. 0 when level or
  /// ahead, for someone on a fluid limit, and for someone who isn't logging
  /// water: they are not behind so much as not using it.
  final int waterBehindMl;

  const TodayNeeds({
    this.dosesDue = 0,
    this.remindersOverdue = 0,
    this.waterBehindMl = 0,
  });

  static const TodayNeeds none = TodayNeeds();
}

/// The cards in the order to show them, and what (if anything) was moved.
class TodayArrangement {
  /// The visible cards, top to bottom.
  final List<String> order;

  /// The card that was lifted to the top, or null when nothing moved.
  final String? promoted;

  /// Why it was lifted, as a phrase that stands after the card's name:
  /// "2 doses are due".
  final String? reason;

  const TodayArrangement(this.order, {this.promoted, this.reason});
}

class TodayOrder {
  const TodayOrder._();

  /// A dose due within this many minutes wants you now.
  static const int soonMinutes = 60;

  /// Water has to be this far behind to take the top. The pacer's own "behind"
  /// starts at 250 ml, which is a little behind on most afternoons; lifting a
  /// card for that would be a card that is always on top.
  static const int waterBehindThresholdMl = 400;

  /// A reminder that came due longer ago than this has stopped being "now". It
  /// is the Overdue list's job, and a heap of them must not pin one card up
  /// for ever.
  static const Duration remindersWindow = Duration(hours: 24);

  /// What a stored order becomes: unknown ids dropped, repeats dropped, and any
  /// card the stored order has never heard of (one added since) put back in its
  /// default place at the end.
  static List<String> normalise(Object? saved) {
    final out = <String>[];
    if (saved is List) {
      for (final e in saved) {
        final id = e.toString();
        if (todayCardIds.contains(id) && !out.contains(id)) out.add(id);
      }
    }
    for (final id in todayCardIds) {
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  /// The order to show. [userOrder] is the person's own, [hidden] the cards they
  /// switched off (never promoted, never shown). With [promote] off the result
  /// is exactly the person's order.
  ///
  /// At most one card moves. Medicine outranks reminders, which outrank water:
  /// that is how much it costs to ignore each.
  static TodayArrangement arrange({
    required List<String> userOrder,
    Set<String> hidden = const {},
    TodayNeeds needs = TodayNeeds.none,
    bool promote = true,
  }) {
    final order = [
      for (final id in normalise(userOrder))
        if (!hidden.contains(id)) id,
    ];
    if (!promote || order.isEmpty) return TodayArrangement(order);

    String? id;
    String? reason;
    if (needs.dosesDue > 0 && order.contains('medicine')) {
      id = 'medicine';
      reason = needs.dosesDue == 1
          ? '1 dose is due'
          : '${needs.dosesDue} doses are due';
    } else if (needs.remindersOverdue > 0 && order.contains('activity')) {
      id = 'activity';
      reason = needs.remindersOverdue == 1
          ? '1 reminder is overdue'
          : '${needs.remindersOverdue} reminders are overdue';
    } else if (needs.waterBehindMl >= waterBehindThresholdMl &&
        order.contains('water')) {
      id = 'water';
      reason = 'about ${_nearest50(needs.waterBehindMl)} ml behind';
    }

    // Already on top: nothing moved, so there is nothing to explain.
    if (id == null || order.first == id) return TodayArrangement(order);
    return TodayArrangement([id, for (final o in order) if (o != id) o],
        promoted: id, reason: reason);
  }

  static int _nearest50(int ml) => (ml / 50).round() * 50;
}
