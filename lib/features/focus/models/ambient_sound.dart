import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum AmbientSoundType {
  none,
  rain,
  thunderstorm,
  ocean,
  forest,
  fireplace,
  wind,
  birds,
  river,
  whiteNoise,
  brownNoise,
  pinkNoise,
  cafe,
  library,
  nightSounds,
  meditation,
}

extension AmbientSoundExtension on AmbientSoundType {
  String get name {
    switch (this) {
      case AmbientSoundType.none:
        return 'No Sound';
      case AmbientSoundType.rain:
        return 'Rain';
      case AmbientSoundType.thunderstorm:
        return 'Thunderstorm';
      case AmbientSoundType.ocean:
        return 'Ocean Waves';
      case AmbientSoundType.forest:
        return 'Forest';
      case AmbientSoundType.fireplace:
        return 'Fireplace';
      case AmbientSoundType.wind:
        return 'Wind';
      case AmbientSoundType.birds:
        return 'Birds';
      case AmbientSoundType.river:
        return 'River Stream';
      case AmbientSoundType.whiteNoise:
        return 'White Noise';
      case AmbientSoundType.brownNoise:
        return 'Brown Noise';
      case AmbientSoundType.pinkNoise:
        return 'Pink Noise';
      case AmbientSoundType.cafe:
        return 'Café Ambience';
      case AmbientSoundType.library:
        return 'Library';
      case AmbientSoundType.nightSounds:
        return 'Night Sounds';
      case AmbientSoundType.meditation:
        return 'Meditation Bells';
    }
  }

  String get emoji {
    switch (this) {
      case AmbientSoundType.none:
        return '🔇';
      case AmbientSoundType.rain:
        return '🌧️';
      case AmbientSoundType.thunderstorm:
        return '⛈️';
      case AmbientSoundType.ocean:
        return '🌊';
      case AmbientSoundType.forest:
        return '🌲';
      case AmbientSoundType.fireplace:
        return '🔥';
      case AmbientSoundType.wind:
        return '💨';
      case AmbientSoundType.birds:
        return '🐦';
      case AmbientSoundType.river:
        return '🏞️';
      case AmbientSoundType.whiteNoise:
        return '📻';
      case AmbientSoundType.brownNoise:
        return '🟤';
      case AmbientSoundType.pinkNoise:
        return '🩷';
      case AmbientSoundType.cafe:
        return '☕';
      case AmbientSoundType.library:
        return '📚';
      case AmbientSoundType.nightSounds:
        return '🌙';
      case AmbientSoundType.meditation:
        return '🔔';
    }
  }

  IconData get icon {
    switch (this) {
      case AmbientSoundType.none:
        return Symbols.volume_off_rounded;
      case AmbientSoundType.rain:
        return Symbols.water_drop_rounded;
      case AmbientSoundType.thunderstorm:
        return Symbols.thunderstorm_rounded;
      case AmbientSoundType.ocean:
        return Symbols.waves_rounded;
      case AmbientSoundType.forest:
        return Symbols.forest_rounded;
      case AmbientSoundType.fireplace:
        return Symbols.local_fire_department_rounded;
      case AmbientSoundType.wind:
        return Symbols.air_rounded;
      case AmbientSoundType.birds:
        return Symbols.flutter_dash_rounded;
      case AmbientSoundType.river:
        return Symbols.water_rounded;
      case AmbientSoundType.whiteNoise:
        return Symbols.graphic_eq_rounded;
      case AmbientSoundType.brownNoise:
        return Symbols.graphic_eq_rounded;
      case AmbientSoundType.pinkNoise:
        return Symbols.graphic_eq_rounded;
      case AmbientSoundType.cafe:
        return Symbols.coffee_rounded;
      case AmbientSoundType.library:
        return Symbols.menu_book_rounded;
      case AmbientSoundType.nightSounds:
        return Symbols.nightlight_rounded;
      case AmbientSoundType.meditation:
        return Symbols.self_improvement_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AmbientSoundType.none:
        return Colors.grey;
      case AmbientSoundType.rain:
        return const Color(0xFF5C9CE5);
      case AmbientSoundType.thunderstorm:
        return const Color(0xFF6B7280);
      case AmbientSoundType.ocean:
        return const Color(0xFF0EA5E9);
      case AmbientSoundType.forest:
        return const Color(0xFF22C55E);
      case AmbientSoundType.fireplace:
        return const Color(0xFFF97316);
      case AmbientSoundType.wind:
        return const Color(0xFF94A3B8);
      case AmbientSoundType.birds:
        return const Color(0xFF84CC16);
      case AmbientSoundType.river:
        return const Color(0xFF06B6D4);
      case AmbientSoundType.whiteNoise:
        return const Color(0xFFE5E7EB);
      case AmbientSoundType.brownNoise:
        return const Color(0xFF92400E);
      case AmbientSoundType.pinkNoise:
        return const Color(0xFFF472B6);
      case AmbientSoundType.cafe:
        return const Color(0xFFB45309);
      case AmbientSoundType.library:
        return const Color(0xFF7C3AED);
      case AmbientSoundType.nightSounds:
        return const Color(0xFF1E3A5F);
      case AmbientSoundType.meditation:
        return const Color(0xFF8B5CF6);
    }
  }

  String get category {
    switch (this) {
      case AmbientSoundType.none:
        return 'General';
      case AmbientSoundType.rain:
      case AmbientSoundType.thunderstorm:
      case AmbientSoundType.ocean:
      case AmbientSoundType.wind:
        return 'Weather';
      case AmbientSoundType.forest:
      case AmbientSoundType.birds:
      case AmbientSoundType.river:
      case AmbientSoundType.nightSounds:
        return 'Nature';
      case AmbientSoundType.whiteNoise:
      case AmbientSoundType.brownNoise:
      case AmbientSoundType.pinkNoise:
        return 'Noise';
      case AmbientSoundType.cafe:
      case AmbientSoundType.library:
      case AmbientSoundType.fireplace:
        return 'Environment';
      case AmbientSoundType.meditation:
        return 'Meditation';
    }
  }
}

class AmbientSound {
  final AmbientSoundType type;
  final double volume;
  final bool isPlaying;

  const AmbientSound({
    required this.type,
    this.volume = 0.5,
    this.isPlaying = false,
  });

  AmbientSound copyWith({
    AmbientSoundType? type,
    double? volume,
    bool? isPlaying,
  }) {
    return AmbientSound(
      type: type ?? this.type,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
