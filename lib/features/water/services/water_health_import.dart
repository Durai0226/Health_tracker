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
import '../../../core/services/health_data_service.dart';
import '../models/beverage_type.dart';
import 'water_service.dart';
import '../../../core/utils/units.dart';

/// A drink another app saved to the health store, ready to keep.
class ImportedDrink {
  const ImportedDrink({required this.id, required this.amountMl, required this.at});

  final String id;
  final int amountMl;
  final DateTime at;
}

/// What an import kept: the Undo of it.
class WaterImportResult {
  const WaterImportResult([this.logs = const []]);

  final List<({DateTime date, String id, int amountMl})> logs;

  int get count => logs.length;
  bool get isEmpty => logs.isEmpty;
  int get totalMl => logs.fold(0, (sum, l) => sum + l.amountMl);

  /// "2 drinks (650 ml)".
  String describe() =>
      '$count drink${count == 1 ? '' : 's'} (${Units.volumeText(totalMl)})';
}

/// Drinks logged in another app — Samsung Health, Fitbit, a smart bottle's app —
/// counted toward today, so the total is what the person actually drank rather
/// than only what they typed in here.
///
/// Opt-in: nothing is read until the person turns "Count drinks from other apps"
/// on in the Hydration profile, and a drink that came in can be removed (an Undo
/// on the toast, and a deleted drink does not come back).
///
/// The same three guards as the vitals import (`VitalsHealthImport`):
///  * **This app's own drinks are skipped.** With sharing on, every drink logged
///    here is also in the health store under this app's name.
///  * **A drink already typed in is not added again** — same amount within two
///    minutes.
///  * **A drink is brought in once.** Every id seen is remembered.
///
/// Plus one of its own: what comes in is **not written back**. A drink from
/// Samsung Health sent out again under this app's name would be counted twice by
/// everything that reads the store.
///
/// Brought in as plain water. The other app's drink type is not in the record, so
/// there is nothing truer to say, and the footer on the switch says so.
class WaterHealthImport {
  const WaterHealthImport._();

  static const ImportLedger _ledger = ImportLedger('water_health_import_seen_ids');

  /// How far back the first run reads. Water is a today thing: a fortnight of
  /// someone else's drinks would reshape history nobody asked about.
  static const Duration firstLookback = Duration(days: 3);

  /// Later runs start this far before the last one, so a drink that reached the
  /// health store late is still found.
  static const Duration overlap = Duration(days: 2);

  /// The least time between two automatic runs.
  static const Duration minInterval = Duration(minutes: 15);

  /// The switch, the window, the gate and one-run-at-a-time, which this shares
  /// with the other imports from the health store.
  static final HealthImportControl _control = HealthImportControl(
    name: 'Water import',
    enabledKey: 'water_health_import_enabled',
    lastRunKey: 'water_health_import_last_run_ms',
    firstLookback: firstLookback,
    overlap: overlap,
    minInterval: minInterval,
  );

  /// Two drinks this close, of the same amount, are the same drink.
  static const Duration duplicateWindow = Duration(minutes: 2);

  /// A record outside these is not a drink: a rounding artefact below, a day's
  /// total written as one record above.
  static const int minMl = 10;
  static const int maxMl = 5000;

  // ---- what a read means (pure) ----------------------------------------------

  /// The drinks in [points], oldest first.
  static List<ImportedDrink> drinks(Iterable<HealthDataPoint> points) {
    final out = <ImportedDrink>[];
    for (final p in HealthSampleOrigin.fromOthers(points)) {
      if (p.type != HealthDataType.WATER) continue;
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final ml = (v.numericValue * 1000).round();
      if (ml < minMl || ml > maxMl) continue;
      out.add(ImportedDrink(
        id: idFor(p),
        amountMl: ml,
        // An interval record is the drink at the moment it ended.
        at: p.dateTo,
      ));
    }
    return out..sort((a, b) => a.at.compareTo(b.at));
  }

  /// The id a drink is kept under: the same sample always gets the same one.
  static String idFor(HealthDataPoint p) => p.uuid.isNotEmpty
      ? 'hc_water_${p.uuid}'
      : 'hc_water_${p.dateTo.millisecondsSinceEpoch}_'
          '${sha1.convert(utf8.encode(HealthSampleOrigin.appOf(p))).toString().substring(0, 8)}';

  /// Whether a log is one this import brought in.
  static bool isImported(String logId) => logId.startsWith('hc_water_');

  // ---- the switch ------------------------------------------------------------

  static Future<bool> isEnabled() => _control.isEnabled();

  static Future<void> setEnabled(bool enabled) => _control.setEnabled(enabled);

  // ---- running it ------------------------------------------------------------

  /// Where a read starts: three days back the first time, otherwise two days
  /// before the last run.
  @visibleForTesting
  static DateTime windowStart({required int? lastRunMs, required DateTime now}) =>
      _control.windowStart(lastRunMs: lastRunMs, now: now);

