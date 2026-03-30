import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/breathing_exercise.dart';
import '../../theme/mood_theme.dart';

/// Breathing exercise card matching Behance design
/// Shows exercise name, pattern, duration, and fluffy image
class BreathingExerciseCard extends StatelessWidget {
  final BreathingExercise exercise;
  final VoidCallback onTap;
  final bool isCompact;

  const BreathingExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    this.isCompact = false,
  });

  Color get _backgroundColor {
    switch (exercise.colorScheme) {
      case BreathingExerciseColor.purple:
        return MoodTheme.purple50;
      case BreathingExerciseColor.beige:
        return MoodTheme.beige50;
      case BreathingExerciseColor.lavender:
        return MoodTheme.purple100;
      case BreathingExerciseColor.cream:
        return const Color(0xFFFFFBF5);
    }
  }

  Color get _accentColor {
    switch (exercise.colorScheme) {
      case BreathingExerciseColor.purple:
        return MoodTheme.purple500;
      case BreathingExerciseColor.beige:
        return MoodTheme.beige500;
      case BreathingExerciseColor.lavender:
        return MoodTheme.purple400;
      case BreathingExerciseColor.cream:
        return MoodTheme.beige400;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard();
    }
    return _buildFullCard();
  }

  Widget _buildFullCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: MoodTheme.spacingMd),
        padding: const EdgeInsets.all(MoodTheme.spacingMd),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: MoodTheme.borderRadiusLg,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Row(
          children: [
            // Left side - info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: MoodTheme.titleLg.copyWith(
                      color: MoodTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.air_rounded,
                    exercise.patternLabel,
                  ),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    Icons.schedule_rounded,
                    exercise.durationLabel,
                  ),
                ],
              ),
            ),

            // Right side - image and button
            Column(
              children: [
                // Fluffy ball placeholder
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: MoodTheme.borderRadiusMd,
                    gradient: RadialGradient(
                      colors: [
                        _accentColor.withOpacity(0.3),
                        _accentColor.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _accentColor.withOpacity(0.6),
                            _accentColor.withOpacity(0.3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Start button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: MoodTheme.borderRadiusRound,
                  ),
                  child: Text(
                    'Start',
                    style: MoodTheme.titleSm.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(MoodTheme.spacingSm),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: MoodTheme.borderRadiusMd,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            _buildInfoRow(
              Icons.air_rounded,
              exercise.patternLabel,
              small: true,
            ),
            const SizedBox(height: 2),
            _buildInfoRow(
              Icons.schedule_rounded,
              exercise.durationLabel,
              small: true,
            ),
            const SizedBox(height: 8),
            
            // Fluffy ball and name
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: MoodTheme.borderRadiusSm,
                          gradient: RadialGradient(
                            colors: [
                              _accentColor.withOpacity(0.4),
                              _accentColor.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  _accentColor.withOpacity(0.7),
                                  _accentColor.withOpacity(0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exercise.name,
                        style: MoodTheme.titleSm.copyWith(
                          color: MoodTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: MoodTheme.borderRadiusRound,
                  ),
                  child: Text(
                    'Start',
                    style: MoodTheme.bodySm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool small = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: small ? 12 : 14,
          color: MoodTheme.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: (small ? MoodTheme.caption : MoodTheme.bodySm).copyWith(
            color: MoodTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Daily breath card for home screen (matching design)
class DailyBreathCard extends StatelessWidget {
  final VoidCallback onTap;

  const DailyBreathCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(MoodTheme.spacingMd),
        decoration: BoxDecoration(
          color: MoodTheme.beige50,
          borderRadius: MoodTheme.borderRadiusLg,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Row(
          children: [
            // Info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.air_rounded,
                        size: 14,
                        color: MoodTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '2-to-1 breathing',
                        style: MoodTheme.caption.copyWith(
                          color: MoodTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: MoodTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '1 minute',
                        style: MoodTheme.caption.copyWith(
                          color: MoodTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Daily Breath',
                    style: MoodTheme.titleMd.copyWith(
                      color: MoodTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: MoodTheme.beige400,
                      borderRadius: MoodTheme.borderRadiusRound,
                    ),
                    child: Text(
                      'Start',
                      style: MoodTheme.titleSm.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Fluffy ball visual
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: MoodTheme.borderRadiusMd,
                gradient: RadialGradient(
                  colors: [
                    MoodTheme.beige200.withOpacity(0.5),
                    MoodTheme.beige100.withOpacity(0.2),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.3),
                      colors: [
                        MoodTheme.beige100,
                        MoodTheme.beige300,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MoodTheme.beige400.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact daily breath card for responsive layouts
class DailyBreathCardCompact extends StatelessWidget {
  final VoidCallback onTap;

  const DailyBreathCardCompact({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(MoodTheme.spacingSm),
        decoration: BoxDecoration(
          color: MoodTheme.beige50,
          borderRadius: MoodTheme.borderRadiusMd,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Row(
          children: [
            // Info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.air_rounded,
                        size: 12,
                        color: MoodTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '2-1 breathing',
                          style: MoodTheme.caption.copyWith(
                            color: MoodTheme.textSecondary,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: MoodTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '1 minute',
                        style: MoodTheme.caption.copyWith(
                          color: MoodTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Daily Breath',
                    style: MoodTheme.titleSm.copyWith(
                      color: MoodTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MoodTheme.beige400,
                      borderRadius: MoodTheme.borderRadiusRound,
                    ),
                    child: Text(
                      'Start',
                      style: MoodTheme.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Fluffy ball visual - smaller
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: MoodTheme.borderRadiusSm,
                gradient: RadialGradient(
                  colors: [
                    MoodTheme.beige200.withOpacity(0.5),
                    MoodTheme.beige100.withOpacity(0.2),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.3),
                      colors: [
                        MoodTheme.beige100,
                        MoodTheme.beige300,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MoodTheme.beige400.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
