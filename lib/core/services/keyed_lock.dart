import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs async bodies one at a time per key, in the order they were asked for.
///
/// A notification-button queue is written by read, modify, write across awaits
/// (reload the preferences, read the list, add to it, store it). Two of those in
/// flight in one isolate each read the list before the other had stored its
/// change, and the second store replaced the first — a button tapped twice in
/// quick succession kept only the second tap. Taking a turn per queue closes
/// that. Isolates do not share statics, so this orders the calls of the isolate
/// it runs in, which is where the interleaving was.
class KeyedLock {
  const KeyedLock._();

  static final Map<String, Future<void>> _tails = {};

  /// Keys with a call still waiting or running.
  @visibleForTesting
  static int get activeKeys => _tails.length;

  /// Run [body] once every earlier call for [key] has finished, and return what
  /// it returns. A body that throws still hands the turn on.
  static Future<T> run<T>(String key, Future<T> Function() body) {
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) => body());
    final tail = result.then<void>((_) {}, onError: (_) {});
    _tails[key] = tail;
    // Forget the key once its queue has emptied, so the map does not grow with
    // every key ever used.
    tail.whenComplete(() {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    return result;
  }
}