  /// Stands in for the platform read when no `samples` are given. A test seam, so
  /// the case that matters — the store could not be read — can be driven.
  @visibleForTesting
  static Future<List<HealthDataPoint>> Function(DateTime from, DateTime to)?
      readerForTesting;

  /// Read, keep what is new, and report what was kept.
  ///
  /// Throws [HealthReadException] when the store could not be read — and then
  /// moves nothing: the window and the ledger stay where they were, so the next
  /// run reads the same stretch again. "Could not look" and "nothing there" are
  /// different answers, and only the second may advance the window. (On Android the
  /// plugin turns a failed read into an empty one, so there the overlap is what
  /// catches it: see `HealthDataService._readOrThrow`.)
  ///
  /// [samples] stands in for the platform read, which headless tests cannot reach.
  static Future<WaterImportResult> run({
    DateTime? now,
    DateTime? since,
    Iterable<HealthDataPoint>? samples,
  }) =>
      _control.singleFlight(() => _run(now: now, since: since, samples: samples));

  static Future<WaterImportResult> _run({
    DateTime? now,
    DateTime? since,
    Iterable<HealthDataPoint>? samples,
  }) async {
    final stillWanted = _control.watchSwitch();
    final wiped = _control.watchWipe();
    final at = now ?? clock.now();
    final prefs = await SharedPreferences.getInstance();
    final from = since ?? windowStart(lastRunMs: prefs.getInt(_control.lastRunKey), now: at);
    final points = samples ??
        await (readerForTesting ?? HealthDataService.instance.readWaterSamples)(
            from, at);
    // The read is the slow part, and turning the switch off does not wait for it:
    // nothing is kept, and nothing remembered, from a read the person has since
    // said no to.
    if (!stillWanted()) return const WaterImportResult();

    final seenList = _ledger.load(prefs);
    final seen = seenList.toSet();
    final newlySeen = <String>[];
    final kept = <({DateTime date, String id, int amountMl})>[];
    final water = BeverageType.defaultBeverages.first;

    for (final d in drinks(points)) {
      if (seen.contains(d.id)) continue;
      final day = DateTime(d.at.year, d.at.month, d.at.day);
      final logged = (await WaterService.loadDataForDate(day))?.logs ?? const [];
      // Asked after the look at the day, which is the first await of every pass — so
      // this is also where the previous drink's write is accounted for.
      if (!stillWanted()) break;
      newlySeen.add(d.id);
      // This very drink is already here: the run that saved it was killed before it
      // wrote the ledger, or the phone was restored from a backup (the ledger is not
      // in one). Added again, it put a second log with the same id in the day and
      // the day's total doubled. Remembered as seen all the same.
      if (logged.any((l) => l.id == d.id)) continue;
      // Only what the person typed in is a duplicate. Another record from the
      // health store is another drink, however alike: a smart bottle that saves
      // two 250 ml drinks a minute and a half apart has saved two. Checked against
      // everything on the day, the second was taken for a copy of the first — which
      // this very run had just added — and, its id being remembered, never counted.
      final already = logged.any((l) =>
          !isImported(l.id) &&
          l.amountMl == d.amountMl &&
          l.time.difference(d.at).abs() <= duplicateWindow);
      if (already) continue;
      await WaterService.addWaterLogForDate(
        date: day,
        amountMl: d.amountMl,
        beverage: water,
        time: d.at,
        id: d.id,
        syncToHealth: false,
      );
      kept.add((date: day, id: d.id, amountMl: d.amountMl));
    }

    // What was kept before the switch went off is still remembered, so it does not
    // come back after an Undo; where the run got to is not written — the next
    // "on" starts from the first window, as setEnabled(false) promised. After
    // "Delete all data" nothing is: the ids held here are the ones just deleted.
    if (!wiped()) await _ledger.remember(prefs, seenList, newlySeen);
    if (stillWanted()) await prefs.setInt(_control.lastRunKey, at.millisecondsSinceEpoch);
    return WaterImportResult(kept);
  }

  /// [run], when the person has turned it on, the health store still allows it and
  /// it has not just run. Null when it did not run. Never throws.
  ///
  /// [force] skips the time gate (the switch has just been turned on).
  /// [hasPermission] stands in for the platform check in tests.
  static Future<WaterImportResult?> runIfEnabled({
    bool force = false,
    DateTime? now,
    Future<bool> Function()? hasPermission,
    Iterable<HealthDataPoint>? samples,
  }) =>
      _control.runIfEnabled(
        force: force,
        now: now,
        hasPermission:
            hasPermission ?? HealthDataService.instance.hasHydrationReadPermission,
        run: (at) => run(now: at, samples: samples),
      );

  /// Take back what [result] kept. The ids stay remembered, so none of it is
  /// fetched again.
  static Future<void> undo(WaterImportResult result) async {
    for (final l in result.logs) {
      await WaterService.removeWaterLogForDate(l.date, l.id);
    }
  }
}
