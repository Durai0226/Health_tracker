/// What was going on when a blood pressure was taken.
///
/// A reading after a coffee, a run or a bad night reads differently from a calm
/// one, and a doctor looking at a fortnight of numbers wants to know which were
/// which. A short list of circumstances the person can tick; it changes nothing
/// about how a reading is classified or averaged — it is context, not a
/// correction.
library;

class BpTag {
  const BpTag(this.id, this.label);

  /// Stable, stored. Never renamed: a backup written today must read the same
  /// next year.
  final String id;

  /// What is shown.
  final String label;
}

class BpTags {
  const BpTags._();

  static const List<BpTag> all = [
    BpTag('after_exercise', 'After exercise'),
    BpTag('after_caffeine', 'After caffeine'),
    BpTag('after_meal', 'After a meal'),
    BpTag('stressed', 'Stressed'),
    BpTag('rushed', 'Rushed'),
    BpTag('slept_badly', 'Slept badly'),
    BpTag('missed_medicine', 'Missed my medicine'),
    BpTag('at_clinic', 'At a clinic'),
  ];

  /// The tag for [id], or null for one this build does not know — which a
  /// backup from a newer build, or another source, may carry.
  static BpTag? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// What to show for [id]: its label, or the id itself made readable when it is
  /// one that is not in the catalogue ("after_swim" → "After swim"), so nothing a
  /// reading carries is hidden.
  static String labelOf(String id) {
    final known = byId(id);
    if (known != null) return known.label;
    final words = id.replaceAll('_', ' ').trim();
    if (words.isEmpty) return id;
    return words[0].toUpperCase() + words.substring(1);
  }

  /// [ids] as one line, in the order they are listed in [all] and then any
  /// others in the order given: "After exercise, Stressed".
  static String describe(Iterable<String> ids) {
    final list = ids.toList();
    final known = [for (final t in all) if (list.contains(t.id)) t.label];
    final other = [
      for (final id in list)
        if (byId(id) == null) labelOf(id)
    ];
    return [...known, ...other].join(', ');
  }

  /// [ids] in a stable order — the catalogue's, then any others as given — and
  /// each once. What is stored, so two readings with the same circumstances look
  /// the same on disk whatever order they were ticked in.
  static List<String> normalise(Iterable<String> ids) {
    final list = <String>[];
    for (final id in ids) {
      if (!list.contains(id)) list.add(id);
    }
    return [
      for (final t in all)
        if (list.contains(t.id)) t.id,
      for (final id in list)
        if (byId(id) == null) id,
    ];
  }

  /// [current] with [id] switched on or off, keeping any tag this build does not
  /// know about exactly as it was.
  static List<String> toggle(List<String> current, String id, {required bool on}) {
    final without = [for (final t in current) if (t != id) t];
    return on ? [...without, id] : without;
  }
}
