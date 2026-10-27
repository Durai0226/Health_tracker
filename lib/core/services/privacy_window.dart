import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the app's content out of the recent-apps preview while App lock is on.
///
/// With the lock on, the lock screen guards the app — but Android's task
/// switcher shows a snapshot of the last thing on screen: medicines, readings, a
/// diary entry. `FLAG_SECURE` on the window removes it (and, as the platform
/// does not separate them, blocks screenshots and screen recordings too, which is
/// said where the lock is switched on).
///
/// Android only: on iPhone the call is a no-op, and the app-switcher snapshot is
/// not covered.
class PrivacyWindow {
  const PrivacyWindow._();

  static const MethodChannel _channel = MethodChannel('dlyminder/lockscreen');

  /// Make the window secure, or not. Never throws: a platform without the
  /// channel (iOS, a test) simply has nothing to do.
  static Future<void> apply(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': secure});
    } catch (e) {
      debugPrint('PrivacyWindow.apply($secure) skipped: $e');
    }
  }
}
