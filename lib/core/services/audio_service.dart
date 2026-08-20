import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_engine.dart';
import '../../features/focus/models/ambient_sound.dart';

/// Service for playing ambient sounds during focus sessions
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  /// Lazily created, and that is the whole point.
  ///
  /// As a field initialiser this constructed a real `just_audio` player — and so
  /// opened a platform channel and touched `AudioSession.instance` — the first time
  /// anything so much as *referenced* `AudioService()`. In a headless test that
  /// throws before a substitute engine can be installed, which is why the seam
  /// has to be lazy rather than merely swappable.
  AudioEngine? _engineOverride;
  AudioEngine get _engine => _engineOverride ??= JustAudioEngine();
  StreamSubscription<AudioEngineState>? _stateSub;

  /// The source currently loaded in the engine, or null if nothing is.
  ///
  /// This replaces `_currentSound` as the resume gate. `_currentSound` describes
  /// which ambient sound the USER picked — it is `none` for relaxation music, and
  /// `stop()` clears it — so gating playback on it meant "resume" silently did
  /// nothing after relaxation playback, and after every session end.
  String? _loadedSource;

  /// How to re-load the last thing that was playing.
  ///
  /// `stop()` releases the engine's source, so resuming afterwards needs a reload
  /// rather than a bare `play()`. Kept across stops on purpose: the Focus screen's
  /// ambient play button has to work again after a session ends.
  Future<void> Function()? _replayLast;

  /// Substitute the engine in tests.
  ///
  /// Also resets the derived state, because this singleton outlives any one test:
  /// leaving `_isPlaying` true from a previous test would make the next one pass
  /// for the wrong reason.
  @visibleForTesting
  set engineForTesting(AudioEngine engine) {
    _loadedSource = null;
    _replayLast = null;
    _stateSub?.cancel();
    _stateSub = null;
    _engineOverride = engine;
    _isInitialized = false;
    _isPlaying = false;
    _currentSound = AmbientSoundType.none;
  }
  
  AmbientSoundType _currentSound = AmbientSoundType.none;
  double _volume = 0.5;
  bool _isPlaying = false;
  bool _isInitialized = false;

  /// The last user-facing audio problem, or null.
  ///
  /// Previously every failure was a `debugPrint` and nothing observed it, so
  /// a silent session was indistinguishable from a working one — with a live
  /// countdown, a volume slider and a completion notification, in total
  /// silence.
  String? _lastError;

  // Getters
  AmbientSoundType get currentSound => _currentSound;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;
  String? get lastError => _lastError;

  /// Initialize the audio service
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // The player is the source of truth for "is sound coming out".
      // `just_audio` defaults handleInterruptions to true and pauses itself on a
      // phone call or a headphone unplug, so a cached flag desynchronises and the
      // UI ends up showing a pause button over silence.
      _stateSub?.cancel();
      _stateSub = _engine.stateStream.listen((state) {
        if (_isPlaying == state.playing) return;
        _isPlaying = state.playing;
        notifyListeners();
      });

      // A `processingStateStream` listener used to live here, re-seeking to zero
      // and replaying on completion. It was dead code under single-track looping
      // (which never reports completion) and would have been audibly gappy if it
      // ever fired — you hear the buffer drain, then re-buffer. Looping belongs to
      // the engine.
      
      _isInitialized = true;
      debugPrint('✓ AudioService initialized');
    } catch (e) {
      debugPrint('Error initializing AudioService: $e');
    }
  }

  /// Get the audio URL for a sound type
  /// Using free ambient sound URLs - longer, seamless loops for better experience
  // ---- the audio catalogue -------------------------------------------------
  //
  // ONE table, of bundled assets. What was here before: two byte-identical maps
  // of hotlinked third-party URLs (a private one that shipped and a public one
  // only tests called, guaranteed to drift), a six-entry generic fallback list,
  // an eight-second-per-attempt timeout and a retry loop that could spend 64
  // seconds failing. Measured at the time: 11 of 14 relaxation URLs returned 404
  // and 12 of 15 ambient URLs returned 403, and every relaxation fallback landed
  // on an algorithmic-music DEMO endpoint — so "Deep Sleep Delta Waves" played
  // generated techno. The test suite was green throughout, because it asserted
  // the URLs' hostnames.
  //
  // Local assets delete that failure mode rather than monitoring it: nothing can
  // 404, nothing can be hotlink-blocked, and it works on a plane. A guard test
  // fails if any `http` source reappears or a declared asset is missing.
  static const String _dir = 'assets/audio';

  /// Ambient sounds for the focus timer.
  ///
  /// `whiteNoise` and `pinkNoise` used to point at the SAME URL. They are now
  /// distinct generated files — see `tool/gen_noise.dart`.
  ///
  /// THE MAP IS A PROMISE: only declare what is on disk. This table listed all
  /// fifteen sounds while twelve of the files did not exist, so twelve of the
  /// fifteen chips in the picker started a session and played nothing — and the
  /// "every declared asset exists on disk" guard was red, which meant CI was red,
  /// which meant no other gate in the feature could be trusted.
  ///
  /// The twelve are being sourced in waves (see `docs/audio-sourcing.md`, and the
  /// `pending` block in `assets/audio/LICENSES.json` which names each one). Each
  /// wave is a one-line entry here plus the file plus its licence record, landing
  /// together in one commit so this table is never ahead of the disk again.
  ///
  /// Do NOT close the gap by synthesising these in `tool/gen_noise.dart`. Filtered
  /// noise can approximate rain or ocean well enough to pass, and that is the same
  /// dishonesty that put two names on one URL. White, pink and brown noise are
  /// generated because each one *is* a DSP definition; "rain" is a claim about a
  /// recording.
  static const Map<AmbientSoundType, String> _ambientAssets = {
    AmbientSoundType.whiteNoise: '$_dir/white_noise.wav',
    AmbientSoundType.brownNoise: '$_dir/brown_noise.wav',
    AmbientSoundType.pinkNoise: '$_dir/pink_noise.wav',
  };

  /// Relaxation tracks, keyed by the enum's identifier.
  ///
  /// Deliberately a SUBSET. The catalogue advertises fourteen tracks, but CC0
  /// *music* is scarce in a way CC0 field recordings are not, so the entries with
  /// no honest asset behind them resolve to null and are filtered out of the
  /// picker rather than pointed at something they are not. Mapping several names
  /// onto one file is exactly how `whiteNoise` and `pinkNoise` ended up sharing a
  /// URL, and it is the thing that made this catalogue untrustworthy.
  ///
  /// The enum itself is untouched: its indices are the persisted wire format, so
  /// removing values would reinterpret every stored session.
  static const Map<String, String> _relaxationAssets = {
    'deepSleepDelta': '$_dir/brown_noise.wav',
    'binauralBeatsAlpha': '$_dir/pink_noise.wav',
    'gammaFocus40Hz': '$_dir/white_noise.wav',
  };

  /// Every asset this service can ask for — the guard test's input.
  @visibleForTesting
  static List<String> get debugAllSources => {
        ..._ambientAssets.values,
        ..._relaxationAssets.values,
      }.toList()
        ..sort();

  /// Whether a relaxation track has audio behind it. The picker uses this to hide
  /// the ones that do not, instead of offering silence.
  static bool hasRelaxationAudio(String musicKey) =>
      _relaxationAssets.containsKey(musicKey);

  /// Whether an ambient sound has audio behind it.
  ///
  /// [AmbientSoundType.none] is deliberately true: "no sound" is a real, working
  /// choice and must stay in the picker.
  static bool hasAmbientAudio(AmbientSoundType sound) =>
      sound == AmbientSoundType.none || _ambientAssets.containsKey(sound);

  /// The ambient sounds that actually play, excluding [AmbientSoundType.none].
  ///
  /// `AchievementType.soundExplorer` is defined against this count rather than a
  /// literal, so shrinking or growing the catalogue can never leave a visible
  /// achievement permanently out of reach.
  static Set<AmbientSoundType> get playableAmbientSounds =>
      _ambientAssets.keys.toSet();

  /// Play a relaxation track. Straight-line: load, loop, set volume, play.
  Future<void> playRelaxationMusic(String musicKey, {double? volume}) async {
    if (volume != null) _volume = volume;
    _replayLast = () => playRelaxationMusic(musicKey, volume: volume);
    await init();

    final asset = _relaxationAssets[musicKey];
    if (asset == null) {
      // No retry chain to fall through: there is nothing to retry to. Surfacing
      // this beats the old behaviour, which started a fully-functional countdown
      // and played an unrelated song.
      debugPrint('No bundled audio for relaxation track: $musicKey');
      _lastError = 'That track is not available yet.';
      _isPlaying = false;
      notifyListeners();
      return;
    }
    await _play(asset, label: musicKey);
  }

  /// Select and play an ambient sound.
  Future<void> playSound(AmbientSoundType soundType, {double? volume}) async {
    _currentSound = soundType;
    if (volume != null) _volume = volume;
    if (soundType != AmbientSoundType.none) {
      _replayLast = () => playSound(soundType, volume: volume);
    }
    await init();

    if (soundType == AmbientSoundType.none) {
      await stop();
      return;
    }
    final asset = _ambientAssets[soundType];
    if (asset == null) {
      debugPrint('No bundled audio for ambient sound: ${soundType.name}');
      _lastError = 'That sound is not available yet.';
      _isPlaying = false;
      notifyListeners();
      return;
    }
    await _play(asset, label: soundType.name);
  }

  /// The one place audio actually starts.
  Future<void> _play(String asset, {required String label}) async {
    try {
      await _engine.setAsset(asset);
      await _engine.setLoopMode(true);
      await _engine.setVolume(_volume);
      await _engine.play();
      _loadedSource = asset;
      _lastError = null;
      _isPlaying = true;
      notifyListeners();
      debugPrint('✓ Playing $label from $asset');
    } catch (e) {
      // Audio failing must never take the caller down with it — a focus session
      // has to keep running in silence.
      debugPrint('Could not play $label ($asset): $e');
      _lastError = 'Could not play that sound.';
      _loadedSource = null;
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _engine.setVolume(_volume);
    notifyListeners();
  }

  /// Pause playback
  Future<void> pause() async {
    await _engine.pause();
    _isPlaying = false;
    notifyListeners();
  }

  /// Resume playback
  Future<void> resume() async {
    if (_loadedSource != null) {
      await _engine.play();
      _isPlaying = true;
      notifyListeners();
      return;
    }
    // Nothing loaded — the engine was stopped, so play() alone would be a no-op.
    // Re-load whatever was playing last.
    final replay = _replayLast;
    if (replay != null) await replay();
  }

  /// Toggle play/pause
  Future<void> toggle() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Stop and reset
  Future<void> stop() async {
    await _engine.stop();
    _loadedSource = null; // the engine has released it; a resume must reload
    _currentSound = AmbientSoundType.none;
    _isPlaying = false;
    notifyListeners();
    debugPrint('✓ Ambient sound stopped');
  }

  /// Fresh state between tests, WITHOUT disposing the engine.
  ///
  /// Disposing is the trap: `AudioService` is process-wide and owns the app's only
  /// player, so a `dispose()` anywhere kills audio for the rest of the process.
  /// A dead wellness service used to do exactly that; a guard test now forbids it.
  @visibleForTesting
  void resetForTesting() {
    _loadedSource = null;
    _replayLast = null;
    _stateSub?.cancel();
    _stateSub = null;
    _isInitialized = false;
    _isPlaying = false;
    _currentSound = AmbientSoundType.none;
    _volume = 0.5;
  }

  /// Dispose resources
  @override
  void dispose() {
    _stateSub?.cancel();
    _stateSub = null;
    // Only dispose a player that actually exists — reading `_engine` here would
    // CREATE one.
    _engineOverride?.dispose();
    _engineOverride = null;
    super.dispose();
  }
}
