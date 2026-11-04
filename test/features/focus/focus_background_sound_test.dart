/// The ambient sound stops when the phase ends, even if the app is in the
/// background and the ticker is not running.
///
/// The ticker is stopped when the app is backgrounded (its only job is a
/// countdown nobody can see), which also meant nothing ran at the end of the
/// phase: the session could only complete on the way back in, and the sound played
/// on until then — rain on the lock screen long after a 25-minute session was
/// over. A single timer at the end instant stops it; the session still completes
/// on resume, as before.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeAudioEngine engine;
  final focus = FocusService();
  final t0 = DateTime(2026, 3, 14, 13);
  final rain = AudioService.playableAmbientSounds.first;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    engine = FakeAudioEngine();
    AudioService().engineForTesting = engine;
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    focus.resetForTesting();
    await db.close();
  });

  /// A 25-minute session with [sound], started at [t0].
  Future<void> start({AmbientSoundType? sound, int minutes = 25}) =>
      withClock(Clock.fixed(t0), () async {
        focus.setDuration(minutes);
        if (sound != null) focus.setSound(sound);
        await focus.startSession();
      });

  /// `AudioService.stop` is asynchronous: the player says it has stopped a few
  /// microtasks after it was asked to.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  void background([DateTime? at]) => withClock(Clock.fixed(at ?? t0.add(const Duration(minutes: 5))), () {
        focus.didChangeAppLifecycleState(AppLifecycleState.paused);
      });

  group('arming', () {
    test('playing a sound and leaving the app: a stop is set for the end of the phase',
        () async {
      await start(sound: rain);
      expect(focus.isAudioPlaying, isTrue, reason: 'the premise');

      background();

      expect(focus.backgroundSoundStopAtForTesting, t0.add(const Duration(minutes: 25)));
    });

    test('with no sound, nothing is set', () async {
      await start();

      background();

      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });

    test('a paused session sets nothing: it has no end', () async {
      await start(sound: rain);
      withClock(Clock.fixed(t0.add(const Duration(minutes: 2))), () {
        focus.pauseSession();
      });

      background();

      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });

    test('an idle service sets nothing when backgrounded', () {
      background();
      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });
  });

  group('what the timer does', () {
    test('when it fires with the app still away, the sound stops', () async {
      await start(sound: rain);
      background();

      focus.fireBackgroundSoundStopForTesting();
      await settle();

      expect(focus.isAudioPlaying, isFalse);
      expect(engine.stopCalls, greaterThan(0));
      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });

    test('back on screen it does nothing: the ticker owns the end again', () async {
      await start(sound: rain);
      background();
      // Back well before the end: the session is still running.
      withClock(Clock.fixed(t0.add(const Duration(minutes: 6))), () {
        focus.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });

      focus.fireBackgroundSoundStopForTesting();
      await settle();

      expect(focus.isAudioPlaying, isTrue);
    });

    test('resuming withdraws it', () async {
      await start(sound: rain);
      background();
      expect(focus.backgroundSoundStopAtForTesting, isNotNull);

      withClock(Clock.fixed(t0.add(const Duration(minutes: 6))), () {
        focus.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });

      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });

    test('abandoning the session withdraws it', () async {
      await start(sound: rain);
      background();

      await focus.abandonSession();

      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });

    test('pausing it withdraws it too', () async {
      await start(sound: rain);
      background();

      withClock(Clock.fixed(t0.add(const Duration(minutes: 6))), () {
        focus.pauseSession();
      });

      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });
  });

  group('the phase was already over when the app was left', () {
    test('the sound stops at once rather than waiting for a timer in the past',
        () async {
      await start(sound: rain, minutes: 1);

      background(t0.add(const Duration(minutes: 3)));
      await settle();

      expect(focus.isAudioPlaying, isFalse);
      expect(focus.backgroundSoundStopAtForTesting, isNull);
    });
  });

  group('the real timer', () {
    test('fires at the end instant and stops the sound', () async {
      await start(sound: rain, minutes: 1);
      // Fifty milliseconds before the end, as far as the clock is concerned; the
      // timer itself counts real time.
      background(t0.add(const Duration(seconds: 59, milliseconds: 950)));
      expect(focus.isAudioPlaying, isTrue);

      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (focus.isAudioPlaying && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(focus.isAudioPlaying, isFalse);
    });
  });
}
