/// What "Delete all data" has to do when a copy of the data is in the cloud.
///
/// It wiped this device and left the switch that says "sync to the cloud" on, so
/// at the next start the sync did what it is for and brought every record back:
/// the person had deleted their data and watched it return. Cloud sync is a
/// consent the device holds (it is never restored from a backup either), so the
/// wipe has to deal with it explicitly — and say so — instead of leaving a copy
/// that undoes it.
library;

/// How far the deletion reaches.
enum DeleteAllScope {
  /// This device only. If a cloud copy exists, sync is turned off so it does not
  /// come back; the copy itself is left where it is.
  deviceOnly,

  /// This device and the cloud copy of the data. The account stays.
  deviceAndCloud,
}

class DeleteAllData {
  const DeleteAllData._();

  /// Whether a cloud copy is in play: sync is on and there is an account it
  /// would sync to.
  static bool cloudCopyAtStake({required bool syncOn, required bool signedIn}) =>
      syncOn && signedIn;

  /// The order of the deletion, with the platform parts handed in so the order is
  /// testable.
  ///
  /// **The cloud goes first.** If it were the other way round and the cloud step
  /// then failed, the person would see an empty device and believe everything was
  /// gone while a full copy of their record sat on a server. A failure there
  /// stops before anything local is touched. Sync is turned off before the
  /// device is wiped, so there is no moment at which an empty device is signed up
  /// to pull the copy straight back.
  ///
  /// Returns null on success, or a message to show.
  static Future<String?> run({
    required DeleteAllScope scope,
    required bool cloudCopyAtStake,
    required Future<List<String>> Function() deleteCloudCopy,
    required Future<void> Function() turnSyncOff,
    required Future<void> Function() wipeLocal,
  }) async {
    if (cloudCopyAtStake && scope == DeleteAllScope.deviceAndCloud) {
      final failed = await deleteCloudCopy();
      if (failed.isNotEmpty) {
        return 'Could not delete your cloud copy (${failed.join(', ')}). '
            'Nothing on this device was deleted.';
      }
    }
    if (cloudCopyAtStake) await turnSyncOff();
    await wipeLocal();
    return null;
  }

  /// What to tell the person once it is done.
  static String doneMessage(
      {required DeleteAllScope scope, required bool cloudCopyAtStake}) {
    if (!cloudCopyAtStake) return 'All data deleted.';
    return scope == DeleteAllScope.deviceAndCloud
        ? 'All data deleted here and in the cloud. Cloud sync is off.'
        : 'All data deleted from this device. Cloud sync is off, so your cloud '
            'copy stays where it is.';
  }
}
