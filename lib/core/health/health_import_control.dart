import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What an automatic import from the health store does the same way, whatever it
/// imports: the switch, where a read starts, the gate that decides whether a run
/// begins, and one run at a time.
///
/// Blood pressure and sugar, and drinks, each had their own copy of this, and the
/// copies drifted apart — a fix to the permission gate or to the single-flight had
/// to be made in both, and one could be missed. What an import reads, and what it
/// keeps, stays with the import; this is only the scaffolding around it.
class HealthImportControl {
  HealthImportControl({
    required this.name,
    required this.enabledKey,
    required this.lastRunKey,
    required this.firstLookback,
    required this.overlap,
    this.minInterval = const Duration(minutes: 15),
  }) {
    _all.add(this);
  }

  /// Every import there is, so that a wipe of all data can stop runs it cannot
  /// name. See [cancelAllRuns].
  static final List<HealthImportControl> _all = [];

  /// What the import is called in the log.
  final String name;

  /// The preference the switch is kept under.
  final String enabledKey;

  /// The preference the end of the last run is kept under.
  final String lastRunKey;

  /// How far back the first run reads.
  final Duration firstLookback;

  /// Later runs start this far before the last one, so a sample that reached the
  /// health store late is still found. The seen ids make the overlap free.
  final Duration overlap;

  /// The least time between two automatic runs.
  final Duration minInterval;

  // ---- the switch ------------------------------------------------------------

  Future<bool> isEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    // Before the first await: a run that is mid-read asks [watchSwitch] the moment
    // the read returns, and must already find the switch off.
    if (!enabled) _cancelRuns();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, enabled);
    // A fresh start reads the whole first window again; what was already seen is
    // still remembered, so nothing comes back twice.
    if (!enabled) await prefs.remove(lastRunKey);
  }

  // ---- the switch turned off in the middle of a run ----------------------------

  int _cancels = 0;

  void _cancelRuns() => _cancels++;

  /// Stop every run in flight, in every import. See [wipeBegan].
  static void cancelAllRuns() {
    for (final control in _all) {
      control._cancelRuns();
    }
  }

  // ---- "Delete all data" -------------------------------------------------------

  /// How many wipes are under way. A count, not a flag: two can overlap — the
  /// settings wipe and an account deletion — and the first to end must not let runs
  /// begin while the second is still deleting.
  static int _wipesRunning = 0;
  static int _wipes = 0;

  /// "Delete all data" is starting: every run in flight is stopped, and none begins
  /// until [wipeEnded]. The wipe removes the switches itself and so never goes
  /// through [setEnabled].
  ///
  /// At the START of it, not at the point it gets to the imports' preferences: a
  /// run that is mid-read would otherwise go on saving into the tables the wipe has
  /// already emptied, and one that starts in the middle would read the store into
  /// them.
  static void wipeBegan() {
    _wipesRunning++;
    _wipes++;
    cancelAllRuns();
  }

  static void wipeEnded() {
    if (_wipesRunning > 0) _wipesRunning--;
  }

  /// Whether "Delete all data" has begun since this was called.
  ///
  /// A run that finds its switch turned off keeps the ids it has dealt with, so none
  /// of it comes back after an Undo. A run that finds everything wiped must keep
  /// NOTHING: the list of ids it holds is the one that was deleted, and writing it
  /// back would make the next "on" skip everything the store still has.
  bool Function() watchWipe() {
    final wipesWhenItBegan = _wipes;
    return () => _wipes != wipesWhenItBegan;
  }

  /// A run's way of asking "do they still want this?". Call it when the run
  /// begins, and ask the function it returns before each step that writes: it
  /// answers false once the switch has been turned off since.
  ///
  /// A read of the health store takes seconds, and turning the switch off does not
  /// wait for it. The run that was mid-read went on to save what it found, then
  /// wrote down where it had got to — after the person had said no, and in front of
  /// the next "on", which then began from the middle of the window instead of the
  /// start of it.
  ///
  /// This is not "is the switch on": a run called directly, with the switch never
  /// turned on, is not cancelled by that.
  bool Function() watchSwitch() {
    final cancelsWhenItBegan = _cancels;
    return () => _cancels == cancelsWhenItBegan;
  }

  // ---- where a read starts ---------------------------------------------------

  /// [firstLookback] back the first time, otherwise [overlap] before the last run.
  DateTime windowStart({required int? lastRunMs, required DateTime now}) =>
      lastRunMs == null
          ? now.subtract(firstLookback)
          : DateTime.fromMillisecondsSinceEpoch(lastRunMs).subtract(overlap);

  // ---- one run at a time -----------------------------------------------------

  Future<Object?>? _running;

  /// How many times the switch had been turned off when [_running] began.
  int _runningCancels = 0;

  /// [start], unless a run is already under way — then that run's answer.
  ///
  /// The app starts a run on its first frame and another on the resume that
  /// follows it, and the gate is only written at the END of a run — so the second
  /// began while the first was still reading, saw the same ledger and the same
  /// samples, and, with neither having written yet, found nothing already kept. A
  /// caller that arrives mid-run gets that run's answer instead.
  ///
  /// Unless that run is stopping: the switch was turned off while it read, and has
  /// since been turned on again, which is a request for a read of its own. Handed
  /// the stopped run's answer, "nothing found" on the screen would have been the
  /// answer to a question the person did not ask. That caller waits for it to
  /// finish and then starts.
  Future<T> singleFlight<T>(Future<T> Function() start) {
    final inFlight = _running;
    if (inFlight != null) {
      if (_runningCancels == _cancels) return inFlight as Future<T>;
      return inFlight.then((_) => singleFlight<T>(start),
          onError: (Object _) => singleFlight<T>(start));
    }
    _runningCancels = _cancels;
    final started = start().whenComplete(() => _running = null);
    _running = started;
    return started;
  }

  // ---- whether a run begins --------------------------------------------------

  /// [run], when the person has turned the import on, the health store still
  /// allows it and it has not just run. Null when it did not run. Never throws: a
  /// health store that is slow, missing or refusing must not get in the way of
  /// opening the app.
  ///
  /// [force] skips the time gate (the switch has just been turned on).
  Future<T?> runIfEnabled<T>({
    required bool force,
    required DateTime? now,
    required Future<bool> Function() hasPermission,
    required Future<T> Function(DateTime at) run,
  }) async {
    try {
      if (_wipesRunning > 0) return null;
      if (!await isEnabled()) return null;
      final at = now ?? clock.now();
      if (!force) {
        final last = (await SharedPreferences.getInstance()).getInt(lastRunKey);
        if (last != null &&
            at.difference(DateTime.fromMillisecondsSinceEpoch(last)) < minInterval) {
          return null;
        }
      }
      if (!await hasPermission()) return null;
      return await run(at);
    } catch (e) {
      debugPrint('⚠️ $name from the health store failed: $e');
      return null;
    }
  }
}
