import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/breathing_exercise.dart';
import '../widgets/breathing_ball_widget.dart';
import '../../theme/mood_theme.dart';

/// Full-screen breathing session matching Behance design
/// Shows animated fluffy ball with breathing states
class BloomBreathSessionScreen extends StatefulWidget {
  final BreathingExercise exercise;

  const BloomBreathSessionScreen({
    super.key,
    required this.exercise,
  });

  @override
  State<BloomBreathSessionScreen> createState() => _BloomBreathSessionScreenState();
}

class _BloomBreathSessionScreenState extends State<BloomBreathSessionScreen>
    with TickerProviderStateMixin {
  // Session state
  BreathingPhase _currentPhase = BreathingPhase.idle;
  bool _isRunning = false;
  bool _isPaused = false;
  int _completedCycles = 0;
  int _elapsedSeconds = 0;
  double _phaseProgress = 0.0;
  
  // Timers
  Timer? _sessionTimer;
  Timer? _phaseTimer;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    // Auto-start after a brief delay
    Future.delayed(const Duration(milliseconds: 500), _startSession);
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _startSession() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _elapsedSeconds = 0;
      _completedCycles = 0;
    });

    // Start session timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
        });

        // Check if session is complete
        final totalDuration = widget.exercise.durationMinutes * 60;
        if (_elapsedSeconds >= totalDuration) {
          _completeSession();
        }
      }
    });

    // Start breathing cycle
    _startBreathingCycle();
  }

  void _startBreathingCycle() {
    final pattern = widget.exercise.pattern;
    
    // Phase sequence: Inhale -> Hold (if any) -> Exhale -> repeat
    _runPhase(BreathingPhase.inhale, pattern.inhaleDuration, () {
      if (pattern.holdDuration > 0) {
        _runPhase(BreathingPhase.hold, pattern.holdDuration, () {
          _runPhase(BreathingPhase.exhale, pattern.exhaleDuration, () {
            if (_isRunning && !_isPaused) {
              setState(() => _completedCycles++);
              _startBreathingCycle();
            }
          });
        });
      } else {
        _runPhase(BreathingPhase.exhale, pattern.exhaleDuration, () {
          if (_isRunning && !_isPaused) {
            setState(() => _completedCycles++);
            _startBreathingCycle();
          }
        });
      }
    });
  }

  void _runPhase(BreathingPhase phase, int durationSeconds, VoidCallback onComplete) {
    if (!_isRunning) return;

    setState(() {
      _currentPhase = phase;
      _phaseProgress = 0.0;
    });

    HapticFeedback.lightImpact();

    int elapsed = 0;
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isPaused) return;

      elapsed += 50;
      final progress = elapsed / (durationSeconds * 1000);

      if (progress >= 1.0) {
        timer.cancel();
        setState(() => _phaseProgress = 1.0);
        onComplete();
      } else {
        setState(() => _phaseProgress = progress);
      }
    });
  }

  void _togglePause() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _restartSession() {
    HapticFeedback.mediumImpact();
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    _startSession();
  }

  void _completeSession() {
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    
    setState(() {
      _isRunning = false;
      _currentPhase = BreathingPhase.idle;
    });

    HapticFeedback.heavyImpact();
    
    // Show completion dialog
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: MoodTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: MoodTheme.borderRadiusLg,
        ),
        title: Column(
          children: [
            const Text('🧘', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Session Complete',
              style: MoodTheme.headingSm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You completed $_completedCycles breathing cycles',
              style: MoodTheme.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_elapsedSeconds),
              style: MoodTheme.titleLg.copyWith(
                color: MoodTheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Done',
              style: MoodTheme.button.copyWith(
                color: MoodTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closeSession() {
    HapticFeedback.mediumImpact();
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    Navigator.of(context).pop();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color get _backgroundColor {
    switch (widget.exercise.colorScheme) {
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Main content
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Breathing ball
                        BreathingBallWidget(
                          phase: _currentPhase,
                          colorScheme: widget.exercise.colorScheme,
                          size: 280,
                          progress: _phaseProgress,
                        ),

                        const SizedBox(height: 48),

                        // Phase label
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _currentPhase.label,
                            key: ValueKey(_currentPhase),
                            style: MoodTheme.headingMd.copyWith(
                              color: MoodTheme.textPrimary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Progress bar
                        BreathingProgressBar(
                          progress: _phaseProgress,
                          colorScheme: widget.exercise.colorScheme,
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  _buildControls(),

                  // Footer info
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          GestureDetector(
            onTap: _closeSession,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: MoodTheme.textPrimary,
                size: 20,
              ),
            ),
          ),

          // Exercise name
          Text(
            widget.exercise.name,
            style: MoodTheme.titleLg.copyWith(
              color: MoodTheme.textPrimary,
            ),
          ),

          // Spacer for symmetry
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MoodTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Restart button
          _buildControlButton(
            icon: Icons.refresh_rounded,
            onTap: _restartSession,
          ),
          const SizedBox(width: 32),

          // Play/Pause button
          _buildControlButton(
            icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onTap: _togglePause,
            isPrimary: true,
          ),
          const SizedBox(width: 32),

          // Sound button (placeholder)
          _buildControlButton(
            icon: Icons.volume_up_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Toggle sound
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isPrimary ? 56 : 44,
        height: isPrimary ? 56 : 44,
        decoration: BoxDecoration(
          color: isPrimary 
              ? MoodTheme.textPrimary 
              : Colors.white.withOpacity(0.8),
          shape: BoxShape.circle,
          boxShadow: isPrimary ? MoodTheme.softShadow : null,
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : MoodTheme.textPrimary,
          size: isPrimary ? 28 : 22,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.air_rounded,
            size: 14,
            color: MoodTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            widget.exercise.patternLabel,
            style: MoodTheme.caption.copyWith(
              color: MoodTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.schedule_rounded,
            size: 14,
            color: MoodTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            widget.exercise.durationLabel,
            style: MoodTheme.caption.copyWith(
              color: MoodTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
