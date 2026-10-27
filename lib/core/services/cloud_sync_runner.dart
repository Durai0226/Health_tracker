import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'clean_storage_service.dart';
import 'cloud_sync_service.dart';

/// When the cloud sync runs.
///
/// It ran once, at app start — so switching it on did nothing until the app was
/// next killed and opened, and an app left open for days never synced at all. It
/// now runs at start, the moment it is switched on, and again when the app comes
/// back to the front after a while.
///
/// Every run keeps the same two gates, and in the same words: the person is
/// signed in with a real account (an anonymous or guest one does not count), and
/// they have switched sync on. Health data leaves the device only with both.
class CloudSyncRunner {
  const CloudSyncRunner._();

  /// How long since the last run before coming back to the app syncs again.
  static const Duration resumeInterval = Duration(minutes: 30);

  static DateTime? _lastRun;

  /// Why a run did not happen, or null when it did. For a test and for the log.
  static String? lastSkipReason;

  /// Run the sync if both gates are open.
  ///
  /// [force] is for the moments the person has just asked for it (start-up, the
  /// switch): it ignores [resumeInterval]. Without it, a run is skipped when one
  /// finished less than [resumeInterval] ago. Returns whether a sync ran and
  /// completed; a failure is logged and returns false, never thrown — this is
  /// always a background courtesy.
  ///
  /// [authenticated], [enabled], [userId] and [sync] are what a test hands in;
  /// production reads the real ones.
  static Future<bool> maybeSync({
    bool force = false,
    bool? authenticated,
    bool? enabled,
    String? userId,
    Future<void> Function(String userId)? sync,
  }) async {
    final auth = AuthService();
    final isAuthenticated = authenticated ?? auth.isAuthenticated;
    final isEnabled = enabled ?? CleanStorageService.cloudSyncEnabled;
    final id = userId ?? auth.currentUser?.id;

    if (!isAuthenticated) return _skip('not signed in with a real account');
    if (!isEnabled) return _skip('cloud sync is switched off');
    if (id == null || id.isEmpty) return _skip('no user id');

    final now = clock.now();
    final last = _lastRun;
    if (!force && last != null && now.difference(last) < resumeInterval) {
      return _skip('synced ${now.difference(last).inMinutes} min ago');
    }

    lastSkipReason = null;
    try {
      await (sync ?? CloudSyncService().syncUserData)(id);
      // Only a run that finished counts: one that threw is tried again at the
      // next chance.
      _lastRun = clock.now();
      debugPrint('✓ Cloud sync completed');
      return true;
    } catch (e) {
      debugPrint('⚠️ Cloud sync failed: $e');
      return false;
    }
  }

  static bool _skip(String why) {
    lastSkipReason = why;
    debugPrint('• Cloud sync skipped — $why');
    return false;
  }

  @visibleForTesting
  static void resetForTesting() {
    _lastRun = null;
    lastSkipReason = null;
  }
}
