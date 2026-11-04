import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Whether this phone's own step sensor may be read.
///
/// Android 10+ keeps the step counter behind the runtime "Physical activity"
/// permission, and iPhone behind Motion & Fitness. Without it the live counter
/// simply never emits — no error, just a number that does not move — which is why
/// a person with no health app connected got a steps screen that read zero all day.
///
/// A seam, so the offer and what follows a yes or a no can be driven without the
/// platform's permission dialog.
abstract interface class StepSensorAccess {
  /// Whether the sensor may be read now.
  Future<bool> isGranted();

  /// Ask. True only when it was allowed.
  Future<bool> request();
}

/// The real thing, through `permission_handler`.
///
/// Android only. On iPhone `permission_handler` can report Motion & Fitness only
/// when the app is built with `PERMISSION_SENSORS=1`, which the Podfile does not
/// set — and without it every answer is "denied", so the offer would show to
/// everyone, and tapping it would send them to Android's Settings path to fix
/// something that was never wrong. iPhone asks for itself instead: the pedometer
/// raises the system prompt the first time it is read. Until the macro is added and
/// checked on a device, this reports "granted" there, and the offer is not made.
class PlatformStepSensorAccess implements StepSensorAccess {
  const PlatformStepSensorAccess({@visibleForTesting this.iosForTesting});

  /// Stands in for `Platform.isIOS`, which a test cannot change.
  final bool? iosForTesting;

  bool get _ios => iosForTesting ?? Platform.isIOS;

  Permission get _permission => Permission.activityRecognition;

  @override
  Future<bool> isGranted() async {
    if (_ios) return true;
    try {
      return (await _permission.status).isGranted;
    } catch (e) {
      // No platform to ask (a desktop test host, a simulator): do not nag about
      // a permission that cannot be granted.
      debugPrint('StepSensorAccess: could not read the permission: $e');
      return true;
    }
  }

  @override
  Future<bool> request() async {
    if (_ios) return true;
    try {
      return (await _permission.request()).isGranted;
    } catch (e) {
      debugPrint('StepSensorAccess: could not ask for the permission: $e');
      return false;
    }
  }
}
