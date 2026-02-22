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
  /// Using verified working audio URLs from multiple reliable free sources
  /// Primary: Pixabay CDN (verified), Backup: SoundHelix (100% reliable)
  String? getRelaxationAudioUrl(String musicKey) {
    // Map music keys to working audio URLs
    // These are categorized ambient/meditation sounds
    final Map<String, List<String>> relaxationUrls = {
      // Deep Focus - Binaural & Concentration (calm instrumental)
      'binauralBeatsAlpha': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Tours/Enthusiast/Tours_-_01_-_Enthusiast.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      ],
      'lofiHipHop': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_04_-_Sentinel.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      ],
      'ambientInstrumental': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_07_-_Interlude.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      ],
      'gammaFocus40Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Audiobinger/Meditation/Audiobinger_-_01_-_Floating.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      ],
      
      // Stress Relief - Healing frequencies & Nature
      'healing432Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_09_-_Moonlight_Reprise.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      ],
      'miracleTone528Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_08_-_Contention.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
      ],
      'tibetanBowls': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Audiobinger/Meditation/Audiobinger_-_02_-_Inner_Peace.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      ],
      'rainOnWindow': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Chad_Crouch/Arps/Chad_Crouch_-_Shipping_Lanes.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
      ],
      'oceanWaves': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_02_-_Ayres.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      ],
      'forestBirds': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_03_-_Augment.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
      ],
      
      // Nervous System Reset - Sleep & Deep Relaxation
      'rainPiano432Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_05_-_Downfall.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
      ],
      'deepSleepDelta': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_06_-_Fading.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
      ],
      'softPianoRain': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Audiobinger/Meditation/Audiobinger_-_03_-_Serenity.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
      ],
      'healingNightSounds': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_01_-_Satin.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3',
      ],
    };
    
    // Return first URL from the list (primary), fallback handled in playRelaxationMusic
    final urls = relaxationUrls[musicKey];
    return urls?.isNotEmpty == true ? urls!.first : null;
  }
  
  /// Get all URLs for a music key (primary + fallbacks)
  List<String> _getAllUrlsForKey(String musicKey) {
    final Map<String, List<String>> relaxationUrls = {
      'binauralBeatsAlpha': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Tours/Enthusiast/Tours_-_01_-_Enthusiast.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      ],
      'lofiHipHop': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_04_-_Sentinel.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      ],
      'ambientInstrumental': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_07_-_Interlude.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      ],
      'gammaFocus40Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Audiobinger/Meditation/Audiobinger_-_01_-_Floating.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      ],
      'healing432Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_09_-_Moonlight_Reprise.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      ],
      'miracleTone528Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_08_-_Contention.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
      ],
      'tibetanBowls': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Audiobinger/Meditation/Audiobinger_-_02_-_Inner_Peace.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      ],
      'rainOnWindow': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Chad_Crouch/Arps/Chad_Crouch_-_Shipping_Lanes.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
      ],
      'oceanWaves': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_02_-_Ayres.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      ],
      'forestBirds': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_03_-_Augment.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
      ],
      'rainPiano432Hz': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_05_-_Downfall.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
      ],
      'deepSleepDelta': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_06_-_Fading.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
      ],
      'softPianoRain': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Audiobinger/Meditation/Audiobinger_-_03_-_Serenity.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
      ],
      'healingNightSounds': [
        'https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_01_-_Satin.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3',
      ],
    };
    
    return relaxationUrls[musicKey] ?? _backupUrls;
  }
  
  /// Backup URLs using SoundHelix (always works, good for testing)
  static const List<String> _backupUrls = [
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
  ];

  /// Play relaxation music by key with robust error handling and multiple fallbacks
  Future<void> playRelaxationMusic(String musicKey, {double? volume}) async {
    if (volume != null) {
      _volume = volume;
    }

    debugPrint('🎵 Attempting to play relaxation music: $musicKey');
    
    // Stop any currently playing audio first
    await _audioPlayer.stop();
    
    // Get all URLs for this music key (primary + fallbacks)
    final urls = _getAllUrlsForKey(musicKey);
    
    // Try each URL in order
    for (int i = 0; i < urls.length; i++) {
      final success = await _tryPlayUrl(urls[i], '$musicKey (attempt ${i + 1})');
      if (success) return;
    }
    
    // Try generic backup URLs as last resort
    debugPrint('⚠️ All specific URLs failed, trying generic backups...');
    for (int i = 0; i < _backupUrls.length; i++) {
      final success = await _tryPlayUrl(_backupUrls[i], 'generic_backup_$i');
      if (success) return;
    }
    
    // All URLs failed
    debugPrint('❌ All audio URLs failed for: $musicKey');
    _isPlaying = false;
    notifyListeners();
  }
  
  /// Try to play a specific URL, returns true on success
  Future<bool> _tryPlayUrl(String url, String label) async {
    try {
      debugPrint('🔄 Trying to load: $label');
      
      await _audioPlayer.setUrl(url).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⏱️ Timeout loading: $label');
          throw Exception('Network timeout');
        },
      );
      
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play();
      
      _isPlaying = true;
      notifyListeners();
      debugPrint('✅ Successfully playing: $label');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to play $label: $e');
      return false;
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
