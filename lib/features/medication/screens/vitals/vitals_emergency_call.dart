import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app/app_widgets.dart';

/// The one "Call emergency" action behind the crisis cards on the
/// blood-pressure and blood-sugar screens.
///
/// Both buttons used to answer with a toast telling the user to call their
/// local emergency number themselves. A hypertensive crisis or a severe
/// hypoglycaemia is precisely the moment a person cannot look a number up, so
/// a button labelled "Call emergency" that only prints advice is worse than no
/// button: it reads as help and delivers none. It now opens the dialer.
///
/// Lives here rather than in either screen because both crisis cards need the
/// identical behaviour, and two copies of an emergency number is two places to
/// get a number wrong.
class VitalsEmergencyCall {
  VitalsEmergencyCall._();

  /// Dialed when the device's region is unknown or not in [numbersByRegion].
  ///
  /// 112 is the GSM standard emergency number: handsets route it to local
  /// services across the EU/EEA, India and most GSM networks worldwide, and it
  /// works from a locked handset. The map below is only the regions where 112
  /// is *not* the number that reaches a dispatcher, or where the national
  /// number is the one people actually recognise.
  static const String fallbackNumber = '112';

  /// Region → the emergency number to put in the dialer. Deliberately short:
  /// every entry is a country where [fallbackNumber] would be wrong or
  /// unfamiliar, not an attempt at a worldwide table this app cannot maintain.
  @visibleForTesting
  static const Map<String, String> numbersByRegion = {
    'US': '911',
    'CA': '911',
    'MX': '911',
    'GB': '999', // 112 also routes here; 999 is the number people know.
    'AU': '000',
    'NZ': '111',
    'JP': '119', // Fire/ambulance; 110 is police.
  };

  /// The number [dial] would use for [regionCode] (an ISO 3166-1 alpha-2
  /// code, e.g. the `countryCode` of the device locale).
  static String numberForRegion(String? regionCode) {
    if (regionCode == null || regionCode.isEmpty) return fallbackNumber;
    return numbersByRegion[regionCode.toUpperCase()] ?? fallbackNumber;
  }

  /// The number for the device's current region.
  static String get currentNumber =>
      numberForRegion(PlatformDispatcher.instance.locale.countryCode);

  /// Test seam. Widget tests have no dialer and no url_launcher platform
  /// implementation, so without this every test of this path would exercise
  /// only the failure branch. Set it to assert on the URI, or to simulate a
  /// device with no dialer; always null in a real build.
  @visibleForTesting
  static Future<bool> Function(Uri uri)? launcherOverride;

  static Future<bool> _launch(Uri uri) async {
    final override = launcherOverride;
    if (override != null) return override(uri);
    // `tel:` opens the dialer with the number filled in and waits for the user
    // to press call — it never places the call itself. Android's CALL_PHONE
    // permission, which would dial directly, is deliberately not requested: a
    // stray tap on a medical screen must not summon an ambulance on its own.
    //
    // Deliberately NOT gated on canLaunchUrl. Its own documentation says it
    // "will always return false" on recent Android and iOS unless the app is
    // configured to query the system for launch support, and a false there is
    // indistinguishable from "this device has no dialer" — which would have
    // turned this button straight back into the advice toast it replaced.
    // launchUrl reports a genuine failure by returning false or throwing, and
    // that is the only signal worth acting on.
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('⚠️ Opening the dialer on $uri failed: $e');
      return false;
    }
  }

  /// Open the dialer on the region's emergency number.
  ///
  /// On failure — no dialer app, a tablet with no telephony, a launch the OS
  /// refuses — the copy says so and still names the number, because "couldn't
  /// open the dialer" without the number leaves the user exactly where the old
  /// toast did.
  static Future<void> dial(BuildContext context) async {
    final number = currentNumber;
    final opened = await _launch(Uri(scheme: 'tel', path: number));
    if (opened || !context.mounted) return;
    context.toastError(
      'Could not open the dialer. Call $number, or get to the nearest ER.',
      title: 'Call $number now',
    );
  }
}
