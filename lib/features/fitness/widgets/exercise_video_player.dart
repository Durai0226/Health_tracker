import 'package:flutter/material.dart';
import '../theme/fitness_theme.dart';
import 'exercise_gif_player.dart';

/// Exercise demonstration player
/// Uses GIF animations for exercise demos (YouTube support removed)
class ExerciseVideoPlayer extends StatelessWidget {
  final String? gifUrl;
  final double? width;
  final double? height;
  final bool autoPlay;
  final Color? backgroundColor;
  final bool showControls;

  const ExerciseVideoPlayer({
    super.key,
    this.gifUrl,
    this.width,
    this.height,
    this.autoPlay = false,
    this.backgroundColor,
    this.showControls = true,
  });

  bool get hasValidSource => gifUrl != null && gifUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (hasValidSource) {
      return ExerciseGifPlayer(
        gifUrl: gifUrl,
        width: width,
        height: height,
        backgroundColor: backgroundColor ?? FitnessTheme.surface,
        borderRadius: FitnessTheme.borderRadiusMd,
        showControls: showControls,
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FitnessTheme.surface,
            FitnessTheme.surface.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: FitnessTheme.borderRadiusMd,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FitnessTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center,
              size: 48,
              color: FitnessTheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          Text(
            'Exercise Demo',
            style: FitnessTheme.titleSm.copyWith(
              color: FitnessTheme.textSecondary,
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingXs),
          Text(
            'Follow the instructions below',
            style: FitnessTheme.caption.copyWith(
              color: FitnessTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
