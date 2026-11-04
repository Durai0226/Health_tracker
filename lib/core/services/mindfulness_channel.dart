import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/focus/models/focus_session.dart';
import '../../features/focus/models/relaxation_music.dart' show RelaxationCategory;
import 'health_data_service.dart';

/// What kind of mindfulness practice a session was. Ordinals are the wire
/// format for the Kotlin side — append only, never insert.
enum MindfulnessKind { breathing, meditation, music }

/// Mindfulness write-back: Health Connect on Android, Apple Health on iPhone.
///
/// `package:health` 13.3.2 supports `HealthDataType.MINDFULNESS` on iOS only —
/// it appears in `dataTypeKeysIOS`, is absent from `dataTypeKeysAndroid`, and
/// there is no mindfulness code in the plugin's Android sources. HealthKit
/// therefore goes through the plugin (via [HealthDataService]); Health Connect
/// needs the method channel. Callers see one interface either way.
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
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether this device can store mindfulness sessions at all.
  ///
  /// `MindfulnessSessionRecord` is an experimental API delivered by a Google Play
  /// System Update, so plenty of devices will say no. **Callers must check this
  /// before requesting the permission**: Health Connect refuses the whole
  /// permission sheet if any requested type is unsupported, which would break the
  /// permissions the app genuinely needs. The settings row is hidden when this is
  /// false rather than shown and broken.
  Future<bool> isAvailable() async {
    // Every iPhone can store a mindful session; nothing like Android's optional
    // system update stands in the way, so the row is always offered there.
    if (_isIOS) return true;
    if (!_isAndroid) return false;
    try {
      return await channelForTesting.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      debugPrint('Mindfulness availability check failed: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    if (_isIOS) return HealthDataService.instance.hasMindfulnessWritePermission();
    if (!_isAndroid) return false;
    try {
      return await channelForTesting.invokeMethod<bool>('hasPermission') ?? false;
    } catch (e) {
      debugPrint('Mindfulness permission check failed: $e');
      return false;
    }
  }

  /// Ask Health Connect for the mindfulness WRITE grant. Returns whether it is
  /// held afterwards.
  ///
  /// Nothing in the app used to request it, so [hasPermission] was always false
  /// the first time and the settings switch could never be turned on at all.
  ///
  /// **Check [isAvailable] first.** Health Connect refuses the entire permission
  /// sheet if any requested type is unsupported, which would take the grants the
  /// app genuinely needs down with it.
  ///
  /// A missing native handler reads as "denied", not as a crash: this is opt-in
  /// and secondary, and a build whose Kotlin half predates this method must still
  /// leave the switch usable everywhere else.
  Future<bool> requestPermission() async {
    if (_isIOS) return HealthDataService.instance.requestMindfulnessWritePermission();
    if (!_isAndroid) return false;
    try {
      return await channelForTesting.invokeMethod<bool>('requestPermission') ??
          false;
    } catch (e) {
      debugPrint('Mindfulness permission request failed: $e');
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
    // HealthKit's mindful session carries no kind or title; those are Health
    // Connect's, and are simply not sent.
    if (_isIOS) {
      return HealthDataService.instance.writeMindfulMinutes(start: start, end: end);
    }
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

/// Which relaxation categories are mindfulness practice.
///
/// Stress Relief is: sitting with calming sound to let anxiety go. Deep Focus is
/// background for work, study and coding, which is concentration, not practice (see
/// [mindfulnessKindFor]). Full Reset is sleep audio, which is often played while
/// falling asleep, so minutes of it would be minutes nobody was mindful for. Both
/// return null, and an exhaustive switch with no `default:` makes a new category a
/// compile error here rather than a silent decision to write it.
MindfulnessKind? mindfulnessKindForRelaxation(RelaxationCategory category) {
  switch (category) {
    case RelaxationCategory.stressRelief:
      return MindfulnessKind.meditation;
    case RelaxationCategory.deepFocus:
    case RelaxationCategory.nervousSystemReset:
      return null;
  }
}
