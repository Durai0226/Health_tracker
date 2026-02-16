import 'package:flutter/material.dart';

/// Premium Theme Palettes for Relaxation Game
enum RelaxationTheme {
  darkLuxury,
  goldAccent,
  obsidian,
  pearlMinimal,
  amoledBlack,
  cosmicNight,
  zenGarden,
  oceanDepth,
}

extension RelaxationThemeExtension on RelaxationTheme {
  String get name {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return 'Dark Luxury';
      case RelaxationTheme.goldAccent:
        return 'Gold Accent';
      case RelaxationTheme.obsidian:
        return 'Obsidian';
      case RelaxationTheme.pearlMinimal:
        return 'Pearl Minimal';
      case RelaxationTheme.amoledBlack:
        return 'AMOLED Black';
      case RelaxationTheme.cosmicNight:
        return 'Cosmic Night';
      case RelaxationTheme.zenGarden:
        return 'Zen Garden';
      case RelaxationTheme.oceanDepth:
        return 'Ocean Depth';
    }
  }

  String get emoji {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return '🌙';
      case RelaxationTheme.goldAccent:
        return '✨';
      case RelaxationTheme.obsidian:
        return '🖤';
      case RelaxationTheme.pearlMinimal:
        return '🤍';
      case RelaxationTheme.amoledBlack:
        return '⬛';
      case RelaxationTheme.cosmicNight:
        return '🌌';
      case RelaxationTheme.zenGarden:
        return '🎋';
      case RelaxationTheme.oceanDepth:
        return '🌊';
    }
  }

  Color get primaryColor {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return const Color(0xFF6366F1);
      case RelaxationTheme.goldAccent:
        return const Color(0xFFD4AF37);
      case RelaxationTheme.obsidian:
        return const Color(0xFF4A4A4A);
      case RelaxationTheme.pearlMinimal:
        return const Color(0xFF8B8B8B);
      case RelaxationTheme.amoledBlack:
        return const Color(0xFF8B5CF6);
      case RelaxationTheme.cosmicNight:
        return const Color(0xFF7C3AED);
      case RelaxationTheme.zenGarden:
        return const Color(0xFF10B981);
      case RelaxationTheme.oceanDepth:
        return const Color(0xFF0EA5E9);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return const Color(0xFF8B5CF6);
      case RelaxationTheme.goldAccent:
        return const Color(0xFFFACC15);
      case RelaxationTheme.obsidian:
        return const Color(0xFF6B6B6B);
      case RelaxationTheme.pearlMinimal:
        return const Color(0xFFB8B8B8);
      case RelaxationTheme.amoledBlack:
        return const Color(0xFFA78BFA);
      case RelaxationTheme.cosmicNight:
        return const Color(0xFFA855F7);
      case RelaxationTheme.zenGarden:
        return const Color(0xFF34D399);
      case RelaxationTheme.oceanDepth:
        return const Color(0xFF38BDF8);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return const Color(0xFF0F0F1A);
      case RelaxationTheme.goldAccent:
        return const Color(0xFF1A1A2E);
      case RelaxationTheme.obsidian:
        return const Color(0xFF0A0A0A);
      case RelaxationTheme.pearlMinimal:
        return const Color(0xFFF8F8F8);
      case RelaxationTheme.amoledBlack:
        return const Color(0xFF000000);
      case RelaxationTheme.cosmicNight:
        return const Color(0xFF0D0221);
      case RelaxationTheme.zenGarden:
        return const Color(0xFF0A1612);
      case RelaxationTheme.oceanDepth:
        return const Color(0xFF0A1929);
    }
  }

  Color get surfaceColor {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return const Color(0xFF1A1A2E);
      case RelaxationTheme.goldAccent:
        return const Color(0xFF252540);
      case RelaxationTheme.obsidian:
        return const Color(0xFF151515);
      case RelaxationTheme.pearlMinimal:
        return const Color(0xFFFFFFFF);
      case RelaxationTheme.amoledBlack:
        return const Color(0xFF0A0A0A);
      case RelaxationTheme.cosmicNight:
        return const Color(0xFF1A0A30);
      case RelaxationTheme.zenGarden:
        return const Color(0xFF122620);
      case RelaxationTheme.oceanDepth:
        return const Color(0xFF0F2942);
    }
  }

  Color get accentGlow {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return const Color(0xFF6366F1).withOpacity(0.3);
      case RelaxationTheme.goldAccent:
        return const Color(0xFFD4AF37).withOpacity(0.4);
      case RelaxationTheme.obsidian:
        return const Color(0xFF6B6B6B).withOpacity(0.2);
      case RelaxationTheme.pearlMinimal:
        return const Color(0xFF8B8B8B).withOpacity(0.15);
      case RelaxationTheme.amoledBlack:
        return const Color(0xFF8B5CF6).withOpacity(0.4);
      case RelaxationTheme.cosmicNight:
        return const Color(0xFF7C3AED).withOpacity(0.5);
      case RelaxationTheme.zenGarden:
        return const Color(0xFF10B981).withOpacity(0.3);
      case RelaxationTheme.oceanDepth:
        return const Color(0xFF0EA5E9).withOpacity(0.35);
    }
  }

  Color get textColor {
    switch (this) {
      case RelaxationTheme.pearlMinimal:
        return const Color(0xFF1A1A1A);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  Color get textSecondary {
    switch (this) {
      case RelaxationTheme.pearlMinimal:
        return const Color(0xFF6B6B6B);
      default:
        return const Color(0xFFB8B8B8);
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case RelaxationTheme.darkLuxury:
        return [const Color(0xFF0F0F1A), const Color(0xFF1A1A2E), const Color(0xFF2D1B4E)];
      case RelaxationTheme.goldAccent:
        return [const Color(0xFF1A1A2E), const Color(0xFF2D2D4A), const Color(0xFF3D3D5C)];
      case RelaxationTheme.obsidian:
        return [const Color(0xFF0A0A0A), const Color(0xFF151515), const Color(0xFF202020)];
      case RelaxationTheme.pearlMinimal:
        return [const Color(0xFFF8F8F8), const Color(0xFFFFFFFF), const Color(0xFFF0F0F0)];
      case RelaxationTheme.amoledBlack:
        return [const Color(0xFF000000), const Color(0xFF050505), const Color(0xFF0A0A0A)];
      case RelaxationTheme.cosmicNight:
        return [const Color(0xFF0D0221), const Color(0xFF1A0A30), const Color(0xFF2D1654)];
      case RelaxationTheme.zenGarden:
        return [const Color(0xFF0A1612), const Color(0xFF122620), const Color(0xFF1A3830)];
      case RelaxationTheme.oceanDepth:
        return [const Color(0xFF0A1929), const Color(0xFF0F2942), const Color(0xFF1A4060)];
    }
  }
}

/// Exclusive Experience Modes
enum ExperienceMode {
  zenFlow,
  liquidRipple,
  auraSculpt,
  breathingRitual,
  cosmicDrift,
  emberMeditation,
  chromaticHarmony,
  hypnoticLoop,
}

extension ExperienceModeExtension on ExperienceMode {
  String get name {
    switch (this) {
      case ExperienceMode.zenFlow:
        return 'Zen Flow';
      case ExperienceMode.liquidRipple:
        return 'Liquid Ripple';
      case ExperienceMode.auraSculpt:
        return 'Aura Sculpt';
      case ExperienceMode.breathingRitual:
        return 'Breathing Ritual';
      case ExperienceMode.cosmicDrift:
        return 'Cosmic Drift';
      case ExperienceMode.emberMeditation:
        return 'Ember Meditation';
      case ExperienceMode.chromaticHarmony:
        return 'Chromatic Harmony';
      case ExperienceMode.hypnoticLoop:
        return 'Hypnotic Loop';
    }
  }

  String get emoji {
    switch (this) {
      case ExperienceMode.zenFlow:
        return '🌌';
      case ExperienceMode.liquidRipple:
        return '🌊';
      case ExperienceMode.auraSculpt:
        return '🔮';
      case ExperienceMode.breathingRitual:
        return '🌬️';
      case ExperienceMode.cosmicDrift:
        return '🌠';
      case ExperienceMode.emberMeditation:
        return '🔥';
      case ExperienceMode.chromaticHarmony:
        return '🌈';
      case ExperienceMode.hypnoticLoop:
        return '🌀';
    }
  }

  String get description {
    switch (this) {
      case ExperienceMode.zenFlow:
        return 'Touch generates flowing light trails with synchronized haptics';
      case ExperienceMode.liquidRipple:
        return 'Tap creates expanding ripple waves with soft pulses';
      case ExperienceMode.auraSculpt:
        return 'Shape glowing energy fields with gestures';
      case ExperienceMode.breathingRitual:
        return 'Guided breathing with haptic rhythm guidance';
      case ExperienceMode.cosmicDrift:
        return 'Particle-based calming exploration';
      case ExperienceMode.emberMeditation:
        return 'Fire-like glow that responds to finger movement';
      case ExperienceMode.chromaticHarmony:
        return 'Color-frequency-based relaxation patterns';
      case ExperienceMode.hypnoticLoop:
        return 'Looping fractal animations with micro haptic pulses';
    }
  }

  Color get primaryColor {
    switch (this) {
      case ExperienceMode.zenFlow:
        return const Color(0xFF8B5CF6);
      case ExperienceMode.liquidRipple:
        return const Color(0xFF06B6D4);
      case ExperienceMode.auraSculpt:
        return const Color(0xFFA855F7);
      case ExperienceMode.breathingRitual:
        return const Color(0xFF10B981);
      case ExperienceMode.cosmicDrift:
        return const Color(0xFF6366F1);
      case ExperienceMode.emberMeditation:
        return const Color(0xFFF97316);
      case ExperienceMode.chromaticHarmony:
        return const Color(0xFFEC4899);
      case ExperienceMode.hypnoticLoop:
        return const Color(0xFF7C3AED);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case ExperienceMode.zenFlow:
        return const Color(0xFFC4B5FD);
      case ExperienceMode.liquidRipple:
        return const Color(0xFF22D3EE);
      case ExperienceMode.auraSculpt:
        return const Color(0xFFD8B4FE);
      case ExperienceMode.breathingRitual:
        return const Color(0xFF34D399);
      case ExperienceMode.cosmicDrift:
        return const Color(0xFFA5B4FC);
      case ExperienceMode.emberMeditation:
        return const Color(0xFFFBBF24);
      case ExperienceMode.chromaticHarmony:
        return const Color(0xFFF472B6);
      case ExperienceMode.hypnoticLoop:
        return const Color(0xFFA78BFA);
    }
  }

  IconData get icon {
    switch (this) {
      case ExperienceMode.zenFlow:
        return Icons.blur_on_rounded;
      case ExperienceMode.liquidRipple:
        return Icons.water_drop_rounded;
      case ExperienceMode.auraSculpt:
        return Icons.auto_awesome_rounded;
      case ExperienceMode.breathingRitual:
        return Icons.air_rounded;
      case ExperienceMode.cosmicDrift:
        return Icons.stars_rounded;
      case ExperienceMode.emberMeditation:
        return Icons.local_fire_department_rounded;
      case ExperienceMode.chromaticHarmony:
        return Icons.palette_rounded;
      case ExperienceMode.hypnoticLoop:
        return Icons.motion_photos_on_rounded;
    }
  }

  bool get isProElite {
    switch (this) {
      case ExperienceMode.zenFlow:
      case ExperienceMode.liquidRipple:
      case ExperienceMode.breathingRitual:
        return false;
      default:
        return true;
    }
  }

  int get unlockMinutesRequired {
    switch (this) {
      case ExperienceMode.auraSculpt:
        return 60;
      case ExperienceMode.cosmicDrift:
        return 120;
      case ExperienceMode.emberMeditation:
        return 180;
      case ExperienceMode.chromaticHarmony:
        return 240;
      case ExperienceMode.hypnoticLoop:
        return 300;
      default:
        return 0;
    }
  }
}

/// Haptic Therapy Modes
enum HapticTherapyMode {
  stressRelease,
  anxietyCalm,
  sleepInduction,
  deepFocus,
  energyBoost,
}

extension HapticTherapyModeExtension on HapticTherapyMode {
  String get name {
    switch (this) {
      case HapticTherapyMode.stressRelease:
        return 'Stress Release';
      case HapticTherapyMode.anxietyCalm:
        return 'Anxiety Calm';
      case HapticTherapyMode.sleepInduction:
        return 'Sleep Induction';
      case HapticTherapyMode.deepFocus:
        return 'Deep Focus';
      case HapticTherapyMode.energyBoost:
        return 'Energy Boost';
    }
  }

  String get emoji {
    switch (this) {
      case HapticTherapyMode.stressRelease:
        return '😌';
      case HapticTherapyMode.anxietyCalm:
        return '🧘';
      case HapticTherapyMode.sleepInduction:
        return '😴';
      case HapticTherapyMode.deepFocus:
        return '🎯';
      case HapticTherapyMode.energyBoost:
        return '⚡';
    }
  }

  String get description {
    switch (this) {
      case HapticTherapyMode.stressRelease:
        return 'Deep slow wave vibrations simulating breathing rhythm';
      case HapticTherapyMode.anxietyCalm:
        return 'Grounding 5-4-3-2-1 sensory pattern with soft pulses';
      case HapticTherapyMode.sleepInduction:
        return 'Fading waves with weighted blanket simulation';
      case HapticTherapyMode.deepFocus:
        return 'Rhythmic pulses for concentration enhancement';
      case HapticTherapyMode.energyBoost:
        return 'Invigorating patterns to increase alertness';
    }
  }

  Color get color {
    switch (this) {
      case HapticTherapyMode.stressRelease:
        return const Color(0xFF10B981);
      case HapticTherapyMode.anxietyCalm:
        return const Color(0xFF8B5CF6);
      case HapticTherapyMode.sleepInduction:
        return const Color(0xFF6366F1);
      case HapticTherapyMode.deepFocus:
        return const Color(0xFFF59E0B);
      case HapticTherapyMode.energyBoost:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case HapticTherapyMode.stressRelease:
        return Icons.spa_rounded;
      case HapticTherapyMode.anxietyCalm:
        return Icons.self_improvement_rounded;
      case HapticTherapyMode.sleepInduction:
        return Icons.bedtime_rounded;
      case HapticTherapyMode.deepFocus:
        return Icons.center_focus_strong_rounded;
      case HapticTherapyMode.energyBoost:
        return Icons.bolt_rounded;
    }
  }
}

/// Interactive Play Modes
enum PlayMode {
  liquidTouch,
  energyOrb,
  zenGarden,
  bubblePop,
  sandFlow,
}

extension PlayModeExtension on PlayMode {
  String get name {
    switch (this) {
      case PlayMode.liquidTouch:
        return 'Liquid Touch';
      case PlayMode.energyOrb:
        return 'Energy Orb';
      case PlayMode.zenGarden:
        return 'Zen Garden';
      case PlayMode.bubblePop:
        return 'Bubble Pop';
      case PlayMode.sandFlow:
        return 'Sand Flow';
    }
  }

  String get emoji {
    switch (this) {
      case PlayMode.liquidTouch:
        return '💧';
      case PlayMode.energyOrb:
        return '🔮';
      case PlayMode.zenGarden:
        return '🪨';
      case PlayMode.bubblePop:
        return '🫧';
      case PlayMode.sandFlow:
        return '⏳';
    }
  }

  String get description {
    switch (this) {
      case PlayMode.liquidTouch:
        return 'Screen reacts like fluid with ripple vibrations';
      case PlayMode.energyOrb:
        return 'Move glowing orb that emits calming pulse waves';
      case PlayMode.zenGarden:
        return 'Rake sand with textured vibration feedback';
      case PlayMode.bubblePop:
        return 'Pop satisfying bubbles with premium haptics';
      case PlayMode.sandFlow:
        return 'Watch sand flow with gentle haptic accompaniment';
    }
  }

  Color get color {
    switch (this) {
      case PlayMode.liquidTouch:
        return const Color(0xFF06B6D4);
      case PlayMode.energyOrb:
        return const Color(0xFFA855F7);
      case PlayMode.zenGarden:
        return const Color(0xFF84CC16);
      case PlayMode.bubblePop:
        return const Color(0xFFEC4899);
      case PlayMode.sandFlow:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get icon {
    switch (this) {
      case PlayMode.liquidTouch:
        return Icons.water_rounded;
      case PlayMode.energyOrb:
        return Icons.blur_circular_rounded;
      case PlayMode.zenGarden:
        return Icons.grass_rounded;
      case PlayMode.bubblePop:
        return Icons.bubble_chart_rounded;
      case PlayMode.sandFlow:
        return Icons.hourglass_bottom_rounded;
    }
  }
}

/// Element types for Energy Orb mode
enum OrbElement {
  water,
  sand,
  silk,
  stone,
  fire,
  crystal,
}

extension OrbElementExtension on OrbElement {
  String get name {
    switch (this) {
      case OrbElement.water:
        return 'Water';
      case OrbElement.sand:
        return 'Sand';
      case OrbElement.silk:
        return 'Silk';
      case OrbElement.stone:
        return 'Stone';
      case OrbElement.fire:
        return 'Fire';
      case OrbElement.crystal:
        return 'Crystal';
    }
  }

  String get emoji {
    switch (this) {
      case OrbElement.water:
        return '💧';
      case OrbElement.sand:
        return '🏜️';
      case OrbElement.silk:
        return '🎀';
      case OrbElement.stone:
        return '🪨';
      case OrbElement.fire:
        return '🔥';
      case OrbElement.crystal:
        return '💎';
    }
  }

  Color get color {
    switch (this) {
      case OrbElement.water:
        return const Color(0xFF06B6D4);
      case OrbElement.sand:
        return const Color(0xFFF59E0B);
      case OrbElement.silk:
        return const Color(0xFFF472B6);
      case OrbElement.stone:
        return const Color(0xFF6B7280);
      case OrbElement.fire:
        return const Color(0xFFF97316);
      case OrbElement.crystal:
        return const Color(0xFF8B5CF6);
    }
  }
}

/// Sound presets for ambient backgrounds
enum AmbientSoundPreset {
  none,
  whiteNoise,
  pinkNoise,
  brownNoise,
  rain,
  ocean,
  forest,
  fireplace,
  wind,
  thunderstorm,
  crystalBowls,
}

extension AmbientSoundPresetExtension on AmbientSoundPreset {
  String get name {
    switch (this) {
      case AmbientSoundPreset.none:
        return 'None';
      case AmbientSoundPreset.whiteNoise:
        return 'White Noise';
      case AmbientSoundPreset.pinkNoise:
        return 'Pink Noise';
      case AmbientSoundPreset.brownNoise:
        return 'Brown Noise';
      case AmbientSoundPreset.rain:
        return 'Rain';
      case AmbientSoundPreset.ocean:
        return 'Ocean';
      case AmbientSoundPreset.forest:
        return 'Forest';
      case AmbientSoundPreset.fireplace:
        return 'Fireplace';
      case AmbientSoundPreset.wind:
        return 'Wind';
      case AmbientSoundPreset.thunderstorm:
        return 'Thunderstorm';
      case AmbientSoundPreset.crystalBowls:
        return 'Crystal Bowls';
    }
  }

  String get emoji {
    switch (this) {
      case AmbientSoundPreset.none:
        return '🔇';
      case AmbientSoundPreset.whiteNoise:
        return '📻';
      case AmbientSoundPreset.pinkNoise:
        return '🎵';
      case AmbientSoundPreset.brownNoise:
        return '🎶';
      case AmbientSoundPreset.rain:
        return '🌧️';
      case AmbientSoundPreset.ocean:
        return '🌊';
      case AmbientSoundPreset.forest:
        return '🌲';
      case AmbientSoundPreset.fireplace:
        return '🔥';
      case AmbientSoundPreset.wind:
        return '🌬️';
      case AmbientSoundPreset.thunderstorm:
        return '⛈️';
      case AmbientSoundPreset.crystalBowls:
        return '🔔';
    }
  }
}

/// Relaxation Game Settings
class RelaxationGameSettings {
  final RelaxationTheme theme;
  final double hapticIntensity;
  final double hapticSpeed;
  final bool hapticEnabled;
  final double soundVolume;
  final AmbientSoundPreset ambientSound;
  final bool soundHapticSync;
  final double particleDensity;
  final double animationSpeed;
  final double glowIntensity;
  final double blurIntensity;
  final double motionSensitivity;
  final bool proEliteUnlocked;
  final int totalMinutesUsed;
  final int currentStreak;
  final Set<ExperienceMode> unlockedModes;
  final Set<ExperienceMode> masteredModes;

  const RelaxationGameSettings({
    this.theme = RelaxationTheme.cosmicNight,
    this.hapticIntensity = 0.7,
    this.hapticSpeed = 0.5,
    this.hapticEnabled = true,
    this.soundVolume = 0.5,
    this.ambientSound = AmbientSoundPreset.none,
    this.soundHapticSync = true,
    this.particleDensity = 0.6,
    this.animationSpeed = 0.5,
    this.glowIntensity = 0.7,
    this.blurIntensity = 0.5,
    this.motionSensitivity = 0.5,
    this.proEliteUnlocked = false,
    this.totalMinutesUsed = 0,
    this.currentStreak = 0,
    this.unlockedModes = const {},
    this.masteredModes = const {},
  });

  RelaxationGameSettings copyWith({
    RelaxationTheme? theme,
    double? hapticIntensity,
    double? hapticSpeed,
    bool? hapticEnabled,
    double? soundVolume,
    AmbientSoundPreset? ambientSound,
    bool? soundHapticSync,
    double? particleDensity,
    double? animationSpeed,
    double? glowIntensity,
    double? blurIntensity,
    double? motionSensitivity,
    bool? proEliteUnlocked,
    int? totalMinutesUsed,
    int? currentStreak,
    Set<ExperienceMode>? unlockedModes,
    Set<ExperienceMode>? masteredModes,
  }) {
    return RelaxationGameSettings(
      theme: theme ?? this.theme,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      hapticSpeed: hapticSpeed ?? this.hapticSpeed,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      ambientSound: ambientSound ?? this.ambientSound,
      soundHapticSync: soundHapticSync ?? this.soundHapticSync,
      particleDensity: particleDensity ?? this.particleDensity,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      motionSensitivity: motionSensitivity ?? this.motionSensitivity,
      proEliteUnlocked: proEliteUnlocked ?? this.proEliteUnlocked,
      totalMinutesUsed: totalMinutesUsed ?? this.totalMinutesUsed,
      currentStreak: currentStreak ?? this.currentStreak,
      unlockedModes: unlockedModes ?? this.unlockedModes,
      masteredModes: masteredModes ?? this.masteredModes,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme.index,
    'hapticIntensity': hapticIntensity,
    'hapticSpeed': hapticSpeed,
    'hapticEnabled': hapticEnabled,
    'soundVolume': soundVolume,
    'ambientSound': ambientSound.index,
    'soundHapticSync': soundHapticSync,
    'particleDensity': particleDensity,
    'animationSpeed': animationSpeed,
    'glowIntensity': glowIntensity,
    'blurIntensity': blurIntensity,
    'motionSensitivity': motionSensitivity,
    'proEliteUnlocked': proEliteUnlocked,
    'totalMinutesUsed': totalMinutesUsed,
    'currentStreak': currentStreak,
    'unlockedModes': unlockedModes.map((e) => e.index).toList(),
    'masteredModes': masteredModes.map((e) => e.index).toList(),
  };

  factory RelaxationGameSettings.fromJson(Map<String, dynamic> json) {
    return RelaxationGameSettings(
      theme: RelaxationTheme.values[json['theme'] ?? 5],
      hapticIntensity: (json['hapticIntensity'] ?? 0.7).toDouble(),
      hapticSpeed: (json['hapticSpeed'] ?? 0.5).toDouble(),
      hapticEnabled: json['hapticEnabled'] ?? true,
      soundVolume: (json['soundVolume'] ?? 0.5).toDouble(),
      ambientSound: AmbientSoundPreset.values[json['ambientSound'] ?? 0],
      soundHapticSync: json['soundHapticSync'] ?? true,
      particleDensity: (json['particleDensity'] ?? 0.6).toDouble(),
      animationSpeed: (json['animationSpeed'] ?? 0.5).toDouble(),
      glowIntensity: (json['glowIntensity'] ?? 0.7).toDouble(),
      blurIntensity: (json['blurIntensity'] ?? 0.5).toDouble(),
      motionSensitivity: (json['motionSensitivity'] ?? 0.5).toDouble(),
      proEliteUnlocked: json['proEliteUnlocked'] ?? false,
      totalMinutesUsed: json['totalMinutesUsed'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      unlockedModes: (json['unlockedModes'] as List?)
          ?.map((e) => ExperienceMode.values[e])
          .toSet() ?? {},
      masteredModes: (json['masteredModes'] as List?)
          ?.map((e) => ExperienceMode.values[e])
          .toSet() ?? {},
    );
  }
}

/// Touch point for tracking interactions
class TouchPoint {
  final Offset position;
  final DateTime timestamp;
  final double pressure;
  final double size;

  const TouchPoint({
    required this.position,
    required this.timestamp,
    this.pressure = 1.0,
    this.size = 1.0,
  });
}

/// Ripple effect data
class RippleEffect {
  final Offset center;
  final DateTime startTime;
  final Color color;
  final double maxRadius;
  final Duration duration;

  RippleEffect({
    required this.center,
    required this.startTime,
    required this.color,
    this.maxRadius = 150.0,
    this.duration = const Duration(milliseconds: 800),
  });

  double get progress {
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    return (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get isComplete => progress >= 1.0;
}

/// Particle data for visual effects
class Particle {
  Offset position;
  Offset velocity;
  double size;
  double opacity;
  Color color;
  double life;
  double maxLife;

  Particle({
    required this.position,
    required this.velocity,
    this.size = 4.0,
    this.opacity = 1.0,
    required this.color,
    this.life = 1.0,
    this.maxLife = 1.0,
  });

  void update(double dt) {
    position += velocity * dt;
    life -= dt / maxLife;
    opacity = life.clamp(0.0, 1.0);
  }

  bool get isDead => life <= 0;
}

/// Light trail data
class LightTrail {
  final List<TouchPoint> points;
  final Color color;
  final double width;
  final DateTime startTime;

  LightTrail({
    required this.points,
    required this.color,
    this.width = 8.0,
    required this.startTime,
  });

  double get age => DateTime.now().difference(startTime).inMilliseconds / 1000.0;
}
