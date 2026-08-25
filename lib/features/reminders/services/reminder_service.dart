import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/services/clean_storage_service.dart';
import '../models/reminder_model.dart';

/// Live reminder state, so a screen no longer has to guess when to reload.
///
/// `lib/features/reminders/services/` was an empty directory and reminders had
/// **no notifier at all** — `home_dashboard.dart` says so outright: *"Returning
/// to Home recomputes the sync parts (reminders have no notifier)."* Every
/// surface read the static `CleanStorageService._remindersCache` and called
/// `_load()` again after each `Navigator.push` returned. Two surfaces showing
/// reminders could therefore disagree until one of them happened to be
/// re-entered, and a write from anywhere else — the reschedule pass, a cloud
/// arrival, an occurrence being recorded — was invisible until then.
///
/// `RemindersDao.watchReminders()` existed for exactly this and had never been
/// called. This wires it up.
///
/// **Shape follows the codebase, not the `provider` package.** There is no
/// `MultiProvider` anywhere in this app despite the dependency: the established
/// pattern is a singleton exposing a notifier that screens subscribe to in
/// `initState` (`VitalsStorageService.revision`,
/// `MedicineCleanStorageService.revision`, `ActiveProfileService`). Introducing
/// a provider tree for one feature would be a second pattern to learn, not a
/// simplification.
///
/// Drift stays the single source of truth. This does not add a second cache: on
/// every emission it refreshes the one cache that already exists
/// (`CleanStorageService`'s, which the synchronous `getReminders()` and the
/// notification layer's snooze lookup both read) and then notifies. So a
/// listener and a synchronous reader can never see different data.
class ReminderService extends ChangeNotifier {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  StreamSubscription<List<db.Reminder>>? _sub;
  bool _started = false;

  List<Reminder> _reminders = const [];

  /// The current reminders, newest scheduled last. Synchronous — safe to read
  /// during `build`.
  List<Reminder> get reminders => List.unmodifiable(_reminders);

  /// Whether the first emission has arrived. Distinguishes "no reminders" from
  /// "not loaded yet", which an empty list alone cannot.
  bool get isLoaded => _loaded;
  bool _loaded = false;

  /// Begin watching. Idempotent — safe to call from more than one entry point.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      // Seed synchronously from the existing cache so the first frame is not
      // empty while the stream spins up.
      _reminders = CleanStorageService.getReminders();
      _sub = db.AppDatabase.instance.remindersDao.watchReminders().listen(
        (_) async {
          // Re-read through CleanStorageService rather than mapping the rows
          // here: it owns the row→model mapping (including the customDaysJson
          // decode) and the cache that synchronous readers depend on. Mapping
          // separately would be a second, silently divergent implementation.
          _reminders = await CleanStorageService.getAllReminders();
          _loaded = true;
          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('⚠️ Reminder stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('⚠️ ReminderService.start failed: $e');
      _started = false;
    }
  }

  /// Force a re-read. Only needed for a write that bypasses Drift; an ordinary
  /// save already emits on the stream.
  Future<void> refresh() async {
    _reminders = await CleanStorageService.getAllReminders();
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    super.dispose();
  }

  /// Test-only: drop the subscription and state between tests, since this is a
  /// process-wide singleton.
  @visibleForTesting
  Future<void> resetForTesting() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
    _loaded = false;
    _reminders = const [];
  }
}
