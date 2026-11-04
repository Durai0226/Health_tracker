/// Whose record is this?
///
/// Health Connect and HealthKit stamp every record with the app that wrote it.
/// This app writes some of what it can also read — blood pressure, blood sugar,
/// weight and water — so reading them back without looking at that stamp counts
/// every one of the person's own entries twice: once as typed here, once as the
/// copy this app sent out.
library;

import 'package:health/health.dart' show HealthDataPoint;

class HealthSampleOrigin {
  const HealthSampleOrigin._();

  /// What the platforms put on records this app writes: the Android application
  /// id (`android/app/build.gradle.kts`) and the iOS bundle id (the Runner
  /// target). A test reads both files and fails if either has moved on.
  static const Set<String> ownSourceIds = {
    'com.dlyminder.app',
    'com.implementation.tabletremainder.tabletRemainder',
  };

  /// The app that wrote [p].
  ///
  /// The plugin fills the two source fields differently on each platform. On iPhone
  /// `sourceId` is the bundle id and `sourceName` the name the person sees. On
  /// Android `sourceId` is always EMPTY and `sourceName` holds the package. Anything
  /// that asks "which app?" — whose record, which two halves belong together, what
  /// an id is built from — through `sourceId` alone sees every Android record as
  /// coming from the same nameless app.
  static String appOf(HealthDataPoint p) =>
      p.sourceId.isNotEmpty ? p.sourceId : p.sourceName;

  /// True for a record this app wrote itself.
  ///
  /// Checked on both fields: the id is in `sourceId` on iPhone and in `sourceName`
  /// on Android (see [appOf]). Comparing `sourceId` alone never recognised an
  /// Android record as this app's own, so with sharing on every blood pressure,
  /// sugar, weight and drink written here came back as another app's.
  static bool isOwn(HealthDataPoint p) =>
      ownSourceIds.contains(p.sourceId) || ownSourceIds.contains(p.sourceName);

  /// The samples another app or device wrote.
  static Iterable<HealthDataPoint> fromOthers(Iterable<HealthDataPoint> points) =>
      points.where((p) => !isOwn(p));

  // ---- readings kept here that came from the store -----------------------------

  /// What the id of a reading brought in from the health store starts with, per
  /// kind. The imports build their ids from these, and a test checks that they do.
  static const String bloodPressureIdPrefix = 'hc_bp_';
  static const String glucoseIdPrefix = 'hc_gl_';
  static const String weightIdPrefix = 'hc_import_';

  /// Whether a blood-pressure, blood-sugar or weight reading's id says it came
  /// from the health store rather than being typed in here.
  ///
  /// Such a reading must never be written back out, however it came to be saved
  /// again: an edit of an imported reading is a save like any other, and sent out,
  /// it puts a second copy in the store under this app's name — which every other
  /// app that reads the store then counts twice.
  static bool cameFromTheStore(String readingId) =>
      readingId.startsWith(bloodPressureIdPrefix) ||
      readingId.startsWith(glucoseIdPrefix) ||
      readingId.startsWith(weightIdPrefix);
}
