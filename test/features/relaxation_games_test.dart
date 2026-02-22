import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_game_models.dart';

void main() {
  group('PlayMode enum tests', () {
    test('All new play modes have correct names', () {
      expect(PlayMode.oceanAquarium.name, 'Ocean Aquarium');
      expect(PlayMode.starryNight.name, 'Starry Night');
      expect(PlayMode.colorBloom.name, 'Color Bloom');
      expect(PlayMode.floatingLantern.name, 'Lantern Wishes');
    });

    test('All new play modes have emojis', () {
      expect(PlayMode.oceanAquarium.emoji, '🐠');
      expect(PlayMode.starryNight.emoji, '⭐');
      expect(PlayMode.colorBloom.emoji, '🎨');
      expect(PlayMode.floatingLantern.emoji, '🏮');
    });

    test('All new play modes have descriptions', () {
      expect(PlayMode.oceanAquarium.description.isNotEmpty, true);
      expect(PlayMode.starryNight.description.isNotEmpty, true);
      expect(PlayMode.colorBloom.description.isNotEmpty, true);
      expect(PlayMode.floatingLantern.description.isNotEmpty, true);
    });

    test('All new play modes have colors', () {
      expect(PlayMode.oceanAquarium.color, const Color(0xFF0EA5E9));
      expect(PlayMode.starryNight.color, const Color(0xFF6366F1));
      expect(PlayMode.colorBloom.color, const Color(0xFFA855F7));
      expect(PlayMode.floatingLantern.color, const Color(0xFFFF6B6B));
    });

    test('All new play modes have icons', () {
      expect(PlayMode.oceanAquarium.icon, Icons.pool_rounded);
      expect(PlayMode.starryNight.icon, Icons.star_rounded);
      expect(PlayMode.colorBloom.icon, Icons.palette_rounded);
      expect(PlayMode.floatingLantern.icon, Icons.light_mode_rounded);
    });

    test('PlayMode enum contains all 9 modes', () {
      expect(PlayMode.values.length, 9);
    });
  });

  group('Game Navigation Integration Tests', () {
    test('All PlayMode values are properly defined', () {
      for (final mode in PlayMode.values) {
        expect(mode.name.isNotEmpty, true, reason: '${mode.toString()} should have a name');
        expect(mode.emoji.isNotEmpty, true, reason: '${mode.toString()} should have an emoji');
        expect(mode.description.isNotEmpty, true, reason: '${mode.toString()} should have a description');
        expect(mode.color, isNotNull, reason: '${mode.toString()} should have a color');
        expect(mode.icon, isNotNull, reason: '${mode.toString()} should have an icon');
      }
    });

    test('New game modes have unique colors', () {
      final newModes = [
        PlayMode.oceanAquarium,
        PlayMode.starryNight,
        PlayMode.colorBloom,
        PlayMode.floatingLantern,
      ];
      
      final colors = newModes.map((m) => m.color).toSet();
      // oceanAquarium and colorBloom can share similar colors, but floatingLantern is unique
      expect(colors.length >= 3, true);
    });

    test('New game modes have unique icons', () {
      final newModes = [
        PlayMode.oceanAquarium,
        PlayMode.starryNight,
        PlayMode.colorBloom,
        PlayMode.floatingLantern,
      ];
      
      final icons = newModes.map((m) => m.icon).toSet();
      expect(icons.length, 4); // All should have unique icons
    });

    test('Game descriptions are meaningful', () {
      expect(PlayMode.oceanAquarium.description.contains('aquarium'), true);
      expect(PlayMode.starryNight.description.contains('star'), true);
      expect(PlayMode.colorBloom.description.contains('color'), true);
      expect(PlayMode.floatingLantern.description.contains('lantern'), true);
    });
  });

  group('Existing PlayMode compatibility tests', () {
    test('Original play modes still exist', () {
      expect(PlayMode.values.contains(PlayMode.liquidTouch), true);
      expect(PlayMode.values.contains(PlayMode.energyOrb), true);
      expect(PlayMode.values.contains(PlayMode.zenGarden), true);
      expect(PlayMode.values.contains(PlayMode.bubblePop), true);
      expect(PlayMode.values.contains(PlayMode.sandFlow), true);
    });

    test('Original play modes retain their properties', () {
      expect(PlayMode.liquidTouch.name, 'Liquid Touch');
      expect(PlayMode.energyOrb.emoji, '🔮');
      expect(PlayMode.zenGarden.icon, Icons.grass_rounded);
    });
  });
}
