import 'package:flutter/foundation.dart';

import '../../../core/services/notification_service.dart';

/// The seam between the Focus timer and the OS notification scheduler.
///
/// This interface is the whole reason the background-completion notification
/// could finally be written. The objection that blocked it — "scheduled delivery
/// cannot be verified headlessly" — was true but too broad: *delivery* is an OS
/// behaviour, and it is not where the defects live. The defects live in the
/// decision of **when to arm and when to disarm**, and that is ordinary logic
/// this makes directly assertable.
///
/// Deliberately narrow, exactly like `AudioEngine`: two methods, no state, no
/// notion of what a focus session is. A fake that records `(id, at, title, body)`
/// is then a dozen lines.
abstract interface class FocusSessionAlarm {
  /// Ask the OS to notify at [at]. Arming the same [id] twice replaces.
  Future<void> arm({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Withdraw a pending notification. Must be safe to call when nothing is armed.
  Future<void> disarm(int id);
}

/// The production implementation: a one-shot local notification on
/// `focus_channel`.
///
/// Nothing here starts an isolate, calls `initialize()` on
/// `flutter_local_notifications`, or registers a background tap handler — and it
/// must stay that way. That plugin stores exactly ONE app-wide background
/// callback handle, which the main isolate and the medicine alarm isolate already
/// contend for; whichever called `initialize()` last wins. A third claimant would
/// silently break dose actions. `focus_guards_test` pins this.
class NotificationFocusSessionAlarm implements FocusSessionAlarm {
  const NotificationFocusSessionAlarm();

  @override
  Future<void> arm({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) =>
      NotificationService()
          .scheduleFocusCompletion(id: id, at: at, title: title, body: body);

  @override
  Future<void> disarm(int id) =>
      NotificationService().cancelFocusCompletion(id);
}

/// Records calls instead of making them.
///
/// Lives beside the production implementation rather than in `test/` so the two
/// cannot drift: adding a method to the interface breaks this file, in `lib`,
/// where it is impossible to miss.
@visibleForTesting
class RecordingFocusSessionAlarm implements FocusSessionAlarm {
  final List<({int id, DateTime at, String title, String body})> armed = [];
  final List<int> disarmed = [];

  /// What is currently armed, in the order it was armed.
  ///
  /// Arming replaces by id, exactly as `zonedSchedule` does, and a disarm
  /// removes — so this answers "would the user get a notification right now?",
  /// which is the question the assertions actually care about. A raw call log
  /// cannot answer it: arm/disarm/arm and arm/arm/disarm have identical logs and
  /// opposite outcomes.
  List<({int id, DateTime at, String title, String body})> get pending {
    final byId = <int, ({int id, DateTime at, String title, String body})>{};
    for (final call in _ordered) {
      if (call.$2) {
        byId[call.$1.id] = call.$1;
      } else {
        byId.remove(call.$1.id);
      }
    }
    return byId.values.toList();
  }

  final List<(({int id, DateTime at, String title, String body}), bool)>
      _ordered = [];

  @override
  Future<void> arm({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    final call = (id: id, at: at, title: title, body: body);
    armed.add(call);
    _ordered.add((call, true));
  }

  @override
  Future<void> disarm(int id) async {
    disarmed.add(id);
    _ordered.add(((id: id, at: DateTime(0), title: '', body: ''), false));
  }

  void clear() {
    armed.clear();
    disarmed.clear();
    _ordered.clear();
  }
}
