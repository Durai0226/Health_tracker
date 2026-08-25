/// State for the Connected-devices screen.
///
/// ## Why this exists as a controller at all
///
/// The screen it replaces did four sequential awaits and then **one**
/// `setState`. Only one of those awaits was time-bounded. So a hung or failing
/// platform probe discarded the database rows too — and the database read
/// resolves in about a millisecond.
///
/// That is not a cosmetic flash. Measured: with a real source row written
/// through the DAO, pumping the old screen for ten seconds of fake time rendered
/// zero switches and the words "Nothing connected yet". The probe never
/// completes under test, the six-second timeout throws into a bare `catch`, and
/// the single `setState` never runs. The same shape means a genuinely slow
/// Health Connect call on a real device shows the user an empty list of devices
/// they demonstrably have.
///
/// So [load] emits **twice, deliberately** — rows first, probes second — and a
/// test pins that ordering so nobody folds it back into one `Future.wait`.
///
/// ## Seams
///
/// Function-typed with real defaults, mirroring
/// `BiometricsService.syncFromHealth({samples})`. This repo has no mocking
/// framework, and that is how anything here becomes testable.
library;

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/services/background_health_sync_service.dart';
import '../../../core/services/health_data_service.dart';
import '../../../core/services/health_sync_queue.dart';
import '../models/health_source.dart';
import 'biometrics_service.dart';

/// How far the load has got.
///
/// [rowsOnly] is a real, renderable state, not a transitional one: the registry
/// rows are historical facts and are worth showing immediately, whatever the
/// platform later says.
enum DevicesPhase { loading, rowsOnly, complete }

@immutable
class ConnectedDevicesState {
  final DevicesPhase phase;

  /// Null until the first read completes — distinct from an empty list, which
  /// means "we looked and there is nothing". The old screen used `const []` for
  /// both and rendered the empty state before it had asked.
  final List<HealthSource>? sources;

  /// Null while unprobed. Note the deliberate absence of a
  /// `HealthAvailability.notDetermined` default: that value means "we can ask,
  /// the user hasn't decided", which is a claim this screen has not earned
  /// before the probe returns.
  final HealthAvailability? availability;

  /// Whether the probe itself failed, as opposed to answering unfavourably.
  /// The old code collapsed both into `notDetermined`.
  final bool probeFailed;

  final bool backgroundAvailable;
  final bool backgroundEnabled;

  /// A pending "the worker switched itself off" notice, with its reason.
  final ({SyncDisableReason reason, DateTime at})? selfDisabled;

  final DateTime? lastRunAt;
  final String? lastError;

  /// Rows whose write is in flight. Only these disable their own switch — the
  /// screen never greys out en masse.
  final Set<String> pendingIds;

  /// Set only when the DATABASE read failed. A failed platform probe is not an
  /// error state: the rows are still worth showing.
  final Object? error;

  const ConnectedDevicesState({
    this.phase = DevicesPhase.loading,
    this.sources,
    this.availability,
    this.probeFailed = false,
    this.backgroundAvailable = false,
    this.backgroundEnabled = false,
    this.selfDisabled,
    this.lastRunAt,
    this.lastError,
    this.pendingIds = const {},
    this.error,
  });

  bool get isLoading => phase != DevicesPhase.complete;

  /// True only once a read has actually completed and found nothing.
  bool get isEmpty => sources != null && sources!.isEmpty;

