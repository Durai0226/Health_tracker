import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('AudioService Relaxation Music Tests', () {
    late AudioService audioService;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      audioService = AudioService();
    });

    test('All RelaxationMusicType values have corresponding URLs', () {
      for (final musicType in RelaxationMusicType.values) {
        final musicKey = musicType.toString().split('.').last;
        final url = audioService.getRelaxationAudioUrl(musicKey);
        
        expect(url, isNotNull, reason: 'Missing URL for $musicKey');
        expect(url!.startsWith('http'), true, reason: 'Invalid URL format for $musicKey: $url');
      }
    });

    test('Deep Focus tracks have valid URLs', () {
      final deepFocusTracks = [
        'binauralBeatsAlpha',
        'lofiHipHop',
        'ambientInstrumental',
        'gammaFocus40Hz',
      ];
      
      for (final key in deepFocusTracks) {
        final url = audioService.getRelaxationAudioUrl(key);
        expect(url, isNotNull, reason: 'Missing URL for Deep Focus track: $key');
        expect(url!.contains('http'), true);
      }
    });

    test('Stress Relief tracks have valid URLs', () {
      final stressReliefTracks = [
        'healing432Hz',
        'miracleTone528Hz',
        'tibetanBowls',
        'rainOnWindow',
        'oceanWaves',
        'forestBirds',
      ];
      
      for (final key in stressReliefTracks) {
        final url = audioService.getRelaxationAudioUrl(key);
        expect(url, isNotNull, reason: 'Missing URL for Stress Relief track: $key');
        expect(url!.contains('http'), true);
      }
    });

    test('Nervous System Reset tracks have valid URLs', () {
      final sleepTracks = [
        'rainPiano432Hz',
        'deepSleepDelta',
        'softPianoRain',
        'healingNightSounds',
      ];
      
      for (final key in sleepTracks) {
        final url = audioService.getRelaxationAudioUrl(key);
        expect(url, isNotNull, reason: 'Missing URL for Sleep track: $key');
        expect(url!.contains('http'), true);
      }
    });

    test('AudioService is singleton', () {
      final service1 = AudioService();
      final service2 = AudioService();
      expect(identical(service1, service2), true);
    });

    test('RelaxationMusicType to key conversion works correctly', () {
      for (final musicType in RelaxationMusicType.values) {
        final key = musicType.toString().split('.').last;
        
        // Key should be camelCase (enum name format)
        expect(key.isNotEmpty, true);
        expect(key[0].toLowerCase(), key[0], reason: 'Key should start with lowercase: $key');
      }
    });

    test('All categories have tracks with URLs', () {
      for (final category in RelaxationCategory.values) {
        expect(category.tracks.isNotEmpty, true, reason: '${category.name} has no tracks');
        
        for (final track in category.tracks) {
          final key = track.toString().split('.').last;
          final url = audioService.getRelaxationAudioUrl(key);
          expect(url, isNotNull, reason: '${category.name} track $key has no URL');
        }
      }
    });

    test('URLs are from expected sources', () {
      for (final musicType in RelaxationMusicType.values) {
        final key = musicType.toString().split('.').last;
        final url = audioService.getRelaxationAudioUrl(key);
        
        // URLs should be from Free Music Archive or SoundHelix
        final isValidSource = url!.contains('freemusicarchive.org') || 
                              url.contains('soundhelix.com') ||
                              url.contains('archive.org');
        
        expect(isValidSource, true, reason: 'URL for $key is not from a known source: $url');
      }
    });
  });

  group('RelaxationMusic Model Tests', () {
    test('All music types belong to a category', () {
      for (final musicType in RelaxationMusicType.values) {
        expect(musicType.category, isNotNull);
        expect(RelaxationCategory.values.contains(musicType.category), true);
      }
    });

    test('Category tracks contain correct music types', () {
      // Deep Focus
      expect(RelaxationCategory.deepFocus.tracks, contains(RelaxationMusicType.binauralBeatsAlpha));
      expect(RelaxationCategory.deepFocus.tracks, contains(RelaxationMusicType.lofiHipHop));
      
      // Stress Relief
      expect(RelaxationCategory.stressRelief.tracks, contains(RelaxationMusicType.oceanWaves));
      expect(RelaxationCategory.stressRelief.tracks, contains(RelaxationMusicType.rainOnWindow));
      
      // Nervous System Reset
      expect(RelaxationCategory.nervousSystemReset.tracks, contains(RelaxationMusicType.deepSleepDelta));
    });

    test('Music type properties are valid', () {
      for (final musicType in RelaxationMusicType.values) {
        expect(musicType.name.isNotEmpty, true);
        expect(musicType.emoji.isNotEmpty, true);
        expect(musicType.description.isNotEmpty, true);
        expect(musicType.color, isNotNull);
        expect(musicType.icon, isNotNull);
      }
    });

    test('Category properties are valid', () {
      for (final category in RelaxationCategory.values) {
        expect(category.name.isNotEmpty, true);
        expect(category.emoji.isNotEmpty, true);
        expect(category.description.isNotEmpty, true);
        expect(category.color, isNotNull);
        expect(category.icon, isNotNull);
        expect(category.tracks.isNotEmpty, true);
      }
    });
  });
}
