import 'package:flutter/material.dart';

enum BreathingPattern {
  relaxing,        // 4-7-8 pattern
  balancing,       // 4-4-4-4 box breathing
  energizing,      // 4-4 fast breathing
  calming,         // 4-8 extended exhale
  deepBreathing,   // 5-5 deep breaths
  sleepBreathing,  // 4-7-8 for sleep
}

extension BreathingPatternExtension on BreathingPattern {
  String get name {
    switch (this) {
      case BreathingPattern.relaxing:
        return 'Relaxing (4-7-8)';
      case BreathingPattern.balancing:
        return 'Box Breathing (4-4-4-4)';
      case BreathingPattern.energizing:
        return 'Energizing (4-4)';
      case BreathingPattern.calming:
        return 'Calming (4-8)';
      case BreathingPattern.deepBreathing:
        return 'Deep Breathing (5-5)';
      case BreathingPattern.sleepBreathing:
        return 'Sleep (4-7-8)';
    }
  }

  String get description {
    switch (this) {
      case BreathingPattern.relaxing:
        return 'A calming technique to reduce anxiety and promote relaxation.';
      case BreathingPattern.balancing:
        return 'Navy SEAL technique for stress relief and focus.';
      case BreathingPattern.energizing:
        return 'Quick breathing to boost energy and alertness.';
      case BreathingPattern.calming:
        return 'Extended exhale to activate the parasympathetic nervous system.';
      case BreathingPattern.deepBreathing:
        return 'Simple deep breaths for overall relaxation.';
      case BreathingPattern.sleepBreathing:
        return 'Perfect for falling asleep naturally.';
    }
  }

  IconData get icon {
    switch (this) {
      case BreathingPattern.relaxing:
        return Icons.spa_rounded;
      case BreathingPattern.balancing:
        return Icons.crop_square_rounded;
      case BreathingPattern.energizing:
        return Icons.bolt_rounded;
      case BreathingPattern.calming:
        return Icons.nights_stay_rounded;
      case BreathingPattern.deepBreathing:
        return Icons.air_rounded;
      case BreathingPattern.sleepBreathing:
        return Icons.bedtime_rounded;
    }
  }

  Color get color {
    switch (this) {
      case BreathingPattern.relaxing:
        return const Color(0xFF22C55E);
      case BreathingPattern.balancing:
        return const Color(0xFF3B82F6);
      case BreathingPattern.energizing:
        return const Color(0xFFF59E0B);
      case BreathingPattern.calming:
        return const Color(0xFF8B5CF6);
      case BreathingPattern.deepBreathing:
        return const Color(0xFF06B6D4);
      case BreathingPattern.sleepBreathing:
        return const Color(0xFF1E3A5F);
    }
  }

  int get inhaleSeconds {
    switch (this) {
      case BreathingPattern.relaxing:
        return 4;
      case BreathingPattern.balancing:
        return 4;
      case BreathingPattern.energizing:
        return 4;
      case BreathingPattern.calming:
        return 4;
      case BreathingPattern.deepBreathing:
        return 5;
      case BreathingPattern.sleepBreathing:
        return 4;
    }
  }

  int get holdAfterInhaleSeconds {
    switch (this) {
      case BreathingPattern.relaxing:
        return 7;
      case BreathingPattern.balancing:
        return 4;
      case BreathingPattern.energizing:
        return 0;
      case BreathingPattern.calming:
        return 0;
      case BreathingPattern.deepBreathing:
        return 0;
      case BreathingPattern.sleepBreathing:
        return 7;
    }
  }

  int get exhaleSeconds {
    switch (this) {
      case BreathingPattern.relaxing:
        return 8;
      case BreathingPattern.balancing:
        return 4;
      case BreathingPattern.energizing:
        return 4;
      case BreathingPattern.calming:
        return 8;
      case BreathingPattern.deepBreathing:
        return 5;
      case BreathingPattern.sleepBreathing:
        return 8;
    }
  }

  int get holdAfterExhaleSeconds {
    switch (this) {
      case BreathingPattern.relaxing:
        return 0;
      case BreathingPattern.balancing:
        return 4;
      case BreathingPattern.energizing:
        return 0;
      case BreathingPattern.calming:
        return 0;
      case BreathingPattern.deepBreathing:
        return 0;
      case BreathingPattern.sleepBreathing:
        return 0;
    }
  }

  int get totalCycleDuration {
    return inhaleSeconds + holdAfterInhaleSeconds + exhaleSeconds + holdAfterExhaleSeconds;
  }

  int get recommendedCycles {
    switch (this) {
      case BreathingPattern.relaxing:
        return 4;
      case BreathingPattern.balancing:
        return 4;
      case BreathingPattern.energizing:
        return 8;
      case BreathingPattern.calming:
        return 6;
      case BreathingPattern.deepBreathing:
        return 5;
      case BreathingPattern.sleepBreathing:
        return 3;
    }
  }
}

enum BreathingPhase {
  inhale,
  holdAfterInhale,
  exhale,
  holdAfterExhale,
}

extension BreathingPhaseExtension on BreathingPhase {
  String get instruction {
    switch (this) {
      case BreathingPhase.inhale:
        return 'Breathe In';
      case BreathingPhase.holdAfterInhale:
        return 'Hold';
      case BreathingPhase.exhale:
        return 'Breathe Out';
      case BreathingPhase.holdAfterExhale:
        return 'Hold';
    }
  }

  Color get color {
    switch (this) {
      case BreathingPhase.inhale:
        return const Color(0xFF22C55E);
      case BreathingPhase.holdAfterInhale:
        return const Color(0xFF3B82F6);
      case BreathingPhase.exhale:
        return const Color(0xFF8B5CF6);
      case BreathingPhase.holdAfterExhale:
        return const Color(0xFF6B7280);
    }
  }
}

class BreathingSession {
  final BreathingPattern pattern;
  final int completedCycles;
  final int targetCycles;
  final DateTime startedAt;
  final bool isActive;

  const BreathingSession({
    required this.pattern,
    this.completedCycles = 0,
    required this.targetCycles,
    required this.startedAt,
    this.isActive = true,
  });

  BreathingSession copyWith({
    BreathingPattern? pattern,
    int? completedCycles,
    int? targetCycles,
    DateTime? startedAt,
    bool? isActive,
  }) {
    return BreathingSession(
      pattern: pattern ?? this.pattern,
      completedCycles: completedCycles ?? this.completedCycles,
      targetCycles: targetCycles ?? this.targetCycles,
      startedAt: startedAt ?? this.startedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
