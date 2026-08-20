import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';

import '../support/fake_audio_engine.dart';

/// Behavioural cover for the audio subsystem — the first it has ever had.
///
/// The suite this replaces (`test/audio_service_test.dart`) had 8 green tests
/// that asserted its hardcoded URLs began with `http` and came from a hostname
/// allowlist. It validated **spelling**. Meanwhile 11 of 14 relaxation URLs were
/// returning 404 and 12 of 15 ambient URLs were returning 403, and two of the
/// bugs below had been reachable in the shipped app the whole time.
///
/// The lesson worth keeping: a test that cannot observe the thing it is named
/// after is worse than no test, because it reads as coverage.
/// Every case below picks a sound backed by one of the three GENERATED noise
/// files (`tool/gen_noise.dart`). They are the only entries that cannot leave the
/// catalogue: white, pink and brown noise are DSP definitions rather than
/// recordings, so no sourcing decision can un-ship them. Naming a field recording
/// here instead — as this file did with `rain` and `oceanWaves` — couples a
/// pause/resume test to the audio backlog, and it broke the moment the catalogue
/// was trimmed to what is actually on disk.
void main() {
  late FakeAudioEngine engine;
  late AudioService audio;

  setUp(() {
    engine = FakeAudioEngine();
    audio = AudioService();
    audio.engineForTesting = engine;
  });

  group('pause then resume', () {
    test('relaxation music comes back after a pause', () async {
      // THE BUG: `resume()` was gated on `_currentSound != AmbientSoundType.none`,
      // and `playRelaxationMusic` never assigned `_currentSound`. So on a fresh
      // app — nothing having selected an ambient sound — starting relaxation
      // music, pausing and resuming left the player stopped forever. The
      // countdown carried on, the button flipped back to a pause icon, and the
      // music never returned. Only an unrelated earlier ambient selection made it
      // appear to work.
      await audio.init();
      await audio.playRelaxationMusic('deepSleepDelta');
      expect(engine.playCalls, 1, reason: 'sanity: playback started');

      await audio.pause();
      expect(engine.pauseCalls, 1);

      await audio.resume();
      expect(engine.playCalls, 2,
          reason: 'resume() must reach the player after relaxation playback, '
              'not silently no-op because _currentSound was never set');
    });

    test('an ambient sound comes back after a pause', () async {
      await audio.init();
      await audio.playSound(AmbientSoundType.whiteNoise);
      await audio.pause();
      await audio.resume();
      expect(engine.playCalls, 2);
    });

    test('toggle resumes after a stop', () async {
      // `stop()` clears `_currentSound`, so the same gate made the Focus screen's
      // ambient play button dead after any stop — including the stop at the end of
      // every session.
      await audio.init();
      await audio.playSound(AmbientSoundType.whiteNoise);
      await audio.stop();
      final before = engine.playCalls;

      await audio.toggle();
      expect(engine.playCalls, greaterThan(before),
          reason: 'the play button must work again after a session ends');
    });
  });

  group('the player is the source of truth', () {
    test('an OS-driven pause updates isPlaying', () async {
      // `just_audio` defaults handleInterruptions to true: it pauses ITSELF on a
      // phone call and on the headphones-unplugged event, without the app asking.
      // Nothing reconciled that, so the UI kept showing a pause button over
      // silence with no way for the user to recover.
      await audio.init();
      await audio.playSound(AmbientSoundType.whiteNoise);
      expect(audio.isPlaying, isTrue);

      engine.emitPlayerState(playing: false); // phone call arrives
      await pumpEventQueue();

      expect(audio.isPlaying, isFalse,
          reason: 'the UI must not claim to be playing over silence');
    });

    test('notifies listeners when the player changes state on its own', () async {
      await audio.init();
      var notifications = 0;
      audio.addListener(() => notifications++);

      engine.emitPlayerState(playing: true);
      await pumpEventQueue();

      expect(notifications, greaterThan(0),
          reason: 'a state change nobody is told about cannot update the UI');
    });
  });

  group('volume', () {
    test('clamps to 0..1', () async {
      // Harvested from the 673-line suite that was disabled by a `skip:`, where it
      // was the only negative assertion in the entire Focus feature and had not
      // executed in months.
      await audio.setVolume(1.5);
      expect(audio.volume, 1.0);

      await audio.setVolume(-0.5);
      expect(audio.volume, 0.0);

      await audio.setVolume(0.4);
      expect(audio.volume, closeTo(0.4, 1e-9));
    });

    test('reaches the engine', () async {
      await audio.setVolume(0.25);
      expect(engine.volumes.last, closeTo(0.25, 1e-9));
    });
  });

  group('failure paths', () {
    test('a failing load leaves the service not-playing rather than throwing',
        () async {
      // Offline, a dead CDN link, a missing asset — all the same shape.
      engine.throwOn.add('setAsset');
      await audio.init();

      await expectLater(
          audio.playSound(AmbientSoundType.whiteNoise), completes,
          reason: 'audio failing must never propagate out and kill the caller — '
              'a focus session has to keep running without sound');
      expect(audio.isPlaying, isFalse);
    });

    test('a failing relaxation load does not leave isPlaying true', () async {
      engine.throwOn.add('setAsset');
      await audio.init();
      await audio.playRelaxationMusic('deepSleepDelta');
      expect(audio.isPlaying, isFalse);
    });
  });

  group('the singleton is not destroyed by a bystander', () {
    test('stop() does not dispose the engine', () async {
      // AudioService owns the app's only player. A dead wellness service used to
      // call dispose() on the singleton, which killed audio for the rest of the
      // process; a source guard now forbids that, and this pins the contract that
      // ordinary teardown uses stop().
      await audio.init();
      await audio.playSound(AmbientSoundType.whiteNoise);
      await audio.stop();
      expect(engine.disposed, isFalse);
    });
  });
}
