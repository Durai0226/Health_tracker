import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/fitness_theme.dart';
import 'breathing_exercise_screen.dart';

/// Mindfulness and meditation hub for fitness feature
/// Includes pre-workout focus, post-workout recovery, and rest day activities
class MindfulnessScreen extends StatefulWidget {
  const MindfulnessScreen({super.key});

  @override
  State<MindfulnessScreen> createState() => _MindfulnessScreenState();
}

class _MindfulnessScreenState extends State<MindfulnessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(FitnessTheme.spacingMd),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildBreathingVisual(),
                  const SizedBox(height: FitnessTheme.spacingLg),
                  _buildQuickSessions(),
                  const SizedBox(height: FitnessTheme.spacingLg),
                  _buildBreathingExercises(),
                  const SizedBox(height: FitnessTheme.spacingLg),
                  _buildRestDayActivities(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: FitnessTheme.background,
      title: Text('Mindfulness', style: FitnessTheme.headingMd),
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildBreathingVisual() {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E).withValues(alpha: 0.3),
            const Color(0xFF4A148C).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: FitnessTheme.borderRadiusLg,
      ),
      child: Column(
        children: [
          Text(
            'Take a Breath',
            style: FitnessTheme.headingSm.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) {
              final scale = 0.8 + (_breatheController.value * 0.4);
              final opacity = 0.3 + (_breatheController.value * 0.4);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  Container(
                    width: 160 * scale,
                    height: 160 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FitnessTheme.primary.withValues(alpha: opacity * 0.3),
                    ),
                  ),
                  // Middle ring
                  Container(
                    width: 120 * scale,
                    height: 120 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FitnessTheme.primary.withValues(alpha: opacity * 0.5),
                    ),
                  ),
                  // Inner circle
                  Container(
                    width: 80 * scale,
                    height: 80 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FitnessTheme.primary.withValues(alpha: opacity),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) {
              final isInhale = _breatheController.status == AnimationStatus.forward;
              return Text(
                isInhale ? 'Inhale...' : 'Exhale...',
                style: FitnessTheme.titleMd.copyWith(
                  color: FitnessTheme.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Sessions', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _SessionCard(
                title: 'Pre-Workout',
                subtitle: '3-5 min focus',
                icon: Icons.fitness_center,
                color: const Color(0xFF4CAF50),
                onTap: () => _startSession('pre_workout'),
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: _SessionCard(
                title: 'Post-Workout',
                subtitle: '5 min recovery',
                icon: Icons.self_improvement,
                color: const Color(0xFF2196F3),
                onTap: () => _startSession('post_workout'),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingMd),
        _SessionCard(
          title: 'Sleep Meditation',
          subtitle: '5-10 min • Rest day recovery',
          icon: Icons.bedtime,
          color: const Color(0xFF9C27B0),
          onTap: () => _startSession('sleep'),
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildBreathingExercises() {
    final exercises = [
      _BreathingExercise(
        name: 'Box Breathing',
        description: 'Focus + stress control',
        pattern: '4-4-4-4',
        icon: Icons.crop_square,
        color: const Color(0xFF00BCD4),
      ),
      _BreathingExercise(
        name: '4-7-8 Breathing',
        description: 'Relaxation + sleep',
        pattern: '4-7-8',
        icon: Icons.nights_stay,
        color: const Color(0xFF673AB7),
      ),
      _BreathingExercise(
        name: 'Deep Breathing',
        description: 'Simple calming',
        pattern: '4-6',
        icon: Icons.air,
        color: const Color(0xFF009688),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Breathing Exercises', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        ...exercises.map((e) => _BreathingExerciseCard(
          exercise: e,
          onTap: () => _openBreathingExercise(e),
        )),
      ],
    );
  }

  Widget _buildRestDayActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rest Day Activities', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        _RestDayCard(
          title: 'Gentle Stretching',
          duration: '10-15 min',
          description: 'Hamstrings, shoulders, lower back',
          icon: Icons.accessibility_new,
          onTap: () {},
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        _RestDayCard(
          title: 'Light Yoga Flow',
          duration: '10-20 min',
          description: 'Cat-Cow, Child\'s Pose, Downward Dog',
          icon: Icons.self_improvement,
          onTap: () {},
        ),
        const SizedBox(height: FitnessTheme.spacingMd),
        _buildWellnessTips(),
      ],
    );
  }

  Widget _buildWellnessTips() {
    final tips = [
      'Avoid intense physical stress on rest days',
      'Reduce screen time before sleep',
      'Stay hydrated throughout the day',
      'Practice gratitude journaling (2-3 mins)',
    ];

    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(
        color: FitnessTheme.info.withValues(alpha: 0.1),
        borderRadius: FitnessTheme.borderRadiusMd,
        border: Border.all(
          color: FitnessTheme.info.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: FitnessTheme.info, size: 20),
              const SizedBox(width: FitnessTheme.spacingSm),
              Text(
                'Mental Wellness Tips',
                style: FitnessTheme.titleSm.copyWith(
                  color: FitnessTheme.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingSm),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: FitnessTheme.bodySm),
                Expanded(
                  child: Text(tip, style: FitnessTheme.bodySm),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _startSession(String type) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreathingExerciseScreen(sessionType: type),
      ),
    );
  }

  void _openBreathingExercise(_BreathingExercise exercise) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreathingExerciseScreen(
          exerciseName: exercise.name,
          pattern: exercise.pattern,
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isWide;

  const _SessionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FitnessTheme.titleMd.copyWith(color: color),
                  ),
                  Text(subtitle, style: FitnessTheme.bodySm),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill, color: color, size: 32),
          ],
        ),
      ),
    );
  }
}

class _BreathingExercise {
  final String name;
  final String description;
  final String pattern;
  final IconData icon;
  final Color color;

  const _BreathingExercise({
    required this.name,
    required this.description,
    required this.pattern,
    required this.icon,
    required this.color,
  });
}

class _BreathingExerciseCard extends StatelessWidget {
  final _BreathingExercise exercise;
  final VoidCallback onTap;

  const _BreathingExerciseCard({
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: FitnessTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: exercise.color.withValues(alpha: 0.2),
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Icon(exercise.icon, color: exercise.color),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: FitnessTheme.titleMd),
                  Text(exercise.description, style: FitnessTheme.bodySm),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FitnessTheme.spacingSm,
                vertical: FitnessTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: exercise.color.withValues(alpha: 0.2),
                borderRadius: FitnessTheme.borderRadiusRound,
              ),
              child: Text(
                exercise.pattern,
                style: FitnessTheme.caption.copyWith(
                  color: exercise.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  final String title;
  final String duration;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _RestDayCard({
    required this.title,
    required this.duration,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: FitnessTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FitnessTheme.primary.withValues(alpha: 0.15),
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Icon(icon, color: FitnessTheme.primary),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: FitnessTheme.titleMd),
                      const SizedBox(width: FitnessTheme.spacingSm),
                      Text(
                        duration,
                        style: FitnessTheme.caption.copyWith(
                          color: FitnessTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(description, style: FitnessTheme.bodySm),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: FitnessTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
