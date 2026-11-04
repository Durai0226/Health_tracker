import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/mindfulness_channel.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../support/fake_audio_engine.dart';

/// "Save mindful minutes" on an iPhone.
///
/// The switch existed only for Health Connect: every method of the channel said no
/// off Android, so on an iPhone the row was never shown and nothing was ever
/// written, though `package:health` writes `MINDFULNESS` to HealthKit. Now the
/// same channel answers for both, and an iPhone goes through the plugin.
///
/// What this cannot prove: that Apple Health stores it. That needs a device with
/// the HealthKit capability enabled on the App ID, and is a manual check in
/// `docs/release-checklist.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late List<MethodCall> channelCalls;
  late List<(List<HealthDataType>, List<HealthDataAccess>)> asked;
  late List<(List<HealthDataType>, List<HealthDataAccess>)> requested;
  late List<(DateTime, DateTime, double)> written;

  const channel = MethodChannel('dlyminder/mindfulness');
  final service = HealthDataService.instance;

  void platform({
    bool? granted = false,
    bool grantOnRequest = true,
    bool writes = true,
  }) {
    var held = granted;
    service.permissionQueryForTesting = (types, access) async {
      asked.add((types, access));
      return held;
    };
    service.authorizationRequestForTesting = (types, access) async {
      requested.add((types, access));
      held = grantOnRequest;
      return held;
    };
    service.mindfulnessWriterForTesting = (start, end, minutes) async {
      written.add((start, end, minutes));
      return writes;
    };
  }

  setUp(() async {
    channelCalls = [];
    asked = [];
    requested = [];
    written = [];
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    RelaxationService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    service.configuredForTesting = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MindfulnessChannel.channelForTesting = channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      channelCalls.add(call);
      return true;
    });
  });

  tearDown(() async {
    FocusService().resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    service.permissionQueryForTesting = null;
    service.authorizationRequestForTesting = null;
    service.mindfulnessWriterForTesting = null;
    service.configuredForTesting = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.close();
  });

  final start = DateTime(2026, 3, 15, 10, 0);

  group('the permission', () {
    test('is asked about as a WRITE of mindfulness, nothing else', () async {
      platform(granted: true);
      expect(await MindfulnessChannel.instance.hasPermission(), isTrue);
      expect(asked, hasLength(1));
      expect(asked.single.$1, HealthDataService.mindfulnessWriteTypes);
      expect(asked.single.$1, [HealthDataType.MINDFULNESS]);
      expect(asked.single.$2, [HealthDataAccess.WRITE],
          reason: 'READ_WRITE always reads as "not granted" on iOS');
    });

    test('a platform that will not say is a no', () async {
      platform(granted: null);
      expect(await MindfulnessChannel.instance.hasPermission(), isFalse);
      platform(granted: false);
      expect(await MindfulnessChannel.instance.hasPermission(), isFalse);
    });

    test('a failing query is a no, not a crash', () async {
      service.permissionQueryForTesting = (_, _) async => throw StateError('x');
      expect(await MindfulnessChannel.instance.hasPermission(), isFalse);
    });

    test('requesting asks for mindfulness, read and write, and reports the answer',
        () async {
      platform(granted: false, grantOnRequest: true);
      expect(await MindfulnessChannel.instance.requestPermission(), isTrue);
      expect(requested.single.$1, [HealthDataType.MINDFULNESS]);
      expect(requested.single.$2, [HealthDataAccess.READ_WRITE]);

      platform(granted: false, grantOnRequest: false);
      expect(await MindfulnessChannel.instance.requestPermission(), isFalse);
    });

    test('a request the platform will not answer is a no, not a yes', () async {
      service.authorizationRequestForTesting = (_, _) async => null;
      expect(await MindfulnessChannel.instance.requestPermission(), isFalse);
    });

    test('a failing request is a no, not a crash', () async {
      service.authorizationRequestForTesting = (_, _) async => throw StateError('x');
      expect(await MindfulnessChannel.instance.requestPermission(), isFalse);
    });

    test('nothing on the Android channel is touched', () async {
      platform();
      await MindfulnessChannel.instance.isAvailable();
      await MindfulnessChannel.instance.hasPermission();
      await MindfulnessChannel.instance.requestPermission();
      expect(channelCalls, isEmpty);
    });
  });

  group('the write', () {
    test('lands as one interval, with its length in minutes', () async {
      platform();
      final end = start.add(const Duration(minutes: 20));
      final ok = await MindfulnessChannel.instance.writeSession(
          start: start, end: end, kind: MindfulnessKind.meditation, title: 'x');
      expect(ok, isTrue);
      expect(written, [(start, end, 20.0)]);
      expect(channelCalls, isEmpty);
    });

    test('a part-minute session is not rounded away', () async {
      platform();
      await MindfulnessChannel.instance.writeSession(
          start: start,
          end: start.add(const Duration(seconds: 90)),
          kind: MindfulnessKind.breathing);
      expect(written.single.$3, 1.5);
    });

    test('a zero-length or reversed session is refused, and nothing is written',
        () async {
      platform();
      expect(
          await MindfulnessChannel.instance
              .writeSession(start: start, end: start, kind: MindfulnessKind.breathing),
          isFalse);
      expect(
          await MindfulnessChannel.instance.writeSession(
              start: start,
              end: start.subtract(const Duration(minutes: 1)),
              kind: MindfulnessKind.breathing),
          isFalse);
      expect(written, isEmpty);
    });

    test('Apple Health refusing it is a no', () async {
      platform(writes: false);
      expect(
          await MindfulnessChannel.instance.writeSession(
              start: start,
              end: start.add(const Duration(minutes: 5)),
              kind: MindfulnessKind.breathing),
          isFalse);
      expect(written, hasLength(1));
    });

    test('a throwing write never escapes', () async {
      service.mindfulnessWriterForTesting = (_, _, _) async => throw StateError('x');
      expect(
          await MindfulnessChannel.instance.writeSession(
              start: start,
              end: start.add(const Duration(minutes: 5)),
              kind: MindfulnessKind.breathing),
          isFalse);
    });

    test('on Android the plugin is not used for it', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      platform();
      await MindfulnessChannel.instance.writeSession(
          start: start,
          end: start.add(const Duration(minutes: 5)),
          kind: MindfulnessKind.breathing);
      expect(written, isEmpty);
      expect(channelCalls.map((c) => c.method), ['writeSession']);
    });
  });

  group('the Focus switch, end to end on an iPhone', () {
    test('turning it on asks Apple Health, then breathing is written', () async {
      platform(granted: false, grantOnRequest: true);

      expect(await FocusService().setMindfulnessSync(true), isTrue);
      expect(requested, hasLength(1));
      expect(FocusService().mindfulnessSync, isTrue);

      final end = start.add(const Duration(minutes: 3));
      await FocusService().writeBreathingMindfulness(start: start, end: end);
      expect(written, [(start, end, 3.0)]);
    });

    test('a refusal bounces the switch back and says why, with nothing written',
        () async {
      platform(granted: false, grantOnRequest: false);

      expect(await FocusService().setMindfulnessSync(true), isFalse);
      expect(FocusService().mindfulnessSync, isFalse);
      expect(FocusService().mindfulnessDenialReason, isNotNull);

      await FocusService().writeBreathingMindfulness(
          start: start, end: start.add(const Duration(minutes: 3)));
      expect(written, isEmpty);
    });

    test('switched off, nothing is written', () async {
      platform(granted: true);
      await FocusService().writeBreathingMindfulness(
          start: start, end: start.add(const Duration(minutes: 3)));
      expect(written, isEmpty);
    });

    test('a work session is still never written as mindfulness', () {
      expect(mindfulnessKindFor(FocusActivityType.coding), isNull);
      expect(mindfulnessKindFor(FocusActivityType.study), isNull);
    });
  });
}
