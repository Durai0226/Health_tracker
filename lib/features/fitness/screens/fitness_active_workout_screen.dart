import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_button.dart';
import '../widgets/fitness_progress_ring.dart';
import '../widgets/exercise_lottie_player.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../data/exercise_library.dart';
import '../services/fitness_storage_service.dart';

enum WorkoutState { countdown, exercise, rest, completed, paused }

class FitnessActiveWorkoutScreen extends StatefulWidget {
  final Workout workout;

  const FitnessActiveWorkoutScreen({
    super.key,
    required this.workout,
  });

  @override
  State<FitnessActiveWorkoutScreen> createState() => _FitnessActiveWorkoutScreenState();
}

class _FitnessActiveWorkoutScreenState extends State<FitnessActiveWorkoutScreen>
    with TickerProviderStateMixin {
  final FitnessStorageService _storage = FitnessStorageService();
  final ExerciseLibrary _exerciseLib = ExerciseLibrary();

  late AnimationController _pulseController;
  Timer? _timer;

  WorkoutState _state = WorkoutState.countdown;
  int _currentExerciseIndex = 0;
  int _remainingSeconds = 3;
  int _totalSeconds = 3;
  int _totalWorkoutSeconds = 0;
  DateTime? _startTime;

  List<ExerciseLog> _exerciseLogs = [];
  bool _isPaused = false;

  Exercise? get _currentExercise {
    if (_currentExerciseIndex >= widget.workout.exercises.length) return null;
    final workoutExercise = widget.workout.exercises[_currentExerciseIndex];
    return _exerciseLib.getById(workoutExercise.exerciseId);
  }

  WorkoutExercise? get _currentWorkoutExercise {
    if (_currentExerciseIndex >= widget.workout.exercises.length) return null;
    return widget.workout.exercises[_currentExerciseIndex];
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _startTime = DateTime.now();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _state = WorkoutState.countdown;
      _remainingSeconds = 3;
      _totalSeconds = 3;
    });
    _startTimer();
  }

  void _startExercise() {
    final workoutExercise = _currentWorkoutExercise;
    if (workoutExercise == null) {
      _completeWorkout();
      return;
    }

    setState(() {
      _state = WorkoutState.exercise;
      _remainingSeconds = workoutExercise.effectiveDurationSeconds;
      _totalSeconds = workoutExercise.effectiveDurationSeconds;
    });
    _startTimer();
  }

  void _startRest() {
    final workoutExercise = _currentWorkoutExercise;
    if (workoutExercise == null || workoutExercise.restAfterSeconds == 0) {
      _nextExercise();
      return;
    }

    setState(() {
      _state = WorkoutState.rest;
      _remainingSeconds = workoutExercise.restAfterSeconds;
      _totalSeconds = workoutExercise.restAfterSeconds;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        _remainingSeconds--;
        _totalWorkoutSeconds++;
      });

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _onTimerComplete();
      }

      // Haptic feedback for last 3 seconds
      if (_remainingSeconds <= 3 && _remainingSeconds > 0) {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _onTimerComplete() {
    HapticFeedback.mediumImpact();

    switch (_state) {
      case WorkoutState.countdown:
        _startExercise();
        break;
      case WorkoutState.exercise:
        _logExercise(completed: true);
        _startRest();
        break;
      case WorkoutState.rest:
        _nextExercise();
        break;
      default:
        break;
    }
  }

  void _logExercise({required bool completed, bool skipped = false}) {
    final exercise = _currentExercise;
    final workoutExercise = _currentWorkoutExercise;
    if (exercise == null || workoutExercise == null) return;

    _exerciseLogs.add(ExerciseLog(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      startedAt: DateTime.now().subtract(Duration(seconds: _totalSeconds - _remainingSeconds)),
      completedAt: DateTime.now(),
      durationSeconds: _totalSeconds - _remainingSeconds,
      repsCompleted: workoutExercise.effectiveReps,
      wasCompleted: completed,
      wasSkipped: skipped,
      caloriesBurned: exercise.estimateCalories(_totalSeconds - _remainingSeconds),
    ));
  }

  void _nextExercise() {
    if (_currentExerciseIndex + 1 >= widget.workout.exercises.length) {
      _completeWorkout();
      return;
    }

    setState(() {
      _currentExerciseIndex++;
    });
    _startExercise();
  }

  void _skipExercise() {
    HapticFeedback.lightImpact();
    _logExercise(completed: false, skipped: true);
    _timer?.cancel();
    _nextExercise();
  }

  void _previousExercise() {
    if (_currentExerciseIndex <= 0) return;
    
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _currentExerciseIndex--;
    });
    _startExercise();
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _state = WorkoutState.paused;
      } else {
        if (_remainingSeconds > 0) {
          _state = WorkoutState.exercise;
        }
      }
    });
  }

  void _completeWorkout() {
    _timer?.cancel();
    setState(() => _state = WorkoutState.completed);

    // Save session
    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workoutId: widget.workout.id,
      workoutName: widget.workout.name,
      startedAt: _startTime ?? DateTime.now(),
      completedAt: DateTime.now(),
      durationSeconds: _totalWorkoutSeconds,
      caloriesBurned: _exerciseLogs.fold(0, (sum, log) => sum + log.caloriesBurned),
      exercisesCompleted: _exerciseLogs.where((l) => l.wasCompleted).length,
      totalExercises: widget.workout.exercises.length,
      wasCompleted: true,
      exerciseLogs: _exerciseLogs,
      primaryBodyPart: widget.workout.primaryBodyPart,
    );

    _storage.saveSession(session);
    _showCompletionDialog(session);
  }

  void _abandonWorkout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FitnessTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusLg),
        title: Text('Quit Workout?', style: FitnessTheme.headingSm),
        content: Text(
          'Your progress will be saved but the workout will be marked as incomplete.',
          style: FitnessTheme.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue', style: TextStyle(color: FitnessTheme.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveAndExit(abandoned: true);
            },
            child: Text('Quit', style: TextStyle(color: FitnessTheme.error)),
          ),
        ],
      ),
    );
  }

  void _saveAndExit({bool abandoned = false}) {
    _timer?.cancel();

    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workoutId: widget.workout.id,
      workoutName: widget.workout.name,
      startedAt: _startTime ?? DateTime.now(),
      completedAt: DateTime.now(),
      durationSeconds: _totalWorkoutSeconds,
      caloriesBurned: _exerciseLogs.fold(0, (sum, log) => sum + log.caloriesBurned),
      exercisesCompleted: _exerciseLogs.where((l) => l.wasCompleted).length,
      totalExercises: widget.workout.exercises.length,
      wasCompleted: false,
      wasAbandoned: abandoned,
      exerciseLogs: _exerciseLogs,
      primaryBodyPart: widget.workout.primaryBodyPart,
    );

    _storage.saveSession(session);
    Navigator.pop(context);
  }

  void _showCompletionDialog(WorkoutSession session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: FitnessTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusLg),
        child: Padding(
          padding: const EdgeInsets.all(FitnessTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FitnessTheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  color: FitnessTheme.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: FitnessTheme.spacingMd),
              Text('Workout Complete!', style: FitnessTheme.headingMd),
              const SizedBox(height: FitnessTheme.spacingSm),
              Text(
                'Great job finishing ${widget.workout.name}!',
                style: FitnessTheme.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FitnessTheme.spacingLg),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompletionStat(
                    Icons.timer,
                    session.formattedDuration,
                    'Duration',
                  ),
                  _buildCompletionStat(
                    Icons.local_fire_department,
                    '${session.caloriesBurned}',
                    'Calories',
                  ),
                  _buildCompletionStat(
                    Icons.check_circle,
                    '${session.exercisesCompleted}/${session.totalExercises}',
                    'Exercises',
                  ),
                ],
              ),
              const SizedBox(height: FitnessTheme.spacingLg),
              FitnessPrimaryButton(
                text: 'Done',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: FitnessTheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: FitnessTheme.titleMd),
        Text(label, style: FitnessTheme.caption),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildContent()),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Row(
        children: [
          GestureDetector(
            onTap: _abandonWorkout,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FitnessTheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: FitnessTheme.textPrimary),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.workout.name,
                  style: FitnessTheme.titleMd,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${_currentExerciseIndex + 1}/${widget.workout.exercises.length} exercises',
                  style: FitnessTheme.bodySm,
                ),
              ],
            ),
          ),
          // Progress indicator
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: widget.workout.exercises.isNotEmpty
                  ? (_currentExerciseIndex + 1) / widget.workout.exercises.length
                  : 0,
              strokeWidth: 3,
              backgroundColor: FitnessTheme.surface,
              valueColor: const AlwaysStoppedAnimation(FitnessTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case WorkoutState.countdown:
        return _buildCountdownView();
      case WorkoutState.exercise:
        return _buildExerciseView();
      case WorkoutState.rest:
        return _buildRestView();
      case WorkoutState.paused:
        return _buildPausedView();
      case WorkoutState.completed:
        return const Center(
          child: CircularProgressIndicator(color: FitnessTheme.primary),
        );
    }
  }

  Widget _buildCountdownView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('GET READY', style: FitnessTheme.headingMd),
          const SizedBox(height: FitnessTheme.spacingLg),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 + (_pulseController.value * 0.1),
                child: Text(
                  '$_remainingSeconds',
                  style: FitnessTheme.timerLarge.copyWith(
                    color: FitnessTheme.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          if (_currentExercise != null)
            Text(
              'First: ${_currentExercise!.name}',
              style: FitnessTheme.titleLg,
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseView() {
    final exercise = _currentExercise;
    final workoutExercise = _currentWorkoutExercise;
    if (exercise == null || workoutExercise == null) return const SizedBox.shrink();

    final progress = _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0.0;

    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Column(
        children: [
          // Exercise animation
          Expanded(
            flex: 3,
            child: ExerciseLottiePlayer(
              assetPath: exercise.lottieAsset,
              networkUrl: exercise.lottieUrl,
              autoPlay: true,
              loop: true,
            ),
          ),
          // Exercise info
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  exercise.name,
                  style: FitnessTheme.headingMd,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FitnessTheme.spacingMd),
                // Timer or reps
                if (exercise.type == ExerciseType.timed)
                  TimerProgressRing(
                    totalSeconds: _totalSeconds,
                    remainingSeconds: _remainingSeconds,
                    size: 150,
                  )
                else
                  Column(
                    children: [
                      Text(
                        '${workoutExercise.effectiveReps ?? 10}',
                        style: FitnessTheme.timerLarge.copyWith(
                          color: FitnessTheme.primary,
                        ),
                      ),
                      Text('REPS', style: FitnessTheme.titleMd),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestView() {
    final nextIndex = _currentExerciseIndex + 1;
    final hasNext = nextIndex < widget.workout.exercises.length;
    Exercise? nextExercise;
    
    if (hasNext) {
      final nextWorkoutExercise = widget.workout.exercises[nextIndex];
      nextExercise = _exerciseLib.getById(nextWorkoutExercise.exerciseId);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('REST', style: FitnessTheme.headingMd),
          const SizedBox(height: FitnessTheme.spacingLg),
          TimerProgressRing(
            totalSeconds: _totalSeconds,
            remainingSeconds: _remainingSeconds,
            size: 180,
            color: FitnessTheme.info,
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          if (nextExercise != null) ...[
            Text('Up Next:', style: FitnessTheme.bodySm),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(nextExercise.name, style: FitnessTheme.titleLg),
          ],
          const SizedBox(height: FitnessTheme.spacingLg),
          FitnessOutlineButton(
            text: 'Skip Rest',
            onPressed: () {
              _timer?.cancel();
              _nextExercise();
            },
            width: 150,
            height: 44,
          ),
        ],
      ),
    );
  }

  Widget _buildPausedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.pause_circle_filled,
            size: 80,
            color: FitnessTheme.primary,
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          Text('PAUSED', style: FitnessTheme.headingLg),
          const SizedBox(height: FitnessTheme.spacingSm),
          Text(
            'Tap play to continue',
            style: FitnessTheme.bodySm,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous
          WorkoutControlButton(
            icon: Icons.skip_previous_rounded,
            onPressed: _currentExerciseIndex > 0 ? _previousExercise : null,
            size: 56,
          ),
          // Play/Pause
          WorkoutControlButton(
            icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onPressed: _togglePause,
            isPrimary: true,
            size: 72,
          ),
          // Skip
          WorkoutControlButton(
            icon: Icons.skip_next_rounded,
            onPressed: _skipExercise,
            size: 56,
          ),
        ],
      ),
    );
  }
}
