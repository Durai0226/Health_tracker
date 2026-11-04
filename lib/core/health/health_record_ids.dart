import 'package:flutter/foundation.dart' show TargetPlatform;

/// The names this app gives the records it writes to the phone's health store, so
/// it can find them again to replace or remove them.
///
/// Health Connect lets a writer name a record (`clientRecordId`) and replaces the
/// one of that name when the same name is written again with a higher
/// `clientRecordVersion`; it can also delete by name. That is what makes an edited
/// reading arrive as the corrected reading instead of a second one, and a deleted
/// reading disappear from the store as well as from here.
///
/// **Android only.** `package:health` passes the name on Android and ignores it on
/// iOS, where a rewrite would be a duplicate. [supported] is the one place that is
/// decided. Records written before this existed carry no name and are left alone:
/// the callers keep a per-record flag for the ones that do.
class HealthRecordIds {
  const HealthRecordIds._();

  static String bloodPressure(String readingId) => 'dlyminder-bp-$readingId';
  static String glucose(String readingId) => 'dlyminder-glucose-$readingId';
  static String weight(String readingId) => 'dlyminder-weight-$readingId';
  static String water(String logId) => 'dlyminder-water-$logId';

  /// Whether named records can be replaced and deleted on [platform].
  static bool supported(TargetPlatform platform) =>
      platform == TargetPlatform.android;

  /// The version to write [now]: milliseconds since the epoch, so every later
  /// write of the same name is higher than every earlier one. Exact as a double.
  static double version(DateTime now) => now.millisecondsSinceEpoch.toDouble();
}
