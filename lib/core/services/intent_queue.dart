import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'keyed_lock.dart';
import 'queue_signal.dart';

/// Isolate-safe hand-off for something the person asked for from a notification
/// button.
///
/// The same shape, and for the same reason, as `WaterActionQueue` and
/// `DoseActionQueue`: a notification action fires in a **background isolate**
/// where Drift is not available, so what was asked for cannot be written there.
/// The isolate records the intent in SharedPreferences ([enqueue]); the main
/// isolate [drain]s it on the next resume, applies it, and [ack]s what landed.
///
/// Read-then-ack, not read-and-clear: anything that throws while applying leaves
/// the rest queued instead of losing it. Malformed records are the one thing
/// [drain] prunes itself, since nothing will ever ack them.
///
/// Each call takes its turn ([KeyedLock]): enqueue, drain and ack all read the
/// list and write it back across awaits, and two taps close together used to
/// read the same list, so the later write dropped the earlier tap.
class IntentQueue {
  const IntentQueue(this.key);

  final String key;

  /// Append [data] (JSON-encodable), stamped with the time of the tap.
  Future<void> enqueue(Map<String, dynamic> data, {required DateTime at}) =>
      KeyedLock.run(key, () async {
        try {
          final prefs = await QueueSignal.freshPrefs();
          final list = (prefs.getStringList(key) ?? const <String>[]).toList();
          list.add(jsonEncode({...data, 'at': at.toIso8601String()}));
          await prefs.setStringList(key, list);
          QueueSignal.notify();
        } catch (e) {
          debugPrint('⚠️ enqueue to $key failed: $e');
        }
      });

  /// Everything queued, oldest first, WITHOUT clearing it. A record that is not
  /// valid JSON, has no readable time, or fails [isValid] is dropped for good.
  Future<List<PendingIntent>> drain({
    bool Function(Map<String, dynamic> data)? isValid,
  }) =>
      KeyedLock.run(key, () => _drain(isValid));

  Future<List<PendingIntent>> _drain(
      bool Function(Map<String, dynamic> data)? isValid) async {
    try {
      final prefs = await QueueSignal.freshPrefs();
      final list = prefs.getStringList(key) ?? const <String>[];
      if (list.isEmpty) return const [];
      final out = <PendingIntent>[];
      final keep = <String>[];
      for (final raw in list) {
        try {
          final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          final at = DateTime.tryParse(m['at']?.toString() ?? '');
          if (at == null || (isValid != null && !isValid(m))) continue;
          // `.toLocal()`: a producer may hand over UTC, and the day an answer
          // belongs to is read off `.year/.month/.day`.
          out.add(PendingIntent(data: m, at: at.toLocal(), raw: raw));
          keep.add(raw);
        } catch (e) {
          debugPrint('⚠️ skipping a malformed record in $key: $e');
        }
      }
      if (keep.length != list.length) await _store(prefs, keep);
      return out;
    } catch (e) {
      debugPrint('⚠️ drain of $key failed: $e');
      return const [];
    }
  }

  /// Forget [applied]. One stored record per acked intent, so two identical taps
  /// need two acks and a tap that arrived DURING the drain survives to the next.
  Future<void> ack(Iterable<PendingIntent> applied) {
    if (applied.isEmpty) return Future<void>.value();
    return KeyedLock.run(key, () async {
      try {
        final prefs = await QueueSignal.freshPrefs();
        final list = (prefs.getStringList(key) ?? const <String>[]).toList();
        for (final a in applied) {
          list.remove(a.raw);
        }
        await _store(prefs, list);
      } catch (e) {
        debugPrint('⚠️ ack of $key failed: $e');
      }
    });
  }

  Future<void> _store(SharedPreferences prefs, List<String> list) =>
      list.isEmpty ? prefs.remove(key) : prefs.setStringList(key, list);
}

/// One queued intent: what was asked for, when, and the stored record it came
/// from (so [IntentQueue.ack] removes exactly that one).
class PendingIntent {
  const PendingIntent({required this.data, required this.at, required this.raw});

  final Map<String, dynamic> data;

  /// When the button was tapped, in LOCAL time.
  final DateTime at;

  final String raw;
}
