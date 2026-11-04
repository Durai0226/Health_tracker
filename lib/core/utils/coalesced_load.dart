import 'dart:async';

/// One load at a time, however often it is asked for.
///
/// A screen that follows a store reloads on every change, and a burst of changes —
/// a few hundred readings saved one after another — started a reload for each, all
/// overlapping, each reading and rebuilding the whole list. This runs the load
/// once, and whatever is asked for while it runs becomes ONE more run after it,
/// which reads everything that changed in the meantime. However long the burst,
/// there is never more than the load under way and one waiting behind it.
class CoalescedLoad {
  CoalescedLoad(this._load, {bool Function()? canContinue})
      : _canContinue = canContinue ?? (() => true);

  final Future<void> Function() _load;

  /// Asked before a waiting run starts: false once there is nothing left to show
  /// it to (a screen that has gone).
  final bool Function() _canContinue;

  Future<void>? _running;
  bool _again = false;

  /// Ask for a load. The future completes once a load that BEGAN after this call
  /// has finished, so what was asked about has been read.
  Future<void> call() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    // Held in a Completer, set BEFORE the loop starts: the loop runs synchronously up
    // to its first await and clears [_running] when it ends, so a load that threw
    // before awaiting anything (a plain callback, not an async one) finished — and
    // cleared it — before `_running = _loop()` could assign, leaving a future that is
    // already complete in `_running` for good. Every later call then took it for a load
    // in progress and none ever ran again.
    final done = Completer<void>();
    _running = done.future;
    _loop().then(done.complete, onError: done.completeError);
    return done.future;
  }

  /// Whether a load is under way.
  bool get isRunning => _running != null;

  /// Completes when the load under way, and the one waiting behind it, have
  /// finished — at once if none is running. For a caller that has just changed
  /// the store, whose own change started the load: it needs the result, not a
  /// second load.
  Future<void> get settled => _running ?? Future<void>.value();

  /// A load that throws does not take the one waiting behind it with it: what was
  /// asked for while it ran is still owed, and it is exactly what a failed load did
  /// not show. The pass behind it runs; the caller hears of a failure only if the
  /// LAST pass failed, since a later pass that succeeded has read everything the
  /// failed one missed.
  Future<void> _loop() async {
    Object? error;
    StackTrace? stack;
    var failed = false;
    try {
      do {
        _again = false;
        try {
          await _load();
          failed = false;
        } catch (e, st) {
          failed = true;
          error = e;
          stack = st;
        }
      } while (_again && _canContinue());
    } finally {
      _running = null;
    }
    if (failed) Error.throwWithStackTrace(error!, stack!);
  }
}
