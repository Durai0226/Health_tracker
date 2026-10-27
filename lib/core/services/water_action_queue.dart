import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'keyed_lock.dart';
import 'queue_signal.dart';

/// Isolate-safe hand-off queue for drinks logged straight from a water
/// reminder's action button.
///
/// Same shape, and for the same reason, as [DoseActionQueue]: a notification
/// action fires in a **background isolate** where Drift is not available, so
/// the drink cannot be written there. The isolate records a lightweight intent
/// in SharedPreferences ([enqueue]); the main isolate [drain]s and applies it on
/// the next resume.
///
/// Why this matters more for water than for anything else in the app: the whole
/// competitive argument for a hydration tracker is that logging is frictionless.
/// Every other app in the category lets you log from the notification, the
/// widget or the watch. Ours made you open the app, find the tab and tap a tile
/// — so the reminder that was supposed to make you drink instead made you do
/// paperwork, and people stop.
class WaterActionQueue {
  WaterActionQueue._();

  static const _key = 'pending_water_actions';

  /// Volume logged by the notification's quick-add button.
  ///
  /// 250 ml is the category's canonical serving (it is also the value Samsung
  /// Health expects in `HealthConstants.WaterIntake.UNIT_AMOUNT`, so a glass
  /// renders as one glass rather than a fraction).
  static const int defaultQuickAddMl = 250;

  /// Append a pending drink (called from the background isolate).
  static Future<void> enqueue({
    required int amountMl,
    required DateTime at,
  }) =>
      KeyedLock.run(_key, () async {
        try {
          final prefs = await QueueSignal.freshPrefs();
          final list = prefs.getStringList(_key) ?? <String>[];
          list.add(jsonEncode({
            'amountMl': amountMl,
            'at': at.toIso8601String(),
          }));
          await prefs.setStringList(_key, list);
          QueueSignal.notify();
          debugPrint('✓ Queued water action: ${amountMl}ml @ $at');
        } catch (e) {
          debugPrint('⚠️ enqueue water action failed: $e');
        }
      });

  /// Read the queue WITHOUT clearing it. The caller applies the entries and
  /// then [ack]s the ones that actually landed.
  ///
  /// It used to clear here, before the caller had written anything. Any throw
  /// while applying — a locked database, a day that could not be read — and the
  /// drinks were gone with nothing to show for them: no log, no queue entry, no
  /// message. A drink logged from a notification is the one the user is least
  /// able to notice missing, because they never opened the app to see it.
  ///
  /// Malformed records are still pruned immediately: nothing will ever ack them,
  /// so leaving them in place would strand them in the queue forever.
  static Future<List<PendingWaterAction>> drain() =>
      KeyedLock.run(_key, _drain);

  static Future<List<PendingWaterAction>> _drain() async {
    try {
      final prefs = await QueueSignal.freshPrefs();
      final list = prefs.getStringList(_key) ?? const <String>[];
      if (list.isEmpty) return const [];
      final out = <PendingWaterAction>[];
      final keep = <String>[];
      for (final raw in list) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final at = DateTime.tryParse(m['at']?.toString() ?? '');
          final ml = (m['amountMl'] as num?)?.toInt();
          // Drop anything malformed rather than failing the whole drain — one
          // bad entry must not strand every other queued drink forever.
          if (at != null && ml != null && ml > 0) {
            // `.toLocal()` because a producer may hand us UTC: the iOS widget
            // extension stamps its taps with `ISO8601DateFormatter()`, which is
            // always Zulu. The day a drink belongs to is read off `.year/.month/
            // .day`, so a +250 tapped at 02:00 in Asia/Kolkata (20:30Z the day
            // before) was filed against YESTERDAY — counted towards yesterday's
            // goal, shown on the timeline at 20:30, with today's dial still 0.
            out.add(PendingWaterAction(
                amountMl: ml, at: at.toLocal(), raw: raw));
            keep.add(raw);
          }
        } catch (e) {
          debugPrint('⚠️ skipping malformed queued water action: $e');
        }
      }
      if (keep.length != list.length) {
        await _store(prefs, keep);
      }
      return out;
    } catch (e) {
      debugPrint('⚠️ drain water actions failed: $e');
      return const [];
    }
  }

  /// Forget the entries that were successfully written to Drift.
  ///
  /// Removes one stored record per acked action, so two identical taps need two
  /// acks and a tap that arrived DURING the drain survives to the next one.
  static Future<void> ack(List<PendingWaterAction> applied) {
    if (applied.isEmpty) return Future<void>.value();
    return KeyedLock.run(_key, () => _ack(applied));
  }

  static Future<void> _ack(List<PendingWaterAction> applied) async {
    try {
      final prefs = await QueueSignal.freshPrefs();
      final list = (prefs.getStringList(_key) ?? const <String>[]).toList();
      if (list.isEmpty) return;
      for (final action in applied) {
        final raw = action.raw;
        if (raw != null) list.remove(raw);
      }
      await _store(prefs, list);
    } catch (e) {
      debugPrint('⚠️ ack water actions failed: $e');
    }
  }

  static Future<void> _store(SharedPreferences prefs, List<String> list) =>
      list.isEmpty ? prefs.remove(_key) : prefs.setStringList(_key, list);
}

/// One drink logged from a notification, waiting to be written to Drift.
class PendingWaterAction {
  final int amountMl;

  /// When the button was tapped, in LOCAL time — see the note in [drain].
  final DateTime at;

  /// The exact stored record this was decoded from, so [WaterActionQueue.ack]
  /// can remove just the entries that were applied and leave the rest queued.
  final String? raw;

  const PendingWaterAction({
    required this.amountMl,
    required this.at,
    this.raw,
  });
}
