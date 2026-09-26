import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/mindfulness_channel.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// "Save mindful minutes" has to be switchable ON.
///
/// `setMindfulnessSync(true)` asked `hasPermission()` and, when the answer was
/// no, wrote `false` back and returned without a word. Nothing anywhere ever
/// REQUESTED the Health Connect mindfulness write permission — so on every device
/// where the row is shown at all the grant is absent the first time, and the
/// switch bounced straight back off with no message and no second chance. The
/// feature was unreachable, permanently, on every install.
///
/// A denial still has to bounce the switch back: the user who revokes the grant
/// in the Health Connect app must not be left with a switch that says "on" while
/// nothing is being written. The difference is that now they are told why.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late List<MethodCall> calls;

  const channel = MethodChannel('dlyminder/mindfulness');

  /// [granted] is what `hasPermission` answers; [grantOnRequest] is whether the
  /// user accepts the sheet. [handled] false simulates a build whose Kotlin half
  /// has no handler for the new method.
  void mock({
    bool granted = false,
    bool grantOnRequest = true,
    bool handled = true,
  }) {
    var held = granted;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'hasPermission':
          return held;
        case 'requestPermission':
          if (!handled) {
            throw MissingPluginException(
                'No implementation found for ${call.method}');
          }
          held = grantOnRequest;
          return held;
      }
      return null;
    });
  }

  setUp(() async {
    calls = [];
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    RelaxationService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MindfulnessChannel.channelForTesting = channel;
  });

  tearDown(() async {
    FocusService().resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.close();
  });

  test('turning it on with no grant yet REQUESTS the permission and succeeds',
      () async {
    mock(granted: false, grantOnRequest: true);

    final applied = await FocusService().setMindfulnessSync(true);

    expect(calls.map((c) => c.method), ['hasPermission', 'requestPermission'],
        reason: 'BEFORE THE FIX only hasPermission was called, so a fresh '
            'install could never grant the permission this feature needs');
    expect(applied, isTrue);
    expect(FocusService().mindfulnessSync, isTrue,
        reason: 'the user asked for it on and granted it — it must be on');
    expect(FocusService().mindfulnessDenialReason, isNull);
  });

  test('an already-granted device does not re-prompt', () async {
    mock(granted: true);

    expect(await FocusService().setMindfulnessSync(true), isTrue);
    expect(calls.map((c) => c.method), ['hasPermission'],
        reason: 'no reason to open the Health Connect sheet over a grant we '
            'already hold');
  });

  test('a refused grant bounces the switch back AND says why', () async {
    mock(granted: false, grantOnRequest: false);

    final applied = await FocusService().setMindfulnessSync(true);

    expect(applied, isFalse);
    expect(FocusService().mindfulnessSync, isFalse,
        reason: 'the switch must not claim to be on while nothing is written');
    expect(FocusService().mindfulnessDenialReason, isNotNull,
        reason: 'BEFORE THE FIX the switch slid back off with no explanation at '
            'all, which reads as a broken control rather than a permission the '
            'user can go and grant');
    expect(CleanStorageService.getAppPreferences()['focusMindfulnessSync'],
        isFalse);
  });

  test('a missing native handler reads as denied, not as a crash', () async {
    // A build whose Kotlin half predates `requestPermission`. Mindfulness
    // write-back is opt-in and secondary; it must never take the settings screen
    // down with it.
    mock(granted: false, handled: false);

    // Awaited directly rather than wrapped in `returnsNormally`: an async
    // closure always "returns normally", so that matcher would pass even if the
    // MissingPluginException escaped.
    final applied = await FocusService().setMindfulnessSync(true);
    expect(applied, isFalse);
    expect(FocusService().mindfulnessSync, isFalse);
    expect(FocusService().mindfulnessDenialReason, isNotNull);
  });

  test('the guard does not over-fire: turning it OFF never asks anything',
      () async {
    mock(granted: true);
    await FocusService().setMindfulnessSync(true);
    calls.clear();

    expect(await FocusService().setMindfulnessSync(false), isTrue);
    expect(FocusService().mindfulnessSync, isFalse);
    expect(calls, isEmpty,
        reason: 'withdrawing consent must not require a permission round trip, '
            'and must never be refused');
    expect(FocusService().mindfulnessDenialReason, isNull);
  });

  test('a denial reason is cleared by the next successful toggle', () async {
    mock(granted: false, grantOnRequest: false);
    await FocusService().setMindfulnessSync(true);
    expect(FocusService().mindfulnessDenialReason, isNotNull);

    // The user grants it in the Health Connect app and tries again.
    mock(granted: true);
    expect(await FocusService().setMindfulnessSync(true), isTrue);
    expect(FocusService().mindfulnessDenialReason, isNull,
        reason: 'a stale reason would have the settings row warn about a '
            'permission that is now held');
  });
}
