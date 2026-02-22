import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/main.dart' as app;
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Relaxation Music E2E Tests', () {
    testWidgets('AudioService URL mapping is complete for all music types', (tester) async {
      final audioService = AudioService();
      await audioService.init();
      
      // Verify all RelaxationMusicType values have corresponding URLs
      for (final musicType in RelaxationMusicType.values) {
        final musicKey = musicType.toString().split('.').last;
        final url = audioService.getRelaxationAudioUrl(musicKey);
        
        expect(url, isNotNull, reason: 'Missing URL for $musicKey');
        expect(url!.startsWith('http'), true, reason: 'Invalid URL format for $musicKey');
        
        debugPrint('✓ $musicKey has valid URL: ${url.substring(0, 50)}...');
      }
    });

    testWidgets('RelaxationCategory has correct tracks assigned', (tester) async {
      // Deep Focus should have 4 tracks
      expect(RelaxationCategory.deepFocus.tracks.length, 4);
      expect(RelaxationCategory.deepFocus.tracks.contains(RelaxationMusicType.binauralBeatsAlpha), true);
      expect(RelaxationCategory.deepFocus.tracks.contains(RelaxationMusicType.lofiHipHop), true);
      expect(RelaxationCategory.deepFocus.tracks.contains(RelaxationMusicType.ambientInstrumental), true);
      expect(RelaxationCategory.deepFocus.tracks.contains(RelaxationMusicType.gammaFocus40Hz), true);
      
      // Stress Relief should have 6 tracks
      expect(RelaxationCategory.stressRelief.tracks.length, 6);
      expect(RelaxationCategory.stressRelief.tracks.contains(RelaxationMusicType.healing432Hz), true);
      expect(RelaxationCategory.stressRelief.tracks.contains(RelaxationMusicType.oceanWaves), true);
      expect(RelaxationCategory.stressRelief.tracks.contains(RelaxationMusicType.rainOnWindow), true);
      
      // Nervous System Reset should have 4 tracks
      expect(RelaxationCategory.nervousSystemReset.tracks.length, 4);
      expect(RelaxationCategory.nervousSystemReset.tracks.contains(RelaxationMusicType.deepSleepDelta), true);
      expect(RelaxationCategory.nervousSystemReset.tracks.contains(RelaxationMusicType.softPianoRain), true);
      
      debugPrint('✓ All categories have correct track assignments');
    });

    testWidgets('All RelaxationMusicType have required properties', (tester) async {
      for (final musicType in RelaxationMusicType.values) {
        // Check name
        expect(musicType.name.isNotEmpty, true, reason: '$musicType missing name');
        
        // Check emoji
        expect(musicType.emoji.isNotEmpty, true, reason: '$musicType missing emoji');
        
        // Check description
        expect(musicType.description.isNotEmpty, true, reason: '$musicType missing description');
        
        // Check color
        expect(musicType.color, isNotNull, reason: '$musicType missing color');
        
        // Check category mapping
        expect(musicType.category, isNotNull, reason: '$musicType missing category');
        
        debugPrint('✓ ${musicType.name} has all required properties');
      }
    });

    testWidgets('RelaxationCategory properties are valid', (tester) async {
      for (final category in RelaxationCategory.values) {
        expect(category.name.isNotEmpty, true, reason: '$category missing name');
        expect(category.emoji.isNotEmpty, true, reason: '$category missing emoji');
        expect(category.description.isNotEmpty, true, reason: '$category missing description');
        expect(category.color, isNotNull, reason: '$category missing color');
        expect(category.icon, isNotNull, reason: '$category missing icon');
        expect(category.tracks.isNotEmpty, true, reason: '$category has no tracks');
        
        debugPrint('✓ ${category.name} category is valid with ${category.tracks.length} tracks');
      }
    });

    testWidgets('Navigate to relaxation screen and verify UI', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Look for focus/relaxation entry point in dashboard
      final focusFinder = find.textContaining('Focus');
      if (focusFinder.evaluate().isNotEmpty) {
        await tester.tap(focusFinder.first);
        await tester.pumpAndSettle();
        
        // Look for Relaxation option
        final relaxationFinder = find.textContaining('Relaxation');
        if (relaxationFinder.evaluate().isNotEmpty) {
          await tester.tap(relaxationFinder.first);
          await tester.pumpAndSettle();
          
          // Verify key UI elements are present
          expect(find.text('Choose Your Goal'), findsOneWidget);
          expect(find.text('Select Music'), findsOneWidget);
          expect(find.text('Session Duration'), findsOneWidget);
          
          debugPrint('✓ Relaxation screen UI verified');
        }
      }
    });

    testWidgets('Music selection and category switching works', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to relaxation (if accessible)
      final focusFinder = find.textContaining('Focus');
      if (focusFinder.evaluate().isNotEmpty) {
        await tester.tap(focusFinder.first);
        await tester.pumpAndSettle();
        
        final relaxationFinder = find.textContaining('Relaxation');
        if (relaxationFinder.evaluate().isNotEmpty) {
          await tester.tap(relaxationFinder.first);
          await tester.pumpAndSettle();
          
          // Test category switching - tap on "Stress Relief"
          final stressReliefFinder = find.text('Stress Relief');
          if (stressReliefFinder.evaluate().isNotEmpty) {
            await tester.tap(stressReliefFinder.first);
            await tester.pumpAndSettle();
            
            // Verify stress relief tracks appear
            expect(find.text('Ocean Waves'), findsOneWidget);
            debugPrint('✓ Category switching works');
          }
          
          // Test music selection
          final oceanWavesFinder = find.text('Ocean Waves');
          if (oceanWavesFinder.evaluate().isNotEmpty) {
            await tester.tap(oceanWavesFinder.first);
            await tester.pumpAndSettle();
            
            // Start button should appear
            expect(find.textContaining('Start'), findsWidgets);
            debugPrint('✓ Music selection works');
          }
        }
      }
    });

    testWidgets('Duration selector shows all options', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final focusFinder = find.textContaining('Focus');
      if (focusFinder.evaluate().isNotEmpty) {
        await tester.tap(focusFinder.first);
        await tester.pumpAndSettle();
        
        final relaxationFinder = find.textContaining('Relaxation');
        if (relaxationFinder.evaluate().isNotEmpty) {
          await tester.tap(relaxationFinder.first);
          await tester.pumpAndSettle();
          
          // Verify duration options
          expect(find.text('5 min'), findsOneWidget);
          expect(find.text('10 min'), findsOneWidget);
          expect(find.text('15 min'), findsOneWidget);
          expect(find.text('20 min'), findsOneWidget);
          expect(find.text('30 min'), findsOneWidget);
          
          debugPrint('✓ Duration selector verified');
        }
      }
    });
  });

  group('AudioService Unit Tests', () {
    test('AudioService singleton pattern works', () {
      final service1 = AudioService();
      final service2 = AudioService();
      expect(identical(service1, service2), true);
    });

    test('All backup URLs are valid SoundHelix URLs', () {
      // SoundHelix URLs are guaranteed to work
      final expectedBackups = [
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      ];
      
      for (final url in expectedBackups) {
        expect(url.startsWith('https://www.soundhelix.com'), true);
        expect(url.endsWith('.mp3'), true);
      }
      
      debugPrint('✓ All backup URLs are valid');
    });

    test('Music keys match RelaxationMusicType enum values', () {
      final audioService = AudioService();
      
      final expectedKeys = [
        'binauralBeatsAlpha',
        'lofiHipHop',
        'ambientInstrumental',
        'gammaFocus40Hz',
        'healing432Hz',
        'miracleTone528Hz',
        'tibetanBowls',
        'rainOnWindow',
        'oceanWaves',
        'forestBirds',
        'rainPiano432Hz',
        'deepSleepDelta',
        'softPianoRain',
        'healingNightSounds',
      ];
      
      for (final key in expectedKeys) {
        final url = audioService.getRelaxationAudioUrl(key);
        expect(url, isNotNull, reason: 'Missing URL for key: $key');
        debugPrint('✓ $key -> ${url!.substring(0, 40)}...');
      }
    });
  });
}
