/// Leaving the phone's health store from inside the app.
///
/// What is proved here is the order and the isolation: the app's own readers and
/// writers are stopped first, every step is attempted whatever happened to the one
/// before, and what the platform says about its permissions is reported as it is.
/// That the platform really takes its permissions back needs a device.
library;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/mindfulness_channel.dart';
import 'package:tablet_remainder/features/biometrics/services/health_disconnect.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/water/services/hydration_health_sync.dart';
import 'package:tablet_remainder/features/water/services/water_health_import.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  const mindfulness = MethodChannel('dlyminder/mindfulness');

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'health_connected': true,
      'health_permission_asked': true,
      'health_biometrics_connected': true,
      'health_cycle_connected': true,
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    RelaxationService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MindfulnessChannel.channelForTesting = mindfulness;
    // Health Connect already allows the write: switching it on succeeds.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mindfulness, (call) async {
      switch (call.method) {
        case 'isAvailable':
        case 'hasPermission':
        case 'requestPermission':
          return true;
      }
      return null;
    });
  });

  tearDown(() async {
    FocusService().resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mindfulness, null);
    await db.close();
  });

  Future<void> everythingOn() async {
    await VitalsHealthImport.setEnabled(true);
    await WaterHealthImport.setEnabled(true);
    await VitalsStorageService.setHealthConnectSyncEnabled(true);
    await HydrationHealthSync.setEnabled(true);
  }

  Future<List<bool>> states() async => [
        await VitalsHealthImport.isEnabled(),
        await WaterHealthImport.isEnabled(),
        await VitalsStorageService.isHealthConnectSyncEnabled(),
        await HydrationHealthSync.isEnabled(),
      ];

  /// Seams that record what was asked, in order.
  ({
    List<String> log,
    Future<void> Function() stop,
    Future<bool> Function() revoke,
    Future<void> Function() forget,
  }) seams({bool revokes = true}) {
    final log = <String>[];
    return (
      log: log,
      stop: () async => log.add('background'),
      revoke: () async {
        log.add('revoke');
        return revokes;
      },
      forget: () async => log.add('forget'),
    );
  }

  test('switches off everything in the app that uses the store', () async {
    await everythingOn();
    expect(await states(), [true, true, true, true], reason: 'the premise');
    final s = seams();

    await HealthDisconnect.run(
        stopBackground: s.stop, revoke: s.revoke, forget: s.forget);

    expect(await states(), [false, false, false, false]);
  });

  group('the Focus mindfulness switch', () {
    // Focus writes mindful minutes to the store. Disconnecting revokes the
    // permission behind them; the switch left on kept trying to write, and kept
    // reading "on", with nothing to say it no longer worked.
    test('is switched off with the rest', () async {
      await FocusService().setMindfulnessSync(true);
      expect(FocusService().mindfulnessSync, isTrue, reason: 'the premise');
      final s = seams();

      await HealthDisconnect.run(
          stopBackground: s.stop, revoke: s.revoke, forget: s.forget);

      expect(FocusService().mindfulnessSync, isFalse);
      expect(CleanStorageService.getAppPreferences()['focusMindfulnessSync'], isFalse,
          reason: 'and it stays off after a restart');
    });

    test('and writes nothing afterwards', () async {
      final written = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mindfulness, (call) async {
        if (call.method == 'writeSession') written.add(call.method);
        return true;
      });
      await FocusService().setMindfulnessSync(true);
      final s = seams();
      await HealthDisconnect.run(
          stopBackground: s.stop, revoke: s.revoke, forget: s.forget);

      await FocusService().writeBreathingMindfulness(
          start: DateTime(2026, 9, 30, 8), end: DateTime(2026, 9, 30, 8, 5));

      expect(written, isEmpty);
    });

    test('a switch that was never on is left off, and nothing breaks', () async {
      final s = seams();

      await HealthDisconnect.run(
          stopBackground: s.stop, revoke: s.revoke, forget: s.forget);

      expect(FocusService().mindfulnessSync, isFalse);
      expect(s.log, ['background', 'forget', 'revoke']);
    });
  });

  test('stops the background worker, forgets the connection, then revokes', () async {
    final s = seams();

    await HealthDisconnect.run(
        stopBackground: s.stop, revoke: s.revoke, forget: s.forget);

    expect(s.log, ['background', 'forget', 'revoke'],
        reason: 'the platform is asked last, after the app has stopped using it');
  });

  test('reports whether the platform took its permissions back', () async {
    final yes = seams(revokes: true);
    final no = seams(revokes: false);

    expect(
        (await HealthDisconnect.run(
                stopBackground: yes.stop, revoke: yes.revoke, forget: yes.forget))
            .revoked,
        isTrue);
    expect(
        (await HealthDisconnect.run(
                stopBackground: no.stop, revoke: no.revoke, forget: no.forget))
            .revoked,
        isFalse,
        reason: 'an iPhone never does: the screen says where to go instead');
  });

  group('one step failing does not skip the rest', () {
    test('a worker that will not stop', () async {
      await everythingOn();
      final s = seams();

      final r = await HealthDisconnect.run(
          stopBackground: () async => throw StateError('worker'),
          revoke: s.revoke,
          forget: s.forget);

      expect(await states(), [false, false, false, false]);
      expect(s.log, ['forget', 'revoke']);
      expect(r.revoked, isTrue);
    });

    test('forgetting the connection fails', () async {
      await everythingOn();
      final s = seams();

      final r = await HealthDisconnect.run(
          stopBackground: s.stop,
          revoke: s.revoke,
          forget: () async => throw StateError('prefs'));

      expect(await states(), [false, false, false, false]);
      expect(s.log, ['background', 'revoke']);
      expect(r.revoked, isTrue);
    });

    test('the platform refuses to revoke: nothing thrown, and it says so', () async {
      await everythingOn();
      final s = seams();

      final r = await HealthDisconnect.run(
          stopBackground: s.stop,
          revoke: () async => throw StateError('no provider'),
          forget: s.forget);

      expect(r.revoked, isFalse);
      expect(await states(), [false, false, false, false]);
    });
  });

  test('forgets the connection the app remembers, by default', () async {
    final s = seams();

    // Only the platform parts are stood in for; forgetting is the real thing.
    await HealthDisconnect.run(stopBackground: s.stop, revoke: s.revoke);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('health_connected'), isFalse);
    expect(prefs.getBool('health_permission_asked'), isFalse);
    expect(prefs.getBool('health_biometrics_connected'), isFalse);
    expect(prefs.getBool('health_cycle_connected'), isFalse);
  });

  test('and leaves what is stored here alone', () async {
    // Disconnecting is not deleting: the readings already kept are the person's.
    SharedPreferences.setMockInitialValues({'keep_me': 'x', 'health_connected': true});
    final s = seams();

    await HealthDisconnect.run(
        stopBackground: s.stop, revoke: s.revoke, forget: s.forget);

    expect((await SharedPreferences.getInstance()).getString('keep_me'), 'x');
  });
}
