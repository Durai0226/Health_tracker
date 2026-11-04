import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'keyed_lock.dart';
import 'queue_signal.dart';

/// A tiny, isolate-safe hand-off queue for dose actions taken from a
/// notification's action buttons ("Take" / "Skip").
///
/// The notification action fires in a **background isolate** where Drift is not
/// available, so we cannot log the dose there directly. Instead the isolate
/// writes a lightweight intent to SharedPreferences ([enqueue]); the main
/// isolate [drain]s it, applies it (Drift + stock decrement) on next resume, and
/// [ack]s what landed. Pure SharedPreferences + JSON — safe to call from the
/// alarm isolate.
class DoseActionQueue {
  DoseActionQueue._();

  static const _key = 'pending_dose_actions';

  /// Kinds of queued action.
  static const actionTake = 'take';
  static const actionSkip = 'skip';

  /// How long an action that keeps failing to apply is kept.
  ///
  /// A failure is retried at every resume, because it may be a locked database
  /// that will not be locked next time. One that has failed for a week is not
  /// that — a record the app cannot apply — and keeping it would retry it, and log
  /// the failure, at every launch for ever, with nothing to ever take it out. Only
  /// an action that FAILS is given up on, and only once its slot is this old.
  static const Duration giveUpAfter = Duration(days: 7);

  /// Append a pending action (called from the background isolate).
  ///
  /// The moment of the tap is written with it ([tappedAt], now by default): it is
  /// when the person decided, which is what a later retry needs to tell a decision
  /// made after it from one made before.
  static Future<void> enqueue({
    required String medicineId,
    required DateTime scheduledTime,
    required String action,
    DateTime? tappedAt,
  }) =>
      KeyedLock.run(_key, () async {
        try {
          final prefs = await QueueSignal.freshPrefs();
          final list = prefs.getStringList(_key) ?? <String>[];
          list.add(jsonEncode({
            'medicineId': medicineId,
            'scheduledTime': scheduledTime.toIso8601String(),
            'action': action,
            'tappedAt': (tappedAt ?? DateTime.now()).toIso8601String(),
          }));
          await prefs.setStringList(_key, list);
          QueueSignal.notify();
          debugPrint(
              '✓ Queued dose action: $action for $medicineId @ $scheduledTime');
        } catch (e) {
          debugPrint('⚠️ enqueue dose action failed: $e');
        }
      });

  /// Read the queue WITHOUT clearing it (called by the main isolate on
  /// resume/open). The caller applies the actions and then [ack]s the ones that
  /// actually landed.
  ///
  /// It used to clear here, before the caller had written anything. A throw while
  /// applying — a locked database, a medicine row that would not read — or the
  /// process being killed half way through the list, and the doses were gone with
  /// nothing to show for them: no log, no queue entry, no message. A "Take" tapped
  /// on a notification is the one the person is least able to notice missing,
  /// because they never opened the app to see it — and for a medicine it is the
  /// record the adherence streak, the stock count and a doctor's report are made
  /// of. [WaterActionQueue] and [IntentQueue] were fixed the same way earlier.
  ///
  /// Malformed records are still pruned immediately: nothing will ever ack them,
  /// so leaving them in place would strand them in the queue forever. An action
  /// that fails to APPLY is not malformed and is kept: it is tried again on the
  /// next resume, and applying one is idempotent (the log id is the slot, and the
  /// stock change is the difference from what the slot already held).
  static Future<List<PendingDoseAction>> drain() =>
      KeyedLock.run(_key, _drain);

  static Future<List<PendingDoseAction>> _drain() async {
    try {
      final prefs = await QueueSignal.freshPrefs();
      final list = prefs.getStringList(_key) ?? const <String>[];
      if (list.isEmpty) return const [];
      final out = <PendingDoseAction>[];
      final keep = <String>[];
      for (final raw in list) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final t = DateTime.tryParse(m['scheduledTime']?.toString() ?? '');
          final id = m['medicineId']?.toString();
          final action = m['action']?.toString();
          if (t != null && id != null && action != null) {
            out.add(PendingDoseAction(
                medicineId: id,
                scheduledTime: t,
                action: action,
                // Absent on what an older build queued: then there is nothing to
                // compare a later decision against, and it is applied as it was.
                tappedAt: DateTime.tryParse(m['tappedAt']?.toString() ?? ''),
                raw: raw));
            keep.add(raw);
          }
        } catch (_) {}
      }
      if (keep.length != list.length) await _store(prefs, keep);
      return out;
    } catch (e) {
      debugPrint('⚠️ drain dose actions failed: $e');
      return const [];
    }
  }

  /// Forget the actions that were applied (or that there was nothing left to
  /// apply them to).
  ///
  /// Removes one stored record per acked action, so two identical taps need two
  /// acks and a tap that arrived DURING the drain survives to the next one.
  static Future<void> ack(List<PendingDoseAction> applied) {
    if (applied.isEmpty) return Future<void>.value();
    return KeyedLock.run(_key, () => _ack(applied));
  }

  static Future<void> _ack(List<PendingDoseAction> applied) async {
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
      debugPrint('⚠️ ack dose actions failed: $e');
    }
  }

  static Future<void> _store(SharedPreferences prefs, List<String> list) =>
      list.isEmpty ? prefs.remove(_key) : prefs.setStringList(_key, list);
}

@immutable
class PendingDoseAction {
  final String medicineId;
  final DateTime scheduledTime;
  final String action; // DoseActionQueue.actionTake | actionSkip

  /// When the person tapped — null for an action queued before this was kept.
  final DateTime? tappedAt;

  /// The exact stored record this was decoded from, so [DoseActionQueue.ack] can
  /// remove just the entries that were applied and leave the rest queued.
  final String? raw;

  const PendingDoseAction({
    required this.medicineId,
    required this.scheduledTime,
    required this.action,
    this.tappedAt,
    this.raw,
  });

  bool get isTake => action == DoseActionQueue.actionTake;
}
