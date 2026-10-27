import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/database/daos/period_dao.dart';

import '../models/cycle_phase.dart';
import '../models/cycle_prediction.dart';
import '../models/flow_intensity.dart';
import '../models/menstrual_cycle.dart';
import '../models/period_day.dart';
import '../models/period_settings.dart';
import 'cycle_predictor.dart';
import 'period_reminder_service.dart';
import 'new_period_check.dart';

/// Reactive menstrual-cycle service. Mirrors `WaterService`: an all-static class
/// with a static [ValueNotifier], an idempotent [init] guarded by
/// [_isInitialized], optimistic in-memory writes that notify by reassigning a
/// copied map, then async Drift persistence. Derived cycles are recomputed after
/// every mutation. All prediction is delegated to the pure [CyclePredictor].
class PeriodService {
  PeriodService._();

  static bool _isInitialized = false;

  /// Keyed by `yyyy-MM-dd` day id.
  static final ValueNotifier<Map<String, PeriodDay>> _daysNotifier =
      ValueNotifier<Map<String, PeriodDay>>({});

  static PeriodSettings _settings = PeriodSettings.defaults;
  static List<MenstrualCycle> _cycles = const [];

  static PeriodDao get _dao => db.AppDatabase.instance.periodDao;

  /// Reactive handle for the day map (drives the dashboard/calendar rebuilds).
  static ValueListenable<Map<String, PeriodDay>> listenToDays() =>
      _daysNotifier;

  // ---- Lifecycle ---------------------------------------------------------

  /// Idempotent load of persisted days + settings from Drift.
  static Future<void> init() async {
    if (_isInitialized) return;
    await reloadFromDb();
    _isInitialized = true;
    // Re-arm predictive period reminders on every startup (dates shift each
    // cycle; the planner no-ops when nothing is enabled).
    unawaited(PeriodReminderService.reschedule());
  }

  /// Re-read days and settings from Drift into the cache the UI renders from.
  ///
  /// Separate from [init] and deliberately NOT guarded by `_isInitialized`:
  /// cloud sync applies downloaded period days straight to the Drift table, so
  /// without a reload the calendar keeps showing the pre-sync month until the
  /// next cold launch. Mirrors `BiometricsService.reloadFromDb`.
  static Future<void> reloadFromDb() async {
    // Two different tables, and neither read uses the other's result — the
    // cycle derivation below needs only the days — so they go out together
    // instead of one after another. [init] is awaited before the first frame
    // from main's pre-runApp group, and production runs Drift on a background
    // isolate, so two awaited-in-turn reads are two sequential port round
    // trips there.
    //
    // Each load keeps its own try/catch rather than sharing one around the
    // pair: `Future.wait` rejects on the FIRST error and leaves the other
    // future's failure unobserved, so a settings read that fails would
    // otherwise also lose the logged days.
    await Future.wait([_loadDays(), _loadSettings()]);

    // Derive cycles in memory; don't write on a read-only launch.
    _recomputeCyclesInMemory();
  }

  /// The full day history, deliberately unranged: the calendar pages back to
  /// any month (`PeriodCalendarScreen._shiftMonth` has no floor) and the cycle
  /// history screen lists every derived cycle, both straight off this in-memory
  /// map with no second fetch. A window would silently blank older months and
  /// truncate the averages in [CycleStats].
  static Future<void> _loadDays() async {
    try {
      final rows = await _dao.getAllDays();
      final map = <String, PeriodDay>{};
      for (final r in rows) {
        map[r.id] = PeriodDay.fromRow(r);
      }
      _daysNotifier.value = map;
      debugPrint('✓ PeriodService loaded ${map.length} days from Drift');
    } catch (e) {
      debugPrint('⚠️ PeriodService day load failed (using empty): $e');
    }
  }

  static Future<void> _loadSettings() async {
    try {
      final s = await _dao.getSettings();
      if (s != null) {
        _settings = PeriodSettings.fromRow(s);
        debugPrint('✓ PeriodService loaded settings from Drift');
      }
    } catch (e) {
      debugPrint('⚠️ PeriodService settings load failed: $e');
    }
  }

  // ---- Days --------------------------------------------------------------

  PeriodDay? getDayById(String id) => _daysNotifier.value[id];

  static PeriodDay? getDay(DateTime date) =>
      _daysNotifier.value[PeriodDay.keyFor(date)];

