import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny, isolate-safe hand-off queue for dose actions taken from a
/// notification's action buttons ("Take" / "Skip").
///
/// The notification action fires in a **background isolate** where Drift is not
/// available, so we cannot log the dose there directly. Instead the isolate
/// writes a lightweight intent to SharedPreferences ([enqueue]); the main
/// isolate [drain]s and applies it (Drift + stock decrement) on next resume.
/// Pure SharedPreferences + JSON — safe to call from the alarm isolate.
class DoseActionQueue {
  DoseActionQueue._();

  static const _key = 'pending_dose_actions';

  /// Kinds of queued action.
  static const actionTake = 'take';
  static const actionSkip = 'skip';

  /// Append a pending action (called from the background isolate).
  static Future<void> enqueue({
    required String medicineId,
    required DateTime scheduledTime,
    required String action,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? <String>[];
      list.add(jsonEncode({
        'medicineId': medicineId,
        'scheduledTime': scheduledTime.toIso8601String(),
        'action': action,
      }));
      await prefs.setStringList(_key, list);
      debugPrint('✓ Queued dose action: $action for $medicineId @ $scheduledTime');
    } catch (e) {
      debugPrint('⚠️ enqueue dose action failed: $e');
    }
  }

  /// Read AND clear the queue (called by the main isolate on resume/open).
  static Future<List<PendingDoseAction>> drain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? const <String>[];
      if (list.isEmpty) return const [];
      await prefs.remove(_key);
      final out = <PendingDoseAction>[];
      for (final raw in list) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final t = DateTime.tryParse(m['scheduledTime']?.toString() ?? '');
          final id = m['medicineId']?.toString();
          final action = m['action']?.toString();
          if (t != null && id != null && action != null) {
            out.add(PendingDoseAction(
                medicineId: id, scheduledTime: t, action: action));
          }
        } catch (_) {}
      }
      return out;
    } catch (e) {
      debugPrint('⚠️ drain dose actions failed: $e');
      return const [];
    }
  }
}

@immutable
class PendingDoseAction {
  final String medicineId;
  final DateTime scheduledTime;
  final String action; // DoseActionQueue.actionTake | actionSkip
  const PendingDoseAction({
    required this.medicineId,
    required this.scheduledTime,
    required this.action,
  });

  bool get isTake => action == DoseActionQueue.actionTake;
}
