/// Whose doctors and clinics a profile sees.
///
/// A doctor or clinic belongs to one household member (null is the account holder,
/// the same "null means self" as every other record) and is either theirs alone or
/// shared with the whole family. A family doctor is both at once, so sharing is its
/// own switch rather than something an owner of "everyone" could stand for.
///
/// Pure Dart; the storage service and both models go through it.
class CareTeamScope {
  const CareTeamScope._();

  /// Whether a record owned by [owner] and marked [shared] shows while [active] is
  /// the profile in view.
  static bool visible({
    required String? owner,
    required bool shared,
    required String? active,
  }) =>
      shared || owner == active;

  /// The value to keep for a stored or imported "shared" flag.
  ///
  /// Anything that is not an explicit false is shared: a record saved before doctors
  /// belonged to a person carries no flag, and treating it as private would hide
  /// every one of them from everybody but the account holder.
  static bool cleanShared(Object? raw) => raw != false;
}