  ConnectedDevicesState copyWith({
    DevicesPhase? phase,
    List<HealthSource>? sources,
    HealthAvailability? availability,
    bool? probeFailed,
    bool? backgroundAvailable,
    bool? backgroundEnabled,
    ({SyncDisableReason reason, DateTime at})? selfDisabled,
    bool clearSelfDisabled = false,
    DateTime? lastRunAt,
    String? lastError,
    bool clearLastError = false,
    Set<String>? pendingIds,
    Object? error,
    bool clearError = false,
  }) =>
      ConnectedDevicesState(
        phase: phase ?? this.phase,
        sources: sources ?? this.sources,
        availability: availability ?? this.availability,
        probeFailed: probeFailed ?? this.probeFailed,
        backgroundAvailable: backgroundAvailable ?? this.backgroundAvailable,
        backgroundEnabled: backgroundEnabled ?? this.backgroundEnabled,
        selfDisabled:
            clearSelfDisabled ? null : (selfDisabled ?? this.selfDisabled),
        lastRunAt: lastRunAt ?? this.lastRunAt,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        pendingIds: pendingIds ?? this.pendingIds,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Seams, all defaulted to the real thing.
typedef ReadSources = Future<List<HealthSource>> Function();
typedef ProbeAvailability = Future<HealthAvailability> Function();
typedef ProbeBackgroundAvailable = Future<bool> Function();
typedef ReadBackgroundEnabled = Future<bool> Function();
typedef WriteSourceEnabled = Future<void> Function(String id, bool enabled);
typedef WriteSourcePriority = Future<void> Function(String id, int priority);
typedef RunSync = Future<int> Function();
typedef ReloadAggregation = Future<void> Function();

class ConnectedDevicesController extends ValueNotifier<ConnectedDevicesState> {
  final ReadSources _readSources;
  final ProbeAvailability _probeAvailability;
  final ProbeBackgroundAvailable _probeBackgroundAvailable;
  final ReadBackgroundEnabled _readBackgroundEnabled;
  final WriteSourceEnabled _writeEnabled;
  final WriteSourcePriority _writePriority;
  final RunSync _sync;
  final ReloadAggregation _reload;
  final Future<void> Function(bool) _setBackground;

  /// How long to wait on the platform before giving up on it. The rows are
  /// already on screen by then, so this bounds an inconvenience rather than a
  /// blank page.
  final Duration probeTimeout;

  ConnectedDevicesController({
    ReadSources? readSources,
    ProbeAvailability? probeAvailability,
    ProbeBackgroundAvailable? probeBackgroundAvailable,
    ReadBackgroundEnabled? readBackgroundEnabled,
    WriteSourceEnabled? writeSourceEnabled,
    WriteSourcePriority? writeSourcePriority,
    RunSync? runSync,
    ReloadAggregation? reloadAggregation,
    Future<void> Function(bool)? setBackground,
    this.probeTimeout = const Duration(seconds: 6),
  })  : _readSources = readSources ?? _defaultReadSources,
        _probeAvailability =
            probeAvailability ?? HealthDataService.instance.availability,
        _probeBackgroundAvailable = probeBackgroundAvailable ??
            HealthDataService.instance.isBackgroundReadAvailable,
        _readBackgroundEnabled = readBackgroundEnabled ?? HealthSyncQueue.isEnabled,
        _writeEnabled = writeSourceEnabled ?? _defaultWriteEnabled,
        _writePriority = writeSourcePriority ?? _defaultWritePriority,
        _sync = runSync ?? BiometricsService.syncFromHealth,
        _reload = reloadAggregation ?? BiometricsService.reloadFromDb,
        _setBackground = setBackground ?? _defaultSetBackground,
        super(const ConnectedDevicesState());

  static Future<List<HealthSource>> _defaultReadSources() async {
    final rows = await db.AppDatabase.instance.biometricsDao.getSources();
    return rows.map(HealthSource.fromRow).toList();
  }

  static Future<void> _defaultWriteEnabled(String id, bool enabled) =>
      db.AppDatabase.instance.biometricsDao.setSourceEnabled(id, enabled);

  static Future<void> _defaultWritePriority(String id, int priority) =>
      db.AppDatabase.instance.biometricsDao.setSourcePriority(id, priority);

  static Future<void> _defaultSetBackground(bool wanted) async {
    if (wanted) {
      await BackgroundHealthSyncService.instance.enable();
    } else {
      await BackgroundHealthSyncService.instance.disable();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit(ConnectedDevicesState next) {
    if (_disposed) return;
    value = next;
  }

  /// Read the local rows, then the platform. Emits after each.
  ///
  /// The split is the whole design. A platform probe that hangs or throws must
  /// not be able to take the rows down with it, and the rows are what the screen
  /// is actually for.
  Future<void> load() async {
    try {
      final rows = await _readSources();
      _emit(value.copyWith(
        phase: DevicesPhase.rowsOnly,
        sources: rows,
        clearError: true,
      ));
    } catch (e) {
      // A database failure IS an error state — unlike a probe failure, there is
      // nothing left to show and retrying is the only sensible offer.
      _emit(value.copyWith(phase: DevicesPhase.complete, error: e));
      return;
    }

    await _probe();
  }

  Future<void> _probe() async {
    HealthAvailability? availability;
    var probeFailed = false;
    try {
      availability = await _probeAvailability().timeout(probeTimeout);
    } catch (_) {
      // Recorded as its own fact rather than folded into `notDetermined`.
      // "The probe broke" and "the user has not decided yet" are different
      // things to tell somebody.
      probeFailed = true;
    }

    var bgAvailable = false;
    var bgEnabled = false;
    ({SyncDisableReason reason, DateTime at})? selfDisabled;
    DateTime? lastRunAt;
    String? lastError;
    try {
      bgAvailable = await _probeBackgroundAvailable().timeout(probeTimeout);
      bgEnabled = await _readBackgroundEnabled();
      selfDisabled = await HealthSyncQueue.selfDisable();
      lastRunAt = await HealthSyncQueue.lastRunAt();
      lastError = await HealthSyncQueue.lastError();
    } catch (_) {
      // Background sync is a secondary concern on this screen; failing to read
      // its status must not disturb the device list.
    }

    _emit(value.copyWith(
      phase: DevicesPhase.complete,
      availability: availability,
      probeFailed: probeFailed,
      backgroundAvailable: bgAvailable,
      backgroundEnabled: bgEnabled,
      selfDisabled: selfDisabled,
      clearSelfDisabled: selfDisabled == null,
      lastRunAt: lastRunAt,
      lastError: lastError,
      clearLastError: lastError == null,
    ));
  }

  /// Turn one source on or off.
  ///
  /// Optimistic, then persisted, then **re-aggregated and re-read**. That last
  /// step is not decoration: `BiometricsService.reloadFromDb`'s own docstring
  /// names "the Connected-devices screen after a source is toggled off" as one
  /// of its two legitimate callers, and it had zero call sites. Without it the
  /// in-memory notifiers keep serving an aggregation computed while the source
  /// was still enabled, so Heart and Workouts go on showing the switched-off
  /// device's numbers until something else happens to reload.
  Future<bool> setEnabled(HealthSource source, bool enabled) async {
    final before = value.sources;
    if (before == null) return false;

    _emit(value.copyWith(
      sources: [
        for (final s in before)
          s.id == source.id ? s.copyWith(enabled: enabled) : s,
      ],
      pendingIds: {...value.pendingIds, source.id},
    ));

    var ok = true;
    try {
      await _writeEnabled(source.id, enabled);
      await _sync();
      await _reload();
    } catch (_) {
      // Only the Drift write can actually throw here — syncFromHealth catches
      // everything and returns 0 — so this is a genuine persistence failure and
      // the switch must go back where the data says.
      ok = false;
      _emit(value.copyWith(sources: before));
    }

    _emit(value.copyWith(
      pendingIds: {...value.pendingIds}..remove(source.id),
    ));
    return ok;
  }

  /// Pin one source, or clear the pin.
  ///
  /// A radio, not a checkbox: exactly one source may hold priority 1 and every
  /// other is reset to 0. Two pinned sources would tie at the top tier of
  /// `HealthSourceRegistry.wins` and fall through to raw sample count — a
  /// control that looks like it works and does not.
  Future<bool> setPinned(HealthSource source, bool pinned) async {
    final before = value.sources;
    if (before == null) return false;

    _emit(value.copyWith(
      sources: [
        for (final s in before)
          s.copyWith(priority: s.id == source.id && pinned ? 1 : 0),
      ],
      pendingIds: {...value.pendingIds, source.id},
    ));

    var ok = true;
    try {
      for (final s in before) {
        final want = s.id == source.id && pinned ? 1 : 0;
        if (s.priority != want) await _writePriority(s.id, want);
      }
      await _sync();
      await _reload();
    } catch (_) {
      ok = false;
      _emit(value.copyWith(sources: before));
    }

    _emit(value.copyWith(
      pendingIds: {...value.pendingIds}..remove(source.id),
    ));
    return ok;
  }

  Future<void> setBackgroundSync(bool wanted) async {
    await _setBackground(wanted);
    // Read the truth back rather than assuming: enabling sends the user out to
    // the Health Connect sheet, and the answer is whatever they chose there.
    final enabled = await _readBackgroundEnabled();
    final selfDisabled = await HealthSyncQueue.selfDisable();
    _emit(value.copyWith(
      backgroundEnabled: enabled,
      selfDisabled: selfDisabled,
      clearSelfDisabled: selfDisabled == null,
    ));
  }

  /// Dismiss the self-disable notice without turning sync back on.
  Future<void> dismissSelfDisableNotice() async {
    await HealthSyncQueue.clearSelfDisable();
    _emit(value.copyWith(clearSelfDisabled: true));
  }
}
