import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/screens/health_privacy_screen.dart';
import '../../main.dart' show navigatorKey;

/// Routes Health Connect's "show your rationale" deep links to
/// [HealthPrivacyScreen].
///
/// `AndroidManifest.xml` declares two filters on MainActivity —
/// `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` and Android 14+'s
/// `ACTION_VIEW_PERMISSION_USAGE` — but MainActivity handled no intents, so
/// both did nothing beyond bringing the app forward. Google reviews that flow
/// for any app declaring health permissions.
///
/// ## Why there are two directions
///
/// * **Cold start** — the intent exists before Flutter has attached a handler,
///   so an `invokeMethod` from Kotlin would land nowhere. Kotlin buffers the
///   action instead and Dart *pulls* it once the first frame is up
///   ([drainPending]).
/// * **Warm** — the activity is already alive (launchMode is `singleTop`), so
///   Kotlin *pushes* via `showHealthPrivacy`.
///
/// Every failure path here is swallowed: this is a disclosure convenience, and
/// it must never be able to take down startup.
class HealthRationaleChannel {
  HealthRationaleChannel._();

  static final HealthRationaleChannel instance = HealthRationaleChannel._();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('dlyminder/health_privacy');

  /// Guards against stacking two copies of the screen — Health Connect can
  /// deliver the intent again while it is already open.
  bool _isShowing = false;

  /// Set when a push arrives before the navigator exists; flushed by
  /// [drainPending].
  bool _deferred = false;

  bool _attached = false;

  /// Health Connect is Android-only, so the whole channel is.
  ///
  /// Deliberately `defaultTargetPlatform` and not `Platform.isAndroid`: the
  /// latter reports the HOST under `flutter test` (macOS), which would make
  /// every method here a no-op and the tests vacuous. This one is overridable
  /// via `debugDefaultTargetPlatformOverride`.
  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Registers the Kotlin → Dart handler. Safe to call before `runApp`; a push
  /// that arrives with no navigator yet is deferred rather than dropped.
  void attach() {
    if (_attached || !_isAndroid) return;
    _attached = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'showHealthPrivacy') _show();
      return null;
    });
  }

  /// Collects a cold-start intent Kotlin buffered before Flutter was ready.
  /// Call once the first frame is up, when [navigatorKey] has a state.
  Future<void> drainPending() async {
    if (!_isAndroid) return;
    if (_deferred) {
      _deferred = false;
      _show();
      return;
    }
    try {
      final action = await channel.invokeMethod<String>('consumePendingRationale');
      if (action != null) _show();
    } on MissingPluginException {
      // No native side (tests, or a host that never registered the channel).
    } catch (e) {
      debugPrint('HealthRationaleChannel.drainPending failed: $e');
    }
  }

  void _show() {
    if (_isShowing) return;
    final nav = navigatorKey.currentState;
    if (nav == null) {
      // Too early — drainPending will pick this up after the first frame.
      _deferred = true;
      return;
    }
    _isShowing = true;
    nav
        .push(MaterialPageRoute<void>(
          builder: (_) => const HealthPrivacyScreen(),
        ))
        .whenComplete(() => _isShowing = false);
  }

  @visibleForTesting
  void resetForTesting() {
    _isShowing = false;
    _deferred = false;
    _attached = false;
  }
}
