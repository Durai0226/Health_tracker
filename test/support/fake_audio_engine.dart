import 'dart:async';

import 'package:tablet_remainder/core/services/audio_engine.dart';

/// A recording, scriptable [AudioEngine] for headless tests.
///
/// Three knobs, chosen to cover every audio failure mode the real subsystem had:
///
///  * [throwOn] — a source that fails to load: offline, a dead URL, a missing
///    asset. 23 of the app's 29 audio sources were dead when this was written and
///    no test noticed, because the only audio test asserted URL *hostnames*.
///  * [hangOn] — a load that never resolves. The production retry chain could run
///    for up to 64 seconds (8 attempts × an 8s timeout) with no cancellation, so
///    abandoning a session inside that window left music playing with no session
///    behind it.
///  * [emitPlayerState] — the player changing state on its own. `just_audio`
///    pauses itself on a phone call or a headphone unplug without being asked, and
///    anything caching its own `isPlaying` flag then shows a pause button over
///    silence.
class FakeAudioEngine implements AudioEngine {
  final List<String> calls = <String>[];
  final List<String> loadedSources = <String>[];
  final List<double> volumes = <double>[];
  final List<bool> loopModes = <bool>[];

  final _state = StreamController<AudioEngineState>.broadcast();

  /// Method names that should throw instead of completing.
  final Set<String> throwOn = <String>{};

  /// Method names that should never complete.
  final Set<String> hangOn = <String>{};

  bool disposed = false;

  int get playCalls => calls.where((c) => c == 'play').length;
  int get pauseCalls => calls.where((c) => c == 'pause').length;
  int get stopCalls => calls.where((c) => c == 'stop').length;
  int get loadCalls =>
      calls.where((c) => c == 'setUrl' || c == 'setAsset').length;

  /// The most recently loaded source, or null if nothing ever loaded.
  String? get currentSource =>
      loadedSources.isEmpty ? null : loadedSources.last;

  void reset() {
    calls.clear();
    loadedSources.clear();
    volumes.clear();
    loopModes.clear();
    throwOn.clear();
    hangOn.clear();
    disposed = false;
  }

  /// Push a state the service did NOT ask for — the OS pausing playback.
  void emitPlayerState({required bool playing, bool completed = false}) {
    _state.add(AudioEngineState(playing: playing, completed: completed));
  }

  Future<void> _record(String method, [String? source]) {
    calls.add(method);
    if (source != null) loadedSources.add(source);
    if (hangOn.contains(method)) return Completer<void>().future;
    if (throwOn.contains(method)) {
      return Future.error(StateError('FakeAudioEngine: $method failed'));
    }
    return Future<void>.value();
  }

  @override
  Future<void> setUrl(String url) => _record('setUrl', url);

  @override
  Future<void> setAsset(String asset) => _record('setAsset', asset);

  @override
  Future<void> setLoopMode(bool loopOne) {
    loopModes.add(loopOne);
    return _record('setLoopMode');
  }

  @override
  Future<void> setVolume(double volume) {
    volumes.add(volume);
    return _record('setVolume');
  }

  @override
  Future<void> play() => _record('play');

  @override
  Future<void> pause() => _record('pause');

  @override
  Future<void> stop() => _record('stop');

  @override
  Stream<AudioEngineState> get stateStream => _state.stream;

  @override
  void dispose() {
    disposed = true;
    calls.add('dispose');
    _state.close();
  }
}