  /// The current in-memory day map (unmodifiable view of the source of truth).
  static Map<String, PeriodDay> get days => _daysNotifier.value;

  /// Upsert a day. An empty day (no data) is treated as a clear/delete so the
  /// calendar doesn't accumulate blank rows.
  static Future<void> logDay(PeriodDay day) async {
    final map = Map<String, PeriodDay>.from(_daysNotifier.value);
    final existing = map[day.id];
    final merged = day.copyWith(
      createdAt: day.createdAt ?? existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!merged.hasData) {
      map.remove(day.id);
      _daysNotifier.value = map;
      await _deletePersist(day.id);
    } else {
      map[day.id] = merged;
      _daysNotifier.value = map; // optimistic notify
      await _persistDay(merged);
    }
    await _recomputeCycles();
    unawaited(PeriodReminderService.reschedule()); // prediction shifted
  }

  /// Set many days at once: a day mapped to a [PeriodDay] is written, one mapped
  /// to null is removed. The cycles are worked out and the reminders re-planned
  /// ONCE, not once a day — an import of a year of periods through [logDay] would
  /// have recomputed every cycle for each of a hundred days.
  ///
  /// All or nothing: the writes go in one transaction, so a failure leaves the
  /// stored days (and what the screens show) exactly as they were and is thrown to
  /// the caller, rather than being swallowed like [logDay]'s — an import that said
  /// "added 40 days" over nothing saved would be worse than one that says it
  /// could not. One commit also means one disk sync instead of one per day.
  static Future<void> setDays(Map<String, PeriodDay?> changes) async {
    if (changes.isEmpty) return;
    final stamp = DateTime.now();
    final write = <PeriodDay>[];
    final remove = <String>[];
    for (final e in changes.entries) {
      final day = e.value;
      if (day != null && day.hasData) {
        write.add(day.copyWith(
          createdAt: day.createdAt ?? _daysNotifier.value[e.key]?.createdAt ?? stamp,
          updatedAt: stamp,
        ));
      } else if (_daysNotifier.value.containsKey(e.key)) {
        remove.add(e.key);
      }
    }
    try {
      await db.AppDatabase.instance.transaction(() async {
        for (final d in write) {
          await _dao.upsertDay(d.toCompanion());
        }
        for (final id in remove) {
          await _dao.deleteDay(id);
        }
      });
    } catch (e) {
      debugPrint('⚠️ PeriodService setDays failed, nothing changed: $e');
      rethrow;
    }
    // Applied to the map as it is NOW, not as it was before the await: a day
    // logged while the transaction ran must not be dropped from memory.
    final map = Map<String, PeriodDay>.from(_daysNotifier.value);
    for (final d in write) {
      map[d.id] = d;
    }
    for (final id in remove) {
      map.remove(id);
    }
    _daysNotifier.value = map;
    await _recomputeCycles();
    unawaited(PeriodReminderService.reschedule());
  }

  /// How many days after the previous period began, if logging [flowIndex] on
  /// [date] would start a new period suspiciously soon (see [NewPeriodCheck]);
  /// null when there is nothing to ask. The sheet asks the user before saving.
  static int? newPeriodTooSoon(DateTime date, int flowIndex) =>
      NewPeriodCheck.tooSoon(
          days: _flowDays(), date: date, flowIndex: flowIndex);

  /// Set just the flow for [date], preserving anything else already logged.
  static Future<void> setFlow(DateTime date, FlowIntensity flow) async {
    final existing = getDay(date) ?? PeriodDay.empty(date);
    await logDay(existing.copyWith(flowIndex: flow.flowIndex));
  }

  static Future<void> deleteDay(String id) async {
    final map = Map<String, PeriodDay>.from(_daysNotifier.value);
    map.remove(id);
    _daysNotifier.value = map;
    await _deletePersist(id);
    await _recomputeCycles();
    unawaited(PeriodReminderService.reschedule()); // prediction shifted
  }

  // ---- Cycles / stats / prediction --------------------------------------

  /// Derived cycles, most recent last (ascending by start date).
  static List<MenstrualCycle> getCycles() => List.unmodifiable(_cycles);

  static CycleStats getStats() =>
      CyclePredictor.computeStats(CyclePredictor.deriveCycles(_flowDays()));

