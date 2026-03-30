import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../data/exercise_library.dart';
import '../services/fitness_storage_service.dart';

class FitnessCustomWorkoutScreen extends StatefulWidget {
  final Workout? existingWorkout;

  const FitnessCustomWorkoutScreen({
    super.key,
    this.existingWorkout,
  });

  @override
  State<FitnessCustomWorkoutScreen> createState() => _FitnessCustomWorkoutScreenState();
}

class _FitnessCustomWorkoutScreenState extends State<FitnessCustomWorkoutScreen> {
  final FitnessStorageService _storage = FitnessStorageService();
  final ExerciseLibrary _exerciseLib = ExerciseLibrary();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<WorkoutExercise> _selectedExercises = [];
  BodyPart _selectedBodyPart = BodyPart.fullBody;
  ExerciseDifficulty _selectedDifficulty = ExerciseDifficulty.beginner;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingWorkout != null) {
      _nameController.text = widget.existingWorkout!.name;
      _descController.text = widget.existingWorkout!.description;
      _selectedExercises = List.from(widget.existingWorkout!.exercises);
      _selectedBodyPart = widget.existingWorkout!.primaryBodyPart;
      _selectedDifficulty = widget.existingWorkout!.difficulty;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  int get _estimatedDuration {
    int total = 0;
    for (final ex in _selectedExercises) {
      total += ex.effectiveDurationSeconds;
      total += ex.restAfterSeconds;
    }
    return (total / 60).ceil();
  }

  int get _estimatedCalories {
    return (_estimatedDuration * 8).round();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingWorkout != null;

    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: Text(
            isEditing ? 'Edit Workout' : 'Create Workout',
            style: FitnessTheme.headingSm,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_selectedExercises.isNotEmpty)
              TextButton(
                onPressed: _isSaving ? null : _saveWorkout,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FitnessTheme.primary,
                        ),
                      )
                    : Text(
                        'Save',
                        style: FitnessTheme.titleMd.copyWith(
                          color: FitnessTheme.primary,
                        ),
                      ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(FitnessTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfo(),
              const SizedBox(height: FitnessTheme.spacingLg),
              _buildWorkoutSettings(),
              const SizedBox(height: FitnessTheme.spacingLg),
              _buildExerciseList(),
              const SizedBox(height: FitnessTheme.spacingLg),
              _buildAddExerciseButton(),
              const SizedBox(height: FitnessTheme.spacingLg),
              if (_selectedExercises.isNotEmpty) _buildWorkoutSummary(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workout Details', style: FitnessTheme.titleLg),
          const SizedBox(height: FitnessTheme.spacingMd),
          TextField(
            controller: _nameController,
            style: FitnessTheme.bodyMd,
            decoration: InputDecoration(
              labelText: 'Workout Name',
              labelStyle: FitnessTheme.bodySm,
              hintText: 'e.g., Morning Energy Boost',
              hintStyle: FitnessTheme.caption,
              filled: true,
              fillColor: FitnessTheme.surface,
              border: OutlineInputBorder(
                borderRadius: FitnessTheme.borderRadiusSm,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: FitnessTheme.borderRadiusSm,
                borderSide: const BorderSide(color: FitnessTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          TextField(
            controller: _descController,
            style: FitnessTheme.bodyMd,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: FitnessTheme.bodySm,
              hintText: 'Describe your workout...',
              hintStyle: FitnessTheme.caption,
              filled: true,
              fillColor: FitnessTheme.surface,
              border: OutlineInputBorder(
                borderRadius: FitnessTheme.borderRadiusSm,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: FitnessTheme.borderRadiusSm,
                borderSide: const BorderSide(color: FitnessTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSettings() {
    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: FitnessTheme.titleLg),
          const SizedBox(height: FitnessTheme.spacingMd),
          // Body Part Selection
          Text('Target Body Part', style: FitnessTheme.titleSm),
          const SizedBox(height: FitnessTheme.spacingSm),
          Wrap(
            spacing: FitnessTheme.spacingSm,
            runSpacing: FitnessTheme.spacingSm,
            children: BodyPart.values.map((part) {
              final isSelected = _selectedBodyPart == part;
              return GestureDetector(
                onTap: () => setState(() => _selectedBodyPart = part),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FitnessTheme.spacingMd,
                    vertical: FitnessTheme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FitnessTheme.primary
                        : FitnessTheme.surface,
                    borderRadius: FitnessTheme.borderRadiusRound,
                    border: Border.all(
                      color: isSelected
                          ? FitnessTheme.primary
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    part.displayName,
                    style: FitnessTheme.titleSm.copyWith(
                      color: isSelected
                          ? FitnessTheme.textOnPrimary
                          : FitnessTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          // Difficulty Selection
          Text('Difficulty', style: FitnessTheme.titleSm),
          const SizedBox(height: FitnessTheme.spacingSm),
          Row(
            children: ExerciseDifficulty.values.map((diff) {
              final isSelected = _selectedDifficulty == diff;
              final color = FitnessTheme.getDifficultyColor(diff.displayName);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDifficulty = diff),
                  child: Container(
                    margin: const EdgeInsets.only(right: FitnessTheme.spacingSm),
                    padding: const EdgeInsets.symmetric(vertical: FitnessTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.3) : FitnessTheme.surface,
                      borderRadius: FitnessTheme.borderRadiusSm,
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          diff == ExerciseDifficulty.beginner
                              ? Icons.sentiment_satisfied
                              : diff == ExerciseDifficulty.intermediate
                                  ? Icons.sentiment_neutral
                                  : Icons.sentiment_very_dissatisfied,
                          color: color,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          diff.displayName,
                          style: FitnessTheme.caption.copyWith(
                            color: isSelected ? color : FitnessTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    if (_selectedExercises.isEmpty) {
      return FitnessCard(
        backgroundColor: FitnessTheme.surface,
        child: Column(
          children: [
            Icon(
              Icons.fitness_center,
              size: 48,
              color: FitnessTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text(
              'No exercises added yet',
              style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.textMuted),
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              'Tap the button below to add exercises',
              style: FitnessTheme.bodySm,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Exercises (${_selectedExercises.length})', style: FitnessTheme.titleLg),
            TextButton.icon(
              onPressed: _reorderExercises,
              icon: const Icon(Icons.swap_vert, size: 18),
              label: const Text('Reorder'),
              style: TextButton.styleFrom(
                foregroundColor: FitnessTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        ...List.generate(_selectedExercises.length, (index) {
          final workoutExercise = _selectedExercises[index];
          final exercise = _exerciseLib.getById(workoutExercise.exerciseId);
          if (exercise == null) return const SizedBox.shrink();

          return _buildExerciseItem(exercise, workoutExercise, index);
        }),
      ],
    );
  }

  Widget _buildExerciseItem(Exercise exercise, WorkoutExercise workoutExercise, int index) {
    return Dismissible(
      key: Key('${workoutExercise.exerciseId}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: FitnessTheme.spacingMd),
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        decoration: BoxDecoration(
          color: FitnessTheme.error,
          borderRadius: FitnessTheme.borderRadiusMd,
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => _selectedExercises.removeAt(index));
        HapticFeedback.lightImpact();
      },
      child: FitnessCard(
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        onTap: () => _editExerciseSettings(index),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FitnessTheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.primary),
                ),
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: FitnessTheme.titleSm),
                  Text(
                    workoutExercise.displayDuration,
                    style: FitnessTheme.caption,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FitnessTheme.spacingSm,
                vertical: FitnessTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: FitnessTheme.info.withValues(alpha: 0.2),
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Text(
                'Rest: ${workoutExercise.restAfterSeconds}s',
                style: FitnessTheme.caption.copyWith(color: FitnessTheme.info),
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingSm),
            const Icon(Icons.edit, size: 18, color: FitnessTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildAddExerciseButton() {
    return FitnessPrimaryButton(
      text: 'Add Exercise',
      icon: Icons.add,
      onPressed: _showExercisePicker,
    );
  }

  Widget _buildWorkoutSummary() {
    return FitnessCard(
      backgroundColor: FitnessTheme.primary.withValues(alpha: 0.1),
      borderColor: FitnessTheme.primary.withValues(alpha: 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(Icons.timer, '$_estimatedDuration min', 'Duration'),
          _buildSummaryItem(Icons.fitness_center, '${_selectedExercises.length}', 'Exercises'),
          _buildSummaryItem(Icons.local_fire_department, '~$_estimatedCalories', 'Calories'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: FitnessTheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.primary)),
        Text(label, style: FitnessTheme.caption),
      ],
    );
  }

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _ExercisePickerSheet(
          scrollController: scrollController,
          onExerciseSelected: (exercise) {
            setState(() {
              _selectedExercises.add(WorkoutExercise(
                exerciseId: exercise.id,
                customDurationSeconds: exercise.defaultDurationSeconds,
                customReps: exercise.defaultReps,
                restAfterSeconds: 30,
                orderIndex: _selectedExercises.length,
              ));
            });
            HapticFeedback.lightImpact();
          },
        ),
      ),
    );
  }

  void _editExerciseSettings(int index) {
    final workoutExercise = _selectedExercises[index];
    final exercise = _exerciseLib.getById(workoutExercise.exerciseId);
    if (exercise == null) return;

    int duration = workoutExercise.customDurationSeconds ?? exercise.defaultDurationSeconds ?? 30;
    int? reps = workoutExercise.customReps ?? exercise.defaultReps;
    int rest = workoutExercise.restAfterSeconds;

    showModalBottomSheet(
      context: context,
      backgroundColor: FitnessTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FitnessTheme.radiusLg)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(FitnessTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exercise.name, style: FitnessTheme.headingSm),
              const SizedBox(height: FitnessTheme.spacingLg),
              // Duration/Reps
              if (exercise.type == ExerciseType.timed) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Duration', style: FitnessTheme.titleSm),
                    Text('$duration seconds', style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.primary)),
                  ],
                ),
                Slider(
                  value: duration.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 22,
                  activeColor: FitnessTheme.primary,
                  onChanged: (v) => setSheetState(() => duration = v.toInt()),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reps', style: FitnessTheme.titleSm),
                    Text('${reps ?? 10} reps', style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.primary)),
                  ],
                ),
                Slider(
                  value: (reps ?? 10).toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  activeColor: FitnessTheme.primary,
                  onChanged: (v) => setSheetState(() => reps = v.toInt()),
                ),
              ],
              const SizedBox(height: FitnessTheme.spacingMd),
              // Rest
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rest After', style: FitnessTheme.titleSm),
                  Text('$rest seconds', style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.info)),
                ],
              ),
              Slider(
                value: rest.toDouble(),
                min: 0,
                max: 60,
                divisions: 12,
                activeColor: FitnessTheme.info,
                onChanged: (v) => setSheetState(() => rest = v.toInt()),
              ),
              const SizedBox(height: FitnessTheme.spacingLg),
              FitnessPrimaryButton(
                text: 'Save',
                onPressed: () {
                  setState(() {
                    _selectedExercises[index] = WorkoutExercise(
                      exerciseId: exercise.id,
                      customDurationSeconds: exercise.type == ExerciseType.timed ? duration : null,
                      customReps: exercise.type == ExerciseType.reps ? reps : null,
                      restAfterSeconds: rest,
                      orderIndex: index,
                    );
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: FitnessTheme.spacingMd),
            ],
          ),
        ),
      ),
    );
  }

  void _reorderExercises() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitnessTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FitnessTheme.radiusLg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(FitnessTheme.spacingMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reorder Exercises', style: FitnessTheme.headingSm),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollController,
                itemCount: _selectedExercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _selectedExercises.removeAt(oldIndex);
                    _selectedExercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final ex = _selectedExercises[index];
                  final exercise = _exerciseLib.getById(ex.exerciseId);
                  return ListTile(
                    key: Key('reorder_$index'),
                    leading: CircleAvatar(
                      backgroundColor: FitnessTheme.primary.withValues(alpha: 0.2),
                      child: Text('${index + 1}', style: TextStyle(color: FitnessTheme.primary)),
                    ),
                    title: Text(exercise?.name ?? 'Unknown', style: FitnessTheme.titleSm),
                    subtitle: Text(ex.displayDuration, style: FitnessTheme.caption),
                    trailing: const Icon(Icons.drag_handle),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveWorkout() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a workout name'),
          backgroundColor: FitnessTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final workout = Workout(
      id: widget.existingWorkout?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      primaryBodyPart: _selectedBodyPart,
      targetedBodyParts: [_selectedBodyPart],
      difficulty: _selectedDifficulty,
      exercises: _selectedExercises,
      estimatedDurationMinutes: _estimatedDuration,
      estimatedCalories: _estimatedCalories,
      isCustom: true,
      createdAt: widget.existingWorkout?.createdAt ?? DateTime.now(),
    );

    final success = await _storage.saveCustomWorkout(workout);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, workout);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save workout'),
            backgroundColor: FitnessTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// Exercise Picker Sheet
class _ExercisePickerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final Function(Exercise) onExerciseSelected;

  const _ExercisePickerSheet({
    required this.scrollController,
    required this.onExerciseSelected,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final ExerciseLibrary _exerciseLib = ExerciseLibrary();
  BodyPart? _filterBodyPart;
  String _searchQuery = '';

  List<Exercise> get _filteredExercises {
    var exercises = _exerciseLib.allExercises;
    if (_filterBodyPart != null) {
      exercises = exercises.where((e) => e.primaryBodyPart == _filterBodyPart).toList();
    }
    if (_searchQuery.isNotEmpty) {
      exercises = exercises.where((e) => 
        e.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return exercises;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FitnessTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(FitnessTheme.radiusLg)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: FitnessTheme.spacingSm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FitnessTheme.textMuted,
              borderRadius: FitnessTheme.borderRadiusRound,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(FitnessTheme.spacingMd),
            child: Column(
              children: [
                Text('Add Exercise', style: FitnessTheme.headingSm),
                const SizedBox(height: FitnessTheme.spacingMd),
                // Search
                TextField(
                  style: FitnessTheme.bodyMd,
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    hintStyle: FitnessTheme.bodySm,
                    prefixIcon: const Icon(Icons.search, color: FitnessTheme.textMuted),
                    filled: true,
                    fillColor: FitnessTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: FitnessTheme.borderRadiusMd,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: FitnessTheme.spacingSm),
                // Filter chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(null, 'All'),
                      ...BodyPart.values.map((part) => _buildFilterChip(part, part.displayName)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingMd),
              itemCount: _filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
                return ListTile(
                  onTap: () {
                    widget.onExerciseSelected(exercise);
                    Navigator.pop(context);
                  },
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: FitnessTheme.getBodyPartColor(exercise.primaryBodyPart.displayName).withValues(alpha: 0.2),
                      borderRadius: FitnessTheme.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: FitnessTheme.getBodyPartColor(exercise.primaryBodyPart.displayName),
                    ),
                  ),
                  title: Text(exercise.name, style: FitnessTheme.titleSm),
                  subtitle: Text(
                    '${exercise.primaryBodyPart.displayName} • ${exercise.displayDuration}',
                    style: FitnessTheme.caption,
                  ),
                  trailing: const Icon(Icons.add_circle_outline, color: FitnessTheme.primary),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BodyPart? part, String label) {
    final isSelected = _filterBodyPart == part;
    return GestureDetector(
      onTap: () => setState(() => _filterBodyPart = part),
      child: Container(
        margin: const EdgeInsets.only(right: FitnessTheme.spacingSm),
        padding: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          color: isSelected ? FitnessTheme.primary : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusRound,
        ),
        child: Center(
          child: Text(
            label,
            style: FitnessTheme.titleSm.copyWith(
              color: isSelected ? FitnessTheme.textOnPrimary : FitnessTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
