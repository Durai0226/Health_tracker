import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../widgets/exercise_lottie_player.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../data/exercise_library.dart';
import '../services/fitness_storage_service.dart';
import 'fitness_active_workout_screen.dart';
import 'fitness_exercise_detail_screen.dart';

class FitnessWorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const FitnessWorkoutDetailScreen({
    super.key,
    required this.workout,
  });

  @override
  State<FitnessWorkoutDetailScreen> createState() => _FitnessWorkoutDetailScreenState();
}

class _FitnessWorkoutDetailScreenState extends State<FitnessWorkoutDetailScreen> {
  final FitnessStorageService _storage = FitnessStorageService();
  final ExerciseLibrary _exerciseLib = ExerciseLibrary();
  
  bool _isFavorite = false;
  int _completionCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isFav = await _storage.isFavorite(widget.workout.id);
    final count = await _storage.getWorkoutCompletionCount(widget.workout.id);
    
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _completionCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final bodyPartColor = FitnessTheme.getBodyPartColor(workout.primaryBodyPart.displayName);

    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(workout, bodyPartColor),
            SliverPadding(
              padding: const EdgeInsets.all(FitnessTheme.spacingMd),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildInfoCard(workout),
                  const SizedBox(height: FitnessTheme.spacingLg),
                  _buildExerciseList(workout),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(workout),
      ),
    );
  }

  Widget _buildAppBar(Workout workout, Color color) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: FitnessTheme.background,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FitnessTheme.background.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_rounded, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FitnessTheme.background.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? FitnessTheme.error : FitnessTheme.textPrimary,
              size: 18,
            ),
          ),
          onPressed: _toggleFavorite,
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FitnessTheme.background.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined, size: 18),
          ),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.4),
                color.withOpacity(0.1),
                FitnessTheme.background,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPatternPainter(color: color.withOpacity(0.1)),
                ),
              ),
              // Content
              Positioned(
                bottom: FitnessTheme.spacingLg,
                left: FitnessTheme.spacingMd,
                right: FitnessTheme.spacingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FitnessTheme.spacingSm,
                        vertical: FitnessTheme.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: FitnessTheme.borderRadiusSm,
                      ),
                      child: Text(
                        workout.primaryBodyPart.displayName.toUpperCase(),
                        style: FitnessTheme.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: FitnessTheme.spacingSm),
                    Text(
                      workout.name,
                      style: FitnessTheme.headingLg,
                    ),
                    const SizedBox(height: FitnessTheme.spacingXs),
                    Text(
                      workout.description,
                      style: FitnessTheme.bodySm,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(Workout workout) {
    final difficultyColor = FitnessTheme.getDifficultyColor(workout.difficulty.displayName);

    return FitnessCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            Icons.timer_outlined,
            workout.formattedDuration,
            'Duration',
            FitnessTheme.info,
          ),
          _buildDivider(),
          _buildInfoItem(
            Icons.fitness_center,
            '${workout.exercises.length}',
            'Exercises',
            FitnessTheme.primary,
          ),
          _buildDivider(),
          _buildInfoItem(
            Icons.local_fire_department,
            '~${workout.estimatedCalories}',
            'Calories',
            FitnessTheme.warning,
          ),
          _buildDivider(),
          _buildInfoItem(
            Icons.speed,
            workout.difficulty.displayName,
            'Level',
            difficultyColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: FitnessTheme.titleMd.copyWith(color: color),
        ),
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

  Widget _buildExerciseList(Workout workout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Exercises', style: FitnessTheme.headingSm),
            if (_completionCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitnessTheme.spacingSm,
                  vertical: FitnessTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: FitnessTheme.success.withOpacity(0.2),
                  borderRadius: FitnessTheme.borderRadiusSm,
                ),
                child: Text(
                  'Completed $_completionCount times',
                  style: FitnessTheme.caption.copyWith(
                    color: FitnessTheme.success,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingMd),
        ...workout.exercises.asMap().entries.map((entry) {
          final index = entry.key;
          final workoutExercise = entry.value;
          final exercise = _exerciseLib.getById(workoutExercise.exerciseId);

          if (exercise == null) return const SizedBox.shrink();

          return ExerciseCard(
            name: exercise.name,
            duration: workoutExercise.displayDuration,
            reps: workoutExercise.effectiveReps,
            index: index,
            onTap: () => _openExerciseDetail(exercise),
            leading: ExerciseThumbnail(
              assetPath: exercise.lottieAsset,
              networkUrl: exercise.lottieUrl,
              size: 48,
            ),
          );
        }),
        // Rest info
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          backgroundColor: FitnessTheme.surface,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FitnessTheme.info.withOpacity(0.2),
                  borderRadius: FitnessTheme.borderRadiusSm,
                ),
                child: const Icon(
                  Icons.timer,
                  color: FitnessTheme.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rest Between Exercises', style: FitnessTheme.titleSm),
                    Text(
                      '${workout.exercises.isNotEmpty ? workout.exercises.first.restAfterSeconds : 30} seconds',
                      style: FitnessTheme.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(Workout workout) {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(
        color: FitnessTheme.background,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: FitnessPrimaryButton(
          text: 'Start Workout',
          icon: Icons.play_arrow_rounded,
          onPressed: () => _startWorkout(workout),
        ),
      ),
    );
  }

  void _toggleFavorite() async {
    HapticFeedback.lightImpact();
    await _storage.toggleFavorite(widget.workout.id);
    final isFav = await _storage.isFavorite(widget.workout.id);
    setState(() => _isFavorite = isFav);
  }

  void _openExerciseDetail(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FitnessExerciseDetailScreen(exercise: exercise),
      ),
    );
  }

  void _startWorkout(Workout workout) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FitnessActiveWorkoutScreen(workout: workout),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  final Color color;

  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 30.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
