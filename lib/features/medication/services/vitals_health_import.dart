import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/health/health_sample_origin.dart';
import '../../../core/health/health_import_control.dart';
import '../../../core/health/import_ledger.dart';
import '../../../core/health/time_index.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../../../core/services/health_data_service.dart';
import '../models/blood_pressure_reading.dart';
import '../models/glucose_reading.dart';
import 'vitals_storage_service.dart';

/// A blood-pressure reading another app saved to the health store, ready to keep.
class ImportedBp {
  const ImportedBp({
    required this.id,
    required this.systolic,
    required this.diastolic,
    required this.takenAt,
  });

  final String id;
  final int systolic;
  final int diastolic;
  final DateTime takenAt;
}

/// A blood-sugar reading another app saved to the health store, in mg/dL.
class ImportedGlucose {
  const ImportedGlucose({
    required this.id,
    required this.valueMgdl,
    required this.takenAt,
  });

  final String id;
  final int valueMgdl;
  final DateTime takenAt;
}

/// What an import kept, by reading id: the Undo of it.
class VitalsImportResult {
  const VitalsImportResult({
    this.bloodPressure = const [],
    this.glucose = const [],
  });

  final List<String> bloodPressure;
  final List<String> glucose;

  int get count => bloodPressure.length + glucose.length;
  bool get isEmpty => count == 0;

  /// "2 blood pressure readings and 1 blood sugar reading".
  String describe() {
    String n(int count, String noun) => '$count $noun reading${count == 1 ? '' : 's'}';
    final parts = [
      if (bloodPressure.isNotEmpty) n(bloodPressure.length, 'blood pressure'),
      if (glucose.isNotEmpty) n(glucose.length, 'blood sugar'),
    ];
    return parts.join(' and ');
  }
}

/// Readings from a cuff or a meter app — an Omron, a Withings, a Qardio, a
/// glucose-meter app — that arrive in Health Connect or Apple Health without the
/// person typing them in again.
///
/// Opt-in: nothing is read until the person turns "Readings from other apps" on
/// in Vitals settings, and what comes in is theirs to remove (an Undo on the
/// toast, and a deleted reading does not come back).
///
/// Three things keep it from doing harm:
///  * **Its own entries are skipped.** This app writes blood pressure and blood
///    sugar out when sharing is on; reading them back would count each twice.
///    See [HealthSampleOrigin].
///  * **A reading already typed in is not added again.** If the cuff app and the
///    person both recorded 128/82 at 08:03, one of them is kept.
///  * **A reading is brought in once.** Every id seen is remembered, so a reading
///    the person deleted is not fetched again at the next start.
///
/// What comes in belongs to the person whose health store it is, not to whichever
/// family profile happens to be open.
class VitalsHealthImport {
  const VitalsHealthImport._();

  static const String _seenKey = 'vitals_health_import_seen_ids';

  /// Ids remembered, newest last, oldest dropped past this.
  static const int seenCap = 1500;
  static const ImportLedger _ledger = ImportLedger(_seenKey, cap: seenCap);

  /// How far back the first run reads: ninety days — where the platform lets it.
  ///
  /// On Android, Health Connect hands an app only the last 30 days before the permission
  /// was first granted unless it also holds `READ_HEALTH_DATA_HISTORY`, which this import
  /// does not ask for (that is a second sheet, and the cycle import's business). So there
  /// the first run finds about a month, whatever this says; the window then moves on from
  /// there as it always does, and nothing older is missed that could ever have been read.
  static const Duration firstLookback = Duration(days: 90);

  /// Later runs start this far before the last one, so a reading that reached the
  /// health store late is still found. The seen ids make the overlap free.
  static const Duration overlap = Duration(days: 7);

  /// The least time between two automatic runs.
  static const Duration minInterval = Duration(minutes: 15);

  /// The switch, the window, the gate and one-run-at-a-time, which this shares
  /// with the other imports from the health store.
  static final HealthImportControl _control = HealthImportControl(
    name: 'Vitals import',
    enabledKey: 'vitals_health_import_enabled',
    lastRunKey: 'vitals_health_import_last_run_ms',
    firstLookback: firstLookback,
    overlap: overlap,
    minInterval: minInterval,
  );

