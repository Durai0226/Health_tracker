import 'package:flutter/material.dart';
import '../theme/flo_theme.dart';
import '../widgets/widgets.dart';
import '../models/cycle_workout.dart';
import '../services/period_prediction_service.dart';
import '../services/period_storage_service.dart';

/// Fitness screen with phase-appropriate workout recommendations
class FloFitnessScreen extends StatefulWidget {
  const FloFitnessScreen({super.key});

  @override
  State<FloFitnessScreen> createState() => _FloFitnessScreenState();
}

class _FloFitnessScreenState extends State<FloFitnessScreen> {
  WorkoutCategory? _selectedCategory;
  CyclePhaseType _currentPhase = CyclePhaseType.follicular;
  List<CycleWorkout> _recommendedWorkouts = [];
  double _weeklyProgress = 75;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Get current phase
    final settings = PeriodCleanStorageService.getSettings();
    final lastPeriod = DateTime.now().subtract(const Duration(days: 10));
    final legacyPhase = PeriodPredictionService.getCurrentPhase(
      lastPeriod,
      settings.defaultCycleLength,
      settings.defaultPeriodDuration,
      DateTime.now(),
    );
    _currentPhase = CyclePhaseTypeExtension.fromLegacy(legacyPhase);
    
    // Get recommended workouts for current phase
    _recommendedWorkouts = PhaseWorkouts.getForPhase(_currentPhase);
    
