import 'package:just_audio/just_audio.dart';

/// What the app needs from an audio player, and nothing more.
///
/// This exists so audio is testable at all. `AudioService` created its
/// `AudioPlayer` in a **field initialiser on a singleton**, which means the
/// platform channel was opened the first time anything touched `AudioService()` —
/// i.e. in every headless test that so much as built a Focus screen. There was no
/// seam to substitute, so the entire audio subsystem had zero behavioural
/// coverage: the only test that existed asserted that its hardcoded URLs matched
/// a hostname allowlist, and stayed green for months over 23 dead links.
///
/// Deliberately narrow. Two richer seams were considered and rejected:
///
///  * mocking `just_audio`'s `MethodChannel` — it opens a per-player channel keyed
///    by a generated id plus three `EventChannel`s, so a fake would have to
///    re-implement the plugin's state machine, and the tests would then be
///    coupled to plugin internals rather than to our behaviour;
///  * substituting `JustAudioPlatform.instance` — the "correct" plugin-level seam,
///    but it needs ~20 methods faked to exercise four behaviours.
///
/// The four behaviours that actually matter are: does a source get loaded, does
/// play/pause reach the player, does an externally-driven pause (a phone call,
/// headphones unplugged) get reflected in our state, and does a stop cancel work
/// that is still in flight.
abstract interface class AudioEngine {
  /// Load a remote source. Retained for the transition only — bundled assets are
  /// the target, and a guard test fails while any `http` source remains.
  Future<void> setUrl(String url);

  /// Load a bundled asset (`assets/audio/rain.m4a`).
  Future<void> setAsset(String asset);

  /// Loop the current source indefinitely when true.
  Future<void> setLoopMode(bool loopOne);

  /// 0.0–1.0. Callers are expected to have clamped already.
  Future<void> setVolume(double volume);

  Future<void> play();
  Future<void> pause();
  Future<void> stop();

  /// The player's own view of what it is doing.
  ///
  /// This is the important one. `just_audio` defaults `handleInterruptions` to
  /// true, so it pauses itself on a phone call and on the headphones-unplugged
  /// event **without the app asking**. Anything that caches its own `isPlaying`
  /// flag instead of following this stream ends up showing a pause button over
  /// silence, with no way for the user to recover.
  Stream<AudioEngineState> get stateStream;

  void dispose();
}

/// A snapshot of the player's state. Two booleans is the whole vocabulary the app
/// needs; anything more would be modelling the plugin rather than the feature.
class AudioEngineState {
  final bool playing;
  final bool completed;

  const AudioEngineState({required this.playing, required this.completed});

  @override
  String toString() =>
      'AudioEngineState(playing: $playing, completed: $completed)';
}

/// The real engine: a thin, mechanical wrapper over one `just_audio` player.
///
/// Every method here is a direct forward. Keep it that way — logic in the adapter
/// is logic the fake cannot reproduce, and the fake is the only reason this
/// interface exists.
class JustAudioEngine implements AudioEngine {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> setAsset(String asset) => _player.setAsset(asset);

  @override
  Future<void> setLoopMode(bool loopOne) =>
      _player.setLoopMode(loopOne ? LoopMode.one : LoopMode.off);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<AudioEngineState> get stateStream => _player.playerStateStream.map(
        (s) => AudioEngineState(
          playing: s.playing,
          completed: s.processingState == ProcessingState.completed,
        ),
      );

  @override
  void dispose() => _player.dispose();
}
