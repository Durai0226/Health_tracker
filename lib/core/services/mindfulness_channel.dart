import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/focus/models/focus_session.dart';

/// What kind of mindfulness practice a session was. Ordinals are the wire
/// format for the Kotlin side — append only, never insert.
enum MindfulnessKind { breathing, meditation, music }

/// Health Connect mindfulness write-back.
///
/// `package:health` 13.3.2 supports `HealthDataType.MINDFULNESS` on iOS only —
/// it appears in `dataTypeKeysIOS`, is absent from `dataTypeKeysAndroid`, and
/// there is no mindfulness code in the plugin's Android sources. HealthKit
/// therefore goes through the plugin; Health Connect needs this channel.
///
/// Every method degrades to "no" rather than throwing. This is opt-in, secondary
/// to the thing the user actually did, and a health provider that hangs or a
/// device without the feature must never affect whether their session was saved.
class MindfulnessChannel {
  MindfulnessChannel._();
  static final MindfulnessChannel instance = MindfulnessChannel._();

  static const MethodChannel _channel = MethodChannel('dlyminder/mindfulness');

  /// Test seam. Set to a fake to assert what would be written without a device.
  @visibleForTesting
  static MethodChannel channelForTesting = _channel;

  /// `defaultTargetPlatform`, not `Platform.isAndroid`.
  ///
  /// `Platform.isAndroid` is false in a headless test on macOS, which would make
  /// every assertion below vacuously pass — the test would prove only that the
  /// host is not Android. `defaultTargetPlatform` is overridable, so the tests
  /// can actually exercise the Android path.
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Whether this device can store mindfulness sessions at all.
  ///
  /// `MindfulnessSessionRecord` is an experimental API delivered by a Google Play
  /// System Update, so plenty of devices will say no. **Callers must check this
  /// before requesting the permission**: Health Connect refuses the whole
  /// permission sheet if any requested type is unsupported, which would break the
  /// permissions the app genuinely needs. The settings row is hidden when this is
  /// false rather than shown and broken.
  Future<bool> isAvailable() async {
    if (!_isAndroid) return false;
    try {
      return await channelForTesting.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      debugPrint('Mindfulness availability check failed: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    if (!_isAndroid) return false;
    try {
      return await channelForTesting.invokeMethod<bool>('hasPermission') ?? false;
    } catch (e) {
      debugPrint('Mindfulness permission check failed: $e');
      return false;
    }
  }

  /// Write one session. Returns whether it landed.
  Future<bool> writeSession({
    required DateTime start,
    required DateTime end,
    required MindfulnessKind kind,
    String? title,
    String? clientId,
  }) async {
    if (!_isAndroid) return false;
    if (!end.isAfter(start)) return false;
    try {
      return await channelForTesting.invokeMethod<bool>('writeSession', {
            'startMs': start.millisecondsSinceEpoch,
            'endMs': end.millisecondsSinceEpoch,
            'kind': kind.index,
            'title': title,
            'clientId': clientId,
          }) ??
          false;
    } catch (e) {
      debugPrint('Mindfulness write failed: $e');
      return false;
    }
  }
}

/// Which focus activities are mindfulness practice, and which are not.
///
/// **Returning null for work is the point, not an omission.** Forest logs every
/// focus session to Apple Health as Mindful Minutes; that is wrong, and declining
/// to copy it is a feature. `MindfulnessSessionRecord` and
/// `HKCategoryTypeIdentifier.mindfulSession` mean *mindfulness practice* — not
/// *time spent concentrating* — so writing a fifty-minute coding sprint there
/// puts a false claim into a permanent health record the user may later show a
/// clinician.
///
/// An **exhaustive switch with no `default:`** on purpose: adding a
/// `FocusActivityType` must be a compile error here, not a silent decision to
/// write it. A guard test pins that.
MindfulnessKind? mindfulnessKindFor(FocusActivityType activity) {
  switch (activity) {
    case FocusActivityType.meditation:
      return MindfulnessKind.meditation;
    // Everything below is concentration, not practice.
    case FocusActivityType.work:
    case FocusActivityType.study:
    case FocusActivityType.reading:
    case FocusActivityType.writing:
    case FocusActivityType.coding:
    case FocusActivityType.creative:
    case FocusActivityType.exercise:
    case FocusActivityType.other:
      return null;
  }
}