  /// Two readings this close, with the same numbers, are the same reading.
  static const Duration duplicateWindow = Duration(minutes: 2);

  // ---- what a read means (pure) ----------------------------------------------

  /// The blood-pressure readings in [points], oldest first.
  ///
  /// A reading is a systolic and a diastolic sample with the same time from the
  /// same app; one without its partner, an implausible pair, and anything this
  /// app wrote itself is dropped.
  static List<ImportedBp> bloodPressure(Iterable<HealthDataPoint> points) {
    final systolic = <String, HealthDataPoint>{};
    final diastolic = <String, HealthDataPoint>{};
    for (final p in HealthSampleOrigin.fromOthers(points)) {
      if (p.value is! NumericHealthValue) continue;
      final key = '${HealthSampleOrigin.appOf(p)}|${p.dateFrom.millisecondsSinceEpoch}';
      if (p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC) {
        systolic[key] = p;
      } else if (p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC) {
        diastolic[key] = p;
      }
    }
    final out = <ImportedBp>[];
    for (final e in systolic.entries) {
      final partner = diastolic[e.key];
      if (partner == null) continue;
      final sys = _round(e.value.value);
      final dia = _round(partner.value);
      if (!VitalsAnalyzer.isValidBp(sys, dia)) continue;
      out.add(ImportedBp(
        id: idFor('bp', e.value.dateFrom, HealthSampleOrigin.appOf(e.value)),
        systolic: sys,
        diastolic: dia,
        takenAt: e.value.dateFrom,
      ));
    }
    return out..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  }

  /// The blood-sugar readings in [points], oldest first, in mg/dL.
  static List<ImportedGlucose> glucose(Iterable<HealthDataPoint> points) {
    final out = <ImportedGlucose>[];
    for (final p in HealthSampleOrigin.fromOthers(points)) {
      if (p.type != HealthDataType.BLOOD_GLUCOSE) continue;
      if (p.value is! NumericHealthValue) continue;
      final mgdl = _round(p.value);
      if (!VitalsAnalyzer.isValidGlucoseMgdl(mgdl)) continue;
      out.add(ImportedGlucose(
        id: idFor('gl', p.dateFrom, HealthSampleOrigin.appOf(p)),
        valueMgdl: mgdl,
        takenAt: p.dateFrom,
      ));
    }
    return out..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  }

  /// The id a reading is kept under: the same sample always gets the same one, and
  /// two apps that saved a reading at the same second get different ones. [app] is
  /// [HealthSampleOrigin.appOf] — not `sourceId`, which Android leaves empty.
  static String idFor(String kind, DateTime at, String app) =>
      'hc_${kind}_${at.millisecondsSinceEpoch}_'
      '${sha1.convert(utf8.encode(app)).toString().substring(0, 8)}';

  /// Whether a reading was brought in from the health store rather than typed.
  static bool isImported(String readingId) =>
      readingId.startsWith(HealthSampleOrigin.bloodPressureIdPrefix) ||
      readingId.startsWith(HealthSampleOrigin.glucoseIdPrefix);

  static int _round(HealthValue v) => (v as NumericHealthValue).numericValue.round();

  // ---- the switch ------------------------------------------------------------

  static Future<bool> isEnabled() => _control.isEnabled();

  static Future<void> setEnabled(bool enabled) => _control.setEnabled(enabled);

  // ---- running it ------------------------------------------------------------

  /// Where a read starts: ninety days back the first time, otherwise a week before
  /// the last run.
  @visibleForTesting
  static DateTime windowStart({required int? lastRunMs, required DateTime now}) =>
      _control.windowStart(lastRunMs: lastRunMs, now: now);

  /// Stands in for the platform read when no samples are given: `kind` is `'bp'`
  /// or `'glucose'`. A test seam, so the case that matters — the store could not
  /// be read — can be driven.
  @visibleForTesting
  static Future<List<HealthDataPoint>> Function(
      String kind, DateTime from, DateTime to)? readerForTesting;