  static CyclePrediction getPrediction({DateTime? on}) {
    return CyclePredictor.predict(
      days: _flowDays(),
      on: on,
      typicalCycleLength: _settings.typicalCycleLength,
      typicalPeriodLength: _settings.typicalPeriodLength,
      lutealPhaseLength: _settings.lutealPhaseLength,
      pregnancyMode: _settings.trackingMode == TrackingMode.pregnancy,
      pregnancyStartDate: _settings.pregnancyStartDate,
    );
  }

  /// Phase of [date] resolved against the containing cycle (null with no data).
  static CyclePhase? phaseOn(DateTime date) {
    return CyclePredictor.phaseForDate(
      date,
      days: _flowDays(),
      typicalCycleLength: _settings.typicalCycleLength,
      typicalPeriodLength: _settings.typicalPeriodLength,
      lutealPhaseLength: _settings.lutealPhaseLength,
    );
  }

  // ---- Settings ----------------------------------------------------------

  static PeriodSettings getSettings() => _settings;

  static Future<void> saveSettings(PeriodSettings settings) async {
    _settings = settings;
    _notifyListeners();
    try {
      await _dao.saveSettings(settings.toCompanion());
    } catch (e) {
      debugPrint('⚠️ PeriodService save settings failed: $e');
    }
    // Tracking-mode / cycle-length changes move the predicted dates.
    unawaited(PeriodReminderService.reschedule());
  }

  // ---- Teardown ----------------------------------------------------------

  /// Remove every logged day, every derived cycle and the cycle settings, from
  /// the database and from memory, and take the reminders down with them.
  ///
  /// Rows are DELETED, not tombstoned: a tombstone keeps the dates and flow in
  /// the database, and this is for the person who wants it gone rather than
  /// hidden. Nothing can bring it back from elsewhere: period data has no cloud
  /// copy (the sync switch that would create one is not reachable from any
  /// screen), so there is no stale copy to be re-downloaded.
  static Future<void> deleteAllCycleData() async {
    final d = db.AppDatabase.instance;
    try {
      await d.delete(d.periodDays).go();
      await d.delete(d.menstrualCycles).go();
      await d.delete(d.periodSettingsTable).go();
    } catch (e) {
      debugPrint('⚠️ PeriodService delete all cycle data failed: $e');
      rethrow;
    }
    _daysNotifier.value = {};
    _cycles = const [];
    _settings = PeriodSettings.defaults;
    // Nothing left to predict from, so this cancels every reminder.
    await PeriodReminderService.reschedule();
  }

  /// Drop all in-memory state after a full data wipe (Drift rows removed
  /// elsewhere). Mirrors `WaterService.clearInMemory`.
  static void clearInMemory() {
    _daysNotifier.value = {};
    _cycles = const [];
    _settings = PeriodSettings.defaults;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    _isInitialized = false;
    _daysNotifier.value = {};
    _cycles = const [];
    _settings = PeriodSettings.defaults;
  }

  // ---- Internals ---------------------------------------------------------

  static List<FlowDay> _flowDays() =>
      _daysNotifier.value.values.map((d) => FlowDay(d.date, d.flowIndex)).toList();

  static void _notifyListeners() {
    _daysNotifier.value = Map<String, PeriodDay>.from(_daysNotifier.value);
  }

  static void _recomputeCyclesInMemory() {
    final derived = CyclePredictor.deriveCycles(_flowDays());
    _cycles = derived
        .map((c) => MenstrualCycle(
              id: 'cycle_${PeriodDay.keyFor(c.start)}',
              startDate: c.start,
              endDate: c.end,
              cycleLengthDays: c.cycleLengthDays,
              periodLengthDays: c.periodLengthDays,
            ))
        .toList();
  }

  static Future<void> _recomputeCycles() async {
    _recomputeCyclesInMemory();
    try {
      await _dao.replaceCycles(_cycles.map((c) => c.toCompanion()).toList());
    } catch (e) {
      debugPrint('⚠️ PeriodService recompute cycles failed: $e');
    }
  }

  static Future<void> _persistDay(PeriodDay d) async {
    try {
      await _dao.upsertDay(d.toCompanion());
    } catch (e) {
      debugPrint('⚠️ PeriodService persist day failed: $e');
    }
  }

  static Future<void> _deletePersist(String id) async {
    try {
      await _dao.deleteDay(id);
    } catch (e) {
      debugPrint('⚠️ PeriodService delete day failed: $e');
    }
  }
}
