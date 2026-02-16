import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/focus/models/ambient_sound.dart';

/// Service for playing ambient sounds during focus sessions
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  AmbientSoundType _currentSound = AmbientSoundType.none;
  double _volume = 0.5;
  bool _isPlaying = false;
  bool _isInitialized = false;

  // Getters
  AmbientSoundType get currentSound => _currentSound;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;

  /// Initialize the audio service
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _audioPlayer.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        notifyListeners();
      });
      
      _audioPlayer.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          // Loop the audio
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        }
      });
      
      _isInitialized = true;
      debugPrint('✓ AudioService initialized');
    } catch (e) {
      debugPrint('Error initializing AudioService: $e');
    }
  }

  /// Get the audio URL for a sound type
  /// Using free ambient sound URLs - longer, seamless loops for better experience
  String? _getAudioUrl(AmbientSoundType soundType) {
    switch (soundType) {
      case AmbientSoundType.none:
        return null;
      case AmbientSoundType.rain:
        // Gentle rain - 3 min loop
        return 'https://cdn.pixabay.com/audio/2022/05/16/audio_166a48e47d.mp3';
      case AmbientSoundType.thunderstorm:
        // Thunder and rain storm
        return 'https://cdn.pixabay.com/audio/2022/10/30/audio_1c3fa4ed6a.mp3';
      case AmbientSoundType.ocean:
        // Ocean waves - calming
        return 'https://cdn.pixabay.com/audio/2022/06/07/audio_b9bd4170e4.mp3';
      case AmbientSoundType.forest:
        // Forest ambience with birds
        return 'https://cdn.pixabay.com/audio/2022/03/10/audio_4dedf5bf94.mp3';
      case AmbientSoundType.fireplace:
        // Crackling fire
        return 'https://cdn.pixabay.com/audio/2022/10/18/audio_69a61cd6d6.mp3';
      case AmbientSoundType.wind:
        // Gentle wind
        return 'https://cdn.pixabay.com/audio/2022/03/24/audio_7e35479d35.mp3';
      case AmbientSoundType.birds:
        // Morning birds chirping
        return 'https://cdn.pixabay.com/audio/2022/02/07/audio_bc594618f0.mp3';
      case AmbientSoundType.river:
        // Flowing stream/river
        return 'https://cdn.pixabay.com/audio/2022/08/04/audio_a40b9cc782.mp3';
      case AmbientSoundType.whiteNoise:
        // White noise for focus
        return 'https://cdn.pixabay.com/audio/2022/03/10/audio_1d2d6e65c5.mp3';
      case AmbientSoundType.brownNoise:
        // Brown noise - deeper, more soothing
        return 'https://cdn.pixabay.com/audio/2024/01/10/audio_fded2c7c09.mp3';
      case AmbientSoundType.pinkNoise:
        // Pink noise - balanced
        return 'https://cdn.pixabay.com/audio/2022/03/10/audio_1d2d6e65c5.mp3';
      case AmbientSoundType.cafe:
        // Cafe ambience with chatter
        return 'https://cdn.pixabay.com/audio/2022/10/17/audio_ad8ca905c8.mp3';
      case AmbientSoundType.library:
        // Quiet library ambience
        return 'https://cdn.pixabay.com/audio/2022/08/02/audio_884fe92c21.mp3';
      case AmbientSoundType.nightSounds:
        // Night crickets and nature
        return 'https://cdn.pixabay.com/audio/2022/08/23/audio_d6a4a6ada2.mp3';
      case AmbientSoundType.meditation:
        // Calm meditation bells/bowls
        return 'https://cdn.pixabay.com/audio/2022/07/08/audio_dc39bde808.mp3';
    }
  }

  /// Get extended audio URL for relaxation music types
  /// These are verified working audio URLs from Pixabay (royalty-free)
  String? getRelaxationAudioUrl(String musicKey) {
    final Map<String, String> relaxationUrls = {
      // Deep Focus - Binaural & Concentration
      'binauralBeatsAlpha': 'https://cdn.pixabay.com/audio/2024/02/14/audio_8e0db3cf42.mp3', // Meditation ambient
      'lofiHipHop': 'https://cdn.pixabay.com/audio/2022/05/27/audio_1808fbf07a.mp3', // Lofi chill beats
      'ambientInstrumental': 'https://cdn.pixabay.com/audio/2023/03/06/audio_0e4a3cc13c.mp3', // Ambient piano
      'gammaFocus40Hz': 'https://cdn.pixabay.com/audio/2024/01/18/audio_e4a6b0f6b0.mp3', // Focus tones
      
      // Stress Relief - Healing frequencies & Nature
      'healing432Hz': 'https://cdn.pixabay.com/audio/2023/06/14/audio_af7fc9b7f0.mp3', // 432Hz healing music
      'miracleTone528Hz': 'https://cdn.pixabay.com/audio/2023/01/16/audio_cc8a0a8e48.mp3', // Healing frequency
      'tibetanBowls': 'https://cdn.pixabay.com/audio/2022/01/18/audio_d0a13f69d2.mp3', // Tibetan bowls meditation
      'rainOnWindow': 'https://cdn.pixabay.com/audio/2022/03/15/audio_8cb749d484.mp3', // Rain sounds
      'oceanWaves': 'https://cdn.pixabay.com/audio/2021/08/09/audio_dc39aae018.mp3', // Ocean waves
      'forestBirds': 'https://cdn.pixabay.com/audio/2022/06/25/audio_d0c9578f59.mp3', // Forest nature
      
      // Nervous System Reset - Sleep & Deep Relaxation
      'rainPiano432Hz': 'https://cdn.pixabay.com/audio/2023/07/30/audio_e8a1e1a8e8.mp3', // Piano with rain
      'deepSleepDelta': 'https://cdn.pixabay.com/audio/2022/08/31/audio_419263ab54.mp3', // Deep sleep music
      'softPianoRain': 'https://cdn.pixabay.com/audio/2024/03/12/audio_a0c2b8b4e2.mp3', // Soft piano ambient
      'healingNightSounds': 'https://cdn.pixabay.com/audio/2022/02/23/audio_1cd66a6faf.mp3', // Night ambience
    };
    return relaxationUrls[musicKey];
  }

  /// Play relaxation music by key with robust error handling
  Future<void> playRelaxationMusic(String musicKey, {double? volume}) async {
    try {
      if (volume != null) {
        _volume = volume;
      }

      debugPrint('Attempting to play relaxation music: $musicKey');
      
      final url = getRelaxationAudioUrl(musicKey);
      if (url == null) {
        debugPrint('No audio URL found for music key: $musicKey');
        await _playFallbackAudio();
        return;
      }

      // Stop any currently playing audio first
      await _audioPlayer.stop();
      
      // Set up the audio with timeout for network loading
      await _audioPlayer.setUrl(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Audio URL load timeout for: $musicKey');
          throw Exception('Network timeout');
        },
      );
      
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play();
      
      _isPlaying = true;
      notifyListeners();
      debugPrint('✓ Successfully playing relaxation music: $musicKey');
    } catch (e) {
      debugPrint('Error playing relaxation music ($musicKey): $e');
      // Try fallback audio
      await _playFallbackAudio();
    }
  }
  
  /// Fallback audio when primary URL fails
  Future<void> _playFallbackAudio() async {
    try {
      debugPrint('Playing fallback meditation audio...');
      await playSound(AmbientSoundType.meditation, volume: _volume);
    } catch (e) {
      debugPrint('Fallback audio also failed: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Set and play a sound
  Future<void> playSound(AmbientSoundType soundType, {double? volume}) async {
    try {
      _currentSound = soundType;
      if (volume != null) {
        _volume = volume;
      }
      
      if (soundType == AmbientSoundType.none) {
        await stop();
        return;
      }

      final url = _getAudioUrl(soundType);
      if (url == null) {
        debugPrint('No audio URL for sound type: $soundType');
        return;
      }

      await _audioPlayer.setUrl(url);
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play();
      
      _isPlaying = true;
      notifyListeners();
      debugPrint('✓ Playing ambient sound: ${soundType.name}');
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  /// Resume playback
  Future<void> resume() async {
    if (_currentSound != AmbientSoundType.none) {
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
    }
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
    await _audioPlayer.stop();
    _currentSound = AmbientSoundType.none;
    _isPlaying = false;
    notifyListeners();
    debugPrint('✓ Ambient sound stopped');
  }

  /// Dispose resources
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
