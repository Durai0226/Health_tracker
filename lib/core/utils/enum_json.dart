/// Reading persisted enums without letting one bad value destroy a feature.
///
/// Focus persists every enum as its **ordinal**, and every `fromJson` reached for
/// `Enum.values[json['x']]` directly. That throws `RangeError` for any index the
/// running build does not have, which happens in practice: a user records data on
/// a newer build, rolls back, and their history becomes unreadable.
///
/// The damage was disproportionate to the cause. `FocusService._loadData` parses
/// twenty preference keys inside **one** `try/catch`, so a single out-of-range
/// ordinal aborted the whole method and silently discarded sessions, garden, stats
/// and achievements together — the user opens Focus and everything is gone, with
/// the data still sitting on disk.
///
/// These helpers make a bad value cost one field instead of one feature.
class EnumJson {
  const EnumJson._();

  /// [raw] as an index into [values], or [fallback] if it is missing, not an
  /// integer, or out of range.
  static T at<T>(List<T> values, Object? raw, T fallback) {
    if (raw is int && raw >= 0 && raw < values.length) return values[raw];
    return fallback;
  }

  /// [raw] as an index into [values], or null if unusable.
  ///
  /// For genuinely optional fields, where a fallback would invent data.
  static T? atOrNull<T>(List<T> values, Object? raw) {
    if (raw is int && raw >= 0 && raw < values.length) return values[raw];
    return null;
  }

  /// A JSON **map key** as an enum value, or null if unusable.
  ///
  /// Enum-keyed maps serialise their keys as stringified ordinals, and the reading
  /// side did `Enum.values[int.parse(key)]` — which throws twice over: `int.parse`
  /// on a non-numeric key, and the index lookup on an unknown ordinal. Callers
  /// should skip null rather than substitute, because a wrong key silently
  /// re-attributes someone's minutes to a different activity.
  static T? key<T>(List<T> values, Object? rawKey) {
    final index = int.tryParse(rawKey?.toString() ?? '');
    if (index == null) return null;
    return atOrNull(values, index);
  }
}
