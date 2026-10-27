import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the dialer or the messages app with a number already in it.
///
/// It never places a call or sends a message: that is one more press, by the
/// person. A stray tap on a medical screen must not ring anyone, which is also
/// why the app does not ask for the CALL_PHONE permission.
class ContactLauncher {
  const ContactLauncher._();

  /// The digits and a leading `+`: what a dialer takes of "+91 (98765) 43-210".
  static String dialable(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

  /// Test seam: widget tests have no dialer. Set it to read the URI, or to
  /// answer false for a device with none.
  @visibleForTesting
  static Future<bool> Function(Uri uri)? launcherOverride;

  /// Open the dialer on [phone]. False when nothing could open it.
  static Future<bool> call(String phone) =>
      _launch(Uri(scheme: 'tel', path: dialable(phone)));

  /// Open the messages app to [phone] with [body] typed in, ready to send.
  ///
  /// The body is percent-encoded by hand. `Uri(queryParameters: ...)` writes a
  /// space as `+`, which several messages apps print as a plus sign.
  static Future<bool> text(String phone, {String body = ''}) {
    final number = dialable(phone);
    return _launch(Uri.parse(
        body.isEmpty ? 'sms:$number' : 'sms:$number?body=${Uri.encodeComponent(body)}'));
  }

  static Future<bool> _launch(Uri uri) async {
    final override = launcherOverride;
    if (override != null) return override(uri);
    // Not gated on canLaunchUrl: it answers false on recent Android and iOS
    // unless the app declares the query, which would turn "no dialer" and "not
    // declared" into the same silence. launchUrl reports a real failure by
    // returning false or throwing.
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('⚠️ Opening $uri failed: $e');
      return false;
    }
  }
}
