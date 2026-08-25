import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The hand-off between the background health worker and the app.
///
/// Pure `SharedPreferences` + JSON, modelled on `dose_action_queue.dart`, and
/// that is the whole point: **the background isolate must never touch Drift.**
///
/// ## Why not just write to the database in the background
///
/// The obvious design — have the worker write straight to Drift — needs
/// `shareAcrossIsolates: true` on the connection, which reroutes every query in
/// the app through a port, changes the carefully tuned pre-`runApp()` startup
/// path, and lets a background worker trigger a schema migration while the app
/// is closed with no UI to report a failure.
///
/// And it buys nothing. `StepService`, `SleepService` and `BiometricsService`
/// are static `ValueNotifier` maps hydrated once at `init()`, so a background
/// write is invisible to the main isolate, which has to re-read on resume
/// anyway. All the risk, none of the benefit.
///
/// So the worker writes a disposable snapshot here and sets a dirty flag; the
/// main isolate drains it on resume and runs the ordinary `syncFromHealth()`,
/// which stays the only writer to Drift. Every invariant those services
/// maintain — the additive step merge, the `hk_<dateKey>` stable ids, the
/// tombstone guards — is untouched.
///
/// ## The consent gate is preserved by construction
///
/// The worker cannot read `CleanStorageService.cloudSyncEnabled` (that needs
/// Drift), so it must never touch Firestore, so it cannot leak health data for
/// a user who never opted in. That is a structural guarantee, not a promise.
/// Why the background worker switched itself off.
///
/// Stored **by name**, not by index, so reordering this enum cannot silently
/// reinterpret a notice already written to a user's device — the same rule
/// `ReminderOccurrences` uses for its outcome column.
enum SyncDisableReason {
  /// Health Connect background-read authorization was revoked. Actionable: the
  /// user can grant it again from this screen.
  permissionRevoked,

  /// The authorization probe itself failed. NOT the same fact as a revocation —
  /// `isBackgroundReadAuthorized()` returns false from its own catch block, so a
  /// transient platform error lands here too, and telling the user their
  /// permission was revoked when it was not is worse than saying nothing
  /// precise.
  checkFailed,
}

abstract final class HealthSyncQueue {
  /// `flutter.` is prepended by shared_preferences itself. If the iOS
  /// background shim ever lands it must write `flutter.health_bg_snapshot`
  /// from Swift, or Dart reads nothing and you debug it for a day.
  static const String _kSnapshot = 'health_bg_snapshot';
  static const String _kDirty = 'health_bg_dirty';
  static const String _kLastRunMs = 'health_bg_last_run_ms';
  static const String _kLastError = 'health_bg_last_error';
  static const String _kEnabled = 'health_bg_enabled';

  /// Why background sync turned ITSELF off, and when.
  ///
  /// The worker disables itself on lost authorization
  /// (`background_health_sync_service.dart`) and used to leave no trace at all.
  /// The switch does read back off next time the user opens this screen, so the
  /// fact was technically observable — but "the toggle I set is off again" with
  /// no reason, no timestamp and no way to act on it is indistinguishable from
  /// the app losing a setting.
  ///
  /// Prefs rather than a table, deliberately: `background_health_sync_policy_test`
  /// forbids the background isolate from touching Drift, so a column here would
  /// be unwritable from the one place that needs to write it.
  static const String _kDisabledReason = 'health_bg_disabled_reason';
  static const String _kDisabledAtMs = 'health_bg_disabled_at_ms';

  /// Bumped when the snapshot's shape changes, so a blob written by an older
  /// build is discarded rather than misread into the wrong fields.
  static const int snapshotVersion = 1;

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, value);
      if (!value) await prefs.remove(_kSnapshot);
      // Turning it ON always clears a previous self-disable: the user has
      // answered it. Leaving the notice up after they act is the fastest way to
      // make a banner feel broken.
      if (value) {
        await prefs.remove(_kDisabledReason);
        await prefs.remove(_kDisabledAtMs);
      }
    } catch (e) {
      debugPrint('HealthSyncQueue.setEnabled failed: $e');
    }
  }

  /// Record that the WORKER disabled background sync, and why.
  ///
  /// Separate from [setEnabled] so a user switching it off by hand never leaves
  /// an explanatory notice behind — they know why it is off.
  static Future<void> recordSelfDisable(SyncDisableReason reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDisabledReason, reason.name);
      await prefs.setInt(
          _kDisabledAtMs, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(_kEnabled, false);
      await prefs.remove(_kSnapshot);
    } catch (e) {
      debugPrint('HealthSyncQueue.recordSelfDisable failed: $e');
    }
  }

  /// The pending self-disable notice, or null when there is none.
  ///
  /// Null once the user re-enables, so the caller renders nothing rather than a
  /// stale explanation.
  static Future<({SyncDisableReason reason, DateTime at})?> selfDisable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_kDisabledReason);
      if (name == null) return null;
      final ms = prefs.getInt(_kDisabledAtMs);
      final reason = SyncDisableReason.values
          .cast<SyncDisableReason?>()
          .firstWhere((r) => r!.name == name, orElse: () => null);
      if (reason == null) return null;
      return (
        reason: reason,
        at: DateTime.fromMillisecondsSinceEpoch(
            ms ?? DateTime.now().millisecondsSinceEpoch),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSelfDisable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDisabledReason);
      await prefs.remove(_kDisabledAtMs);
    } catch (_) {
      // Nothing useful to do; the notice will simply show once more.
    }
  }

  static Future<void> writeSnapshot(Map<String, dynamic> snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kSnapshot, jsonEncode({...snapshot, 'v': snapshotVersion}));
      await prefs.setInt(_kLastRunMs, DateTime.now().millisecondsSinceEpoch);
      await prefs.remove(_kLastError);
    } catch (e) {
      debugPrint('HealthSyncQueue.writeSnapshot failed: $e');
    }
  }

  /// Null when absent, corrupt, or written by a different snapshot version.
  static Future<Map<String, dynamic>?> readSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSnapshot);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['v'] != snapshotVersion) return null;
      return decoded;
    } catch (_) {
      // A malformed blob is a bug on our side, not user input. Losing one
      // snapshot is better than taking down whatever was reading it.
      return null;
    }
  }

  static Future<void> setDirty(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDirty, value);
    } catch (e) {
      debugPrint('HealthSyncQueue.setDirty failed: $e');
    }
  }

  /// Read-and-clear, so two drains cannot both act on one background run.
  static Future<bool> takeDirty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dirty = prefs.getBool(_kDirty) ?? false;
      if (dirty) await prefs.setBool(_kDirty, false);
      return dirty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> recordError(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Truncated: this is a debugging breadcrumb, not a log sink, and a
      // pathological stack trace should not bloat the prefs file.
      await prefs.setString(
          _kLastError,
          message.length > 300 ? message.substring(0, 300) : message);
    } catch (_) {
      // Nothing useful to do — the error path cannot itself fail loudly.
    }
  }

  static Future<DateTime?> lastRunAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kLastRunMs);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> lastError() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kLastError);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static Future<void> clearForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kSnapshot,
      _kDirty,
      _kLastRunMs,
      _kLastError,
      _kEnabled,
      _kDisabledReason,
      _kDisabledAtMs,
    ]) {
      await prefs.remove(k);
    }
  }
}