  /// Read, keep what is new, and report what was kept.
  ///
  /// Throws [HealthReadException] when the store could not be read — and then
  /// moves nothing, so the next run reads the same stretch again. "Could not look"
  /// and "nothing there" are different answers, and only the second may advance
  /// the window. (On Android the plugin turns a failed read into an empty one, so
  /// there the overlap is what catches it: see `HealthDataService._readOrThrow`.)
  ///
  /// [bpSamples] and [glucoseSamples] stand in for the platform read, which
  /// headless tests cannot reach. [since] overrides where the read starts.
  static Future<VitalsImportResult> run({
    DateTime? now,
    DateTime? since,
    Iterable<HealthDataPoint>? bpSamples,
    Iterable<HealthDataPoint>? glucoseSamples,
  }) =>
      _control.singleFlight(() => _run(
          now: now, since: since, bpSamples: bpSamples, glucoseSamples: glucoseSamples));

  static Future<VitalsImportResult> _run({
    DateTime? now,
    DateTime? since,
    Iterable<HealthDataPoint>? bpSamples,
    Iterable<HealthDataPoint>? glucoseSamples,
  }) async {
    final stillWanted = _control.watchSwitch();
    final wiped = _control.watchWipe();
    final at = now ?? clock.now();
    final prefs = await SharedPreferences.getInstance();
    final from = since ?? windowStart(lastRunMs: prefs.getInt(_control.lastRunKey), now: at);

    final service = HealthDataService.instance;
    final reader = readerForTesting;
    final bpPoints = bpSamples ??
        await (reader != null
            ? reader('bp', from, at)
            : service.readBloodPressureSamples(from, at));
    final glucosePoints = glucoseSamples ??
        await (reader != null
            ? reader('glucose', from, at)
            : service.readGlucoseSamples(from, at));
    // The reads are the slow part, and turning the switch off does not wait for
    // them: nothing is kept, and nothing remembered, from a read the person has
    // since said no to.
    if (!stillWanted()) return const VitalsImportResult();

    final seenList = _ledger.load(prefs);
    final seen = seenList.toSet();
    final newlySeen = <String>[];

    final bpReadings = bloodPressure(bpPoints);
    final glucoseReadings = glucose(glucosePoints);
    // Only what has not been seen needs comparing with what is already kept — and
    // this runs at every start and resume, when almost every run finds nothing new.
    // Oldest first, so the first and the last say how far the new ones reach.
    final newBp = [for (final r in bpReadings) if (!seen.contains(r.id)) r];
    final newGlucose = [for (final r in glucoseReadings) if (!seen.contains(r.id)) r];

    // What is already kept, around the new readings and no further: a reading can
    // only be a copy of one within [duplicateWindow] of it. Not the whole table on
    // every run, and — found by the minute they were taken, not scanned for each in
    // turn — not hundreds of millions of comparisons on a first run over a sensor's
    // months of readings. See [TimeIndex].
    Future<List<T>> keptAround<T>(List<DateTime> times,
            Future<List<T>> Function(DateTime from, DateTime to) load) async =>
        times.isEmpty
            ? <T>[]
            : load(times.first.subtract(duplicateWindow), times.last.add(duplicateWindow));
    final localBp = TimeIndex<BloodPressureReading>(
        await keptAround([for (final r in newBp) r.takenAt],
            (from, to) => VitalsStorageService.getBpForRange(from, to, scopeToActiveProfile: false)),
        at: (l) => l.takenAt);
    final localGlucose = TimeIndex<GlucoseReading>(
        await keptAround([for (final r in newGlucose) r.takenAt],
            (from, to) =>
                VitalsStorageService.getGlucoseForRange(from, to, scopeToActiveProfile: false)),
        at: (l) => l.takenAt);
    final savedBp = <String>[];
    final savedGlucose = <String>[];

    // One notice to the screens that follow the store, when all of it is saved —
    // not one per reading, each of which reloaded the list while the rest were
    // still being written.
    await VitalsStorageService.batch(() async {
      for (final r in newBp) {
        if (!stillWanted()) break;
        newlySeen.add(r.id);
        final already = localBp.anyNear(r.takenAt, duplicateWindow,
            (l) => l.systolic == r.systolic && l.diastolic == r.diastolic);
        if (already) continue;
        final reading = BloodPressureReading(
          id: r.id,
          systolic: r.systolic,
          diastolic: r.diastolic,
          takenAt: r.takenAt,
          createdAt: at,
        );
        await VitalsStorageService.saveBp(
          reading,
          stampActiveProfile: false,
          syncToHealthConnect: false,
        );
        savedBp.add(r.id);
        // Kept, so the next one in this run is compared with it too: a cuff app and
        // an aggregator that mirrors it each leave the same reading in the store, and
        // the second is a copy of the first as surely as a typed one would be.
        localBp.add(reading);
      }

      for (final r in newGlucose) {
        if (!stillWanted()) break;
        newlySeen.add(r.id);
        final already =
            localGlucose.anyNear(r.takenAt, duplicateWindow, (l) => l.valueMgdl == r.valueMgdl);
        if (already) continue;
        final reading = GlucoseReading(
          id: r.id,
          valueMgdl: r.valueMgdl,
          takenAt: r.takenAt,
          createdAt: at,
        );
        await VitalsStorageService.saveGlucose(
          reading,
          stampActiveProfile: false,
          syncToHealthConnect: false,
        );
        savedGlucose.add(r.id);
        localGlucose.add(reading);
      }
    });

    // What the next run will read again is the last [overlap] — a day more for
    // the edges. Those ids must outlive the cap: an app that writes a reading
    // every few minutes puts thousands into that week, and an id forgotten while
    // its reading can still be read is a deleted reading that comes back.
    final windowFrom = at.subtract(overlap + const Duration(days: 1));
    final stillRead = <String>{
      for (final r in bpReadings)
        if (!r.takenAt.isBefore(windowFrom)) r.id,
      for (final r in glucoseReadings)
        if (!r.takenAt.isBefore(windowFrom)) r.id,
    };
    // What was kept before the switch went off is still remembered, so it does not
    // come back after an Undo; where the run got to is not written — the next
    // "on" starts from the first window, as setEnabled(false) promised. After
    // "Delete all data" nothing is: the ids held here are the ones just deleted.
    if (!wiped()) await _ledger.remember(prefs, seenList, newlySeen, keep: stillRead);
    if (stillWanted()) await prefs.setInt(_control.lastRunKey, at.millisecondsSinceEpoch);

    return VitalsImportResult(bloodPressure: savedBp, glucose: savedGlucose);
  }

  /// [run], when the person has turned it on, the health store still allows it and
  /// it has not just run. Null when it did not run. Never throws: a health store
  /// that is slow, missing or refusing must not get in the way of opening the app.
  ///
  /// [force] skips the time gate (the switch has just been turned on).
  /// [hasPermission] stands in for the platform check in tests.
  static Future<VitalsImportResult?> runIfEnabled({
    bool force = false,
    DateTime? now,
    Future<bool> Function()? hasPermission,
    Iterable<HealthDataPoint>? bpSamples,
    Iterable<HealthDataPoint>? glucoseSamples,
  }) =>
      _control.runIfEnabled(
        force: force,
        now: now,
        hasPermission: hasPermission ?? HealthDataService.instance.hasVitalsReadPermission,
        run: (at) => run(now: at, bpSamples: bpSamples, glucoseSamples: glucoseSamples),
      );

  /// Take back what [result] kept. The ids stay remembered, so none of it is
  /// fetched again.
  static Future<void> undo(VitalsImportResult result) async {
    for (final id in result.bloodPressure) {
      await VitalsStorageService.deleteBp(id);
    }
    for (final id in result.glucose) {
      await VitalsStorageService.deleteGlucose(id);
    }
  }
}