    setState(() {});
  }

  List<CycleWorkout> get _filteredWorkouts {
    if (_selectedCategory == null) {
      return _recommendedWorkouts;
    }
    return _recommendedWorkouts
        .where((w) => w.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FloTheme.getBackground(context),
      appBar: FloAppBar(
        titleWidget: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Flo ',
                style: FloTheme.headlineMedium.copyWith(
                  color: FloTheme.periodPink,
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextSpan(
                text: 'Fitness',
                style: FloTheme.headlineMedium.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress card
            Padding(
              padding: const EdgeInsets.all(FloTheme.spacingLg),
              child: FloWorkoutProgress(
                percentage: _weeklyProgress,
                label: 'Weekly goal',
              ),
            ),

            // Current phase info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
              child: _buildPhaseInfo(),
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Categories
            Padding(
              padding: const EdgeInsets.only(left: FloTheme.spacingLg),
              child: Text(
                'Categories',
                style: FloTheme.headlineSmall.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
              ),
            ),

            const SizedBox(height: FloTheme.spacingMd),

            FloCategorySelector(
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() => _selectedCategory = category);
              },
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Recommended workouts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recommended Workouts',
                    style: FloTheme.headlineSmall.copyWith(
                      color: FloTheme.getTextPrimary(context),
                    ),
                  ),
                  Text(
                    '${_filteredWorkouts.length} workouts',
                    style: FloTheme.bodySmall.copyWith(
                      color: FloTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: FloTheme.spacingMd),

            // Workout grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
              child: _buildWorkoutGrid(),
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // All workouts list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
              child: Text(
                'All Workouts',
                style: FloTheme.headlineSmall.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
              ),
            ),

            const SizedBox(height: FloTheme.spacingMd),

            ..._buildWorkoutList(),

            const SizedBox(height: FloTheme.spacing4xl),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseInfo() {
    final phaseColor = FloTheme.getPhaseColor(_currentPhase);
    final phaseName = FloTheme.getPhaseName(_currentPhase);
    final intensities = WorkoutIntensityExtension.forPhase(_currentPhase);
    
    return FloGlassCard(
      color: phaseColor.withOpacity(0.1),
      borderColor: phaseColor.withOpacity(0.2),
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(FloTheme.spacingMd),
            decoration: BoxDecoration(
              color: phaseColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(FloTheme.radiusMd),
            ),
            child: Text(
              FloTheme.getPhaseEmoji(_currentPhase),
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: FloTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phaseName,
                  style: FloTheme.titleLarge.copyWith(
                    color: phaseColor,
                  ),
                ),
                Text(
                  'Best for ${intensities.map((i) => i.displayName.toLowerCase()).join(', ')} intensity',
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutGrid() {
    final workouts = _filteredWorkouts.take(2).toList();
    
    if (workouts.isEmpty) {
      return FloGlassCard(
        padding: const EdgeInsets.all(FloTheme.spacingXl),
        child: Center(
          child: Text(
            'No workouts in this category',
            style: FloTheme.bodyMedium.copyWith(
              color: FloTheme.getTextSecondary(context),
            ),
          ),
        ),
      );
    }

    return Row(
      children: workouts.map((workout) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: workout != workouts.last ? FloTheme.spacingMd : 0,
            ),
            child: FloWorkoutCard(
              workout: workout,
              onTap: () => _openWorkout(workout),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildWorkoutList() {
    final allWorkouts = _selectedCategory == null
        ? PhaseWorkouts.allWorkouts
        : PhaseWorkouts.allWorkouts
            .where((w) => w.category == _selectedCategory)
            .toList();

    return allWorkouts.skip(2).map((workout) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FloTheme.spacingLg,
          vertical: FloTheme.spacingXs,
        ),
        child: FloWorkoutCardCompact(
          workout: workout,
          onTap: () => _openWorkout(workout),
        ),
      );
    }).toList();
  }

  void _openWorkout(CycleWorkout workout) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkoutDetailSheet(workout: workout),
    );
  }
}

class _WorkoutDetailSheet extends StatelessWidget {
  final CycleWorkout workout;

  const _WorkoutDetailSheet({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: FloTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FloTheme.radius2xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: FloTheme.spacingMd),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FloTheme.getDivider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header image
          Container(
            height: 180,
            margin: const EdgeInsets.all(FloTheme.spacingLg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FloTheme.periodPink.withOpacity(0.3),
                  FloTheme.periodPink.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(FloTheme.radiusXl),
            ),
            child: Center(
              child: Text(
                workout.category.icon,
                style: const TextStyle(fontSize: 72),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    workout.name,
                    style: FloTheme.headlineLarge.copyWith(
                      color: FloTheme.getTextPrimary(context),
                    ),
                  ),

                  const SizedBox(height: FloTheme.spacingSm),

                  // Description
                  Text(
                    workout.description,
                    style: FloTheme.bodyMedium.copyWith(
                      color: FloTheme.getTextSecondary(context),
                    ),
                  ),

                  const SizedBox(height: FloTheme.spacingLg),

                  // Stats
                  Row(
                    children: [
                      _StatBadge(
                        icon: Icons.timer_outlined,
                        value: '${workout.durationMinutes} min',
                      ),
                      const SizedBox(width: FloTheme.spacingMd),
                      _StatBadge(
                        icon: Icons.local_fire_department_rounded,
                        value: '${workout.caloriesBurned} kcal',
                      ),
                      const SizedBox(width: FloTheme.spacingMd),
                      _StatBadge(
                        icon: Icons.speed_rounded,
                        value: workout.intensity.displayName,
                      ),
                    ],
                  ),

                  const SizedBox(height: FloTheme.spacing2xl),

                  // Benefits
                  Text(
                    'Best for',
                    style: FloTheme.titleLarge.copyWith(
                      color: FloTheme.getTextPrimary(context),
                    ),
                  ),

                  const SizedBox(height: FloTheme.spacingMd),

                  Wrap(
                    spacing: FloTheme.spacingSm,
                    runSpacing: FloTheme.spacingSm,
                    children: workout.recommendedPhases.map((phase) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FloTheme.spacingMd,
                          vertical: FloTheme.spacingSm,
                        ),
                        decoration: BoxDecoration(
                          color: FloTheme.getPhaseColor(phase).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(FloTheme.radiusFull),
                        ),
                        child: Text(
                          FloTheme.getPhaseName(phase),
                          style: FloTheme.labelSmall.copyWith(
                            color: FloTheme.getPhaseColor(phase),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: FloTheme.spacing3xl),
                ],
              ),
            ),
          ),

          // Start button
          Padding(
            padding: const EdgeInsets.all(FloTheme.spacingLg),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Start workout
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FloTheme.periodPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: FloTheme.spacingLg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                  ),
                ),
                child: const Text(
                  'Start Workout',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatBadge({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FloTheme.spacingMd,
        vertical: FloTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: FloTheme.getDivider(context),
        borderRadius: BorderRadius.circular(FloTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FloTheme.getTextSecondary(context)),
          const SizedBox(width: 4),
          Text(
            value,
            style: FloTheme.labelSmall.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
