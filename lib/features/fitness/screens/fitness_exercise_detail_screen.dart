import 'package:flutter/material.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/exercise_video_player.dart';
import '../models/exercise.dart';

class FitnessExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const FitnessExerciseDetailScreen({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final bodyPartColor = FitnessTheme.getBodyPartColor(exercise.primaryBodyPart.displayName);
    final difficultyColor = FitnessTheme.getDifficultyColor(exercise.difficulty.displayName);

    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: FitnessTheme.background,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FitnessTheme.surface.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(exercise.name, style: FitnessTheme.headingMd),
                centerTitle: true,
              ),
              // Video Player Section
              SliverToBoxAdapter(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ExerciseVideoPlayer(
                    gifUrl: exercise.gifUrl,
                    autoPlay: false,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header
                    Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exercise.name, style: FitnessTheme.headingMd),
                            const SizedBox(height: FitnessTheme.spacingXs),
                            Text(exercise.description, style: FitnessTheme.bodySm),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitnessTheme.spacingMd),
                  
                  // Tags
                  Wrap(
                    spacing: FitnessTheme.spacingSm,
                    runSpacing: FitnessTheme.spacingSm,
                    children: [
                      _buildTag(
                        exercise.primaryBodyPart.displayName,
                        bodyPartColor,
                      ),
                      _buildTag(
                        exercise.difficulty.displayName,
                        difficultyColor,
                      ),
                      _buildTag(
                        exercise.type == ExerciseType.timed ? 'Timed' : 'Reps',
                        FitnessTheme.info,
                      ),
                      if (exercise.requiresEquipment)
                        _buildTag('Equipment', FitnessTheme.warning),
                    ],
                  ),
                  const SizedBox(height: FitnessTheme.spacingLg),
                  
                  // Info card
                  FitnessCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(
                          Icons.timer_outlined,
                          exercise.displayDuration,
                          'Duration',
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          Icons.local_fire_department,
                          '~${exercise.caloriesPerMinute}',
                          'Cal/min',
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          Icons.fitness_center,
                          exercise.primaryBodyPart.displayName,
                          'Target',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FitnessTheme.spacingLg),
                  
                  // Instructions
                  if (exercise.instructions.isNotEmpty) ...[
                    Text('Instructions', style: FitnessTheme.headingSm),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    ...exercise.instructions.asMap().entries.map((entry) {
                      return _buildInstructionItem(entry.key + 1, entry.value);
                    }),
                    const SizedBox(height: FitnessTheme.spacingLg),
                  ],
                  
                  // Tips
                  if (exercise.tips.isNotEmpty) ...[
                    Text('Tips', style: FitnessTheme.headingSm),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    FitnessCard(
                      backgroundColor: FitnessTheme.success.withValues(alpha: 0.1),
                      borderColor: FitnessTheme.success.withValues(alpha: 0.3),
                      child: Column(
                        children: exercise.tips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: FitnessTheme.success,
                                size: 18,
                              ),
                              const SizedBox(width: FitnessTheme.spacingSm),
                              Expanded(
                                child: Text(tip, style: FitnessTheme.bodyMd),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: FitnessTheme.spacingLg),
                  ],
                  
                  // Common mistakes
                  if (exercise.commonMistakes.isNotEmpty) ...[
                    Text('Common Mistakes', style: FitnessTheme.headingSm),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    FitnessCard(
                      backgroundColor: FitnessTheme.error.withValues(alpha: 0.1),
                      borderColor: FitnessTheme.error.withValues(alpha: 0.3),
                      child: Column(
                        children: exercise.commonMistakes.map((mistake) => Padding(
                          padding: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: FitnessTheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: FitnessTheme.spacingSm),
                              Expanded(
                                child: Text(mistake, style: FitnessTheme.bodyMd),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: FitnessTheme.spacingLg),
                  ],
                  
                  // Secondary body parts
                  if (exercise.secondaryBodyParts.isNotEmpty) ...[
                    Text('Also Targets', style: FitnessTheme.headingSm),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    Wrap(
                      spacing: FitnessTheme.spacingSm,
                      runSpacing: FitnessTheme.spacingSm,
                      children: exercise.secondaryBodyParts.map((part) {
                        return _buildTag(
                          part.displayName,
                          FitnessTheme.getBodyPartColor(part.displayName),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 50),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FitnessTheme.spacingSm,
        vertical: FitnessTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: FitnessTheme.borderRadiusSm,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: FitnessTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: FitnessTheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(value, style: FitnessTheme.titleMd),
        Text(label, style: FitnessTheme.caption),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      color: FitnessTheme.surface,
    );
  }

  Widget _buildInstructionItem(int number, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FitnessTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: FitnessTheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: FitnessTheme.titleSm.copyWith(
                  color: FitnessTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: FitnessTheme.spacingMd),
          Expanded(
            child: Text(
              instruction,
              style: FitnessTheme.bodyMd,
            ),
          ),
        ],
      ),
    );
  }
}
