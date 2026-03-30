import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/breathing_exercise.dart';
import '../widgets/breathing_exercise_card.dart';
import '../../theme/mood_theme.dart';
import 'bloom_breath_session_screen.dart';

/// Breathing exercises list screen matching Behance design
/// Shows: Calm Flow, Soft Rest, Deep Ease, Slow Calm
class BloomBreathListScreen extends StatefulWidget {
  const BloomBreathListScreen({super.key});

  @override
  State<BloomBreathListScreen> createState() => _BloomBreathListScreenState();
}

class _BloomBreathListScreenState extends State<BloomBreathListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final List<BreathingExercise> _exercises = BreathingExercise.defaultExercises;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _startExercise(BreathingExercise exercise) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloomBreathSessionScreen(exercise: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: MoodTheme.background,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),

                // Exercise list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MoodTheme.spacingLg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final exercise = _exercises[index];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: BreathingExerciseCard(
                                  exercise: exercise,
                                  onTap: () => _startExercise(exercise),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _exercises.length,
                    ),
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breath',
            style: MoodTheme.headingLg.copyWith(
              color: MoodTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an exercise to begin',
            style: MoodTheme.bodyMd.copyWith(
              color: MoodTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
