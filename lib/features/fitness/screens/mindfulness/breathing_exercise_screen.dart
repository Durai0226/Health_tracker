import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/fitness_theme.dart';

/// Breathing exercise screen with visual breath guide
/// Supports Box Breathing (4-4-4-4), 4-7-8, and custom patterns
class BreathingExerciseScreen extends StatefulWidget {
  final String? sessionType;
  final String? exerciseName;
  final String? pattern;

  const BreathingExerciseScreen({
    super.key,
    this.sessionType,
    this.exerciseName,
    this.pattern,
  });

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _pulseController;
  
  Timer? _sessionTimer;
  Timer? _phaseTimer;
  
  bool _isRunning = false;
  int _currentPhase = 0; // 0: inhale, 1: hold, 2: exhale, 3: hold
  int _currentCycle = 0;
  int _secondsRemaining = 0;
  int _phaseSeconds = 0;
  
  late List<int> _phaseDurations;
  late int _totalCycles;
  late String _title;

  @override
  void initState() {
    super.initState();
    _setupExercise();
    
    _breatheController = AnimationController(
      duration: Duration(seconds: _phaseDurations[0]),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _setupExercise() {
    if (widget.pattern == '4-4-4-4') {
      // Box Breathing
      _phaseDurations = [4, 4, 4, 4];
      _totalCycles = 5;
      _title = 'Box Breathing';
    } else if (widget.pattern == '4-7-8') {
      // 4-7-8 Breathing
      _phaseDurations = [4, 7, 8, 0];
      _totalCycles = 4;
      _title = '4-7-8 Breathing';
    } else if (widget.sessionType == 'pre_workout') {
      // Pre-workout focus
      _phaseDurations = [4, 0, 6, 0];
      _totalCycles = 6;
      _title = 'Pre-Workout Focus';
    } else if (widget.sessionType == 'post_workout') {
      // Post-workout recovery
      _phaseDurations = [4, 2, 6, 2];
      _totalCycles = 8;
      _title = 'Post-Workout Recovery';
    } else if (widget.sessionType == 'sleep') {
      // Sleep meditation
      _phaseDurations = [4, 7, 8, 0];
      _totalCycles = 6;
      _title = 'Sleep Meditation';
    } else {
      // Default deep breathing
      _phaseDurations = [4, 0, 6, 0];
      _totalCycles = 5;
      _title = widget.exerciseName ?? 'Deep Breathing';
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _pulseController.dispose();
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _startExercise() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRunning = true;
      _currentPhase = 0;
      _currentCycle = 0;
      _phaseSeconds = _phaseDurations[0];
    });
    _startPhase();
  }

  void _startPhase() {
    final duration = _phaseDurations[_currentPhase];
    if (duration == 0) {
      _nextPhase();
      return;
    }

    _phaseSeconds = duration;
    _breatheController.duration = Duration(seconds: duration);
    
    if (_currentPhase == 0) {
      _breatheController.forward(from: 0);
    } else if (_currentPhase == 2) {
      _breatheController.reverse(from: 1);
    }

    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_phaseSeconds > 1) {
        setState(() => _phaseSeconds--);
      } else {
        timer.cancel();
        _nextPhase();
      }
    });
  }

  void _nextPhase() {
    HapticFeedback.selectionClick();
    
    if (_currentPhase == 3 || (_currentPhase == 2 && _phaseDurations[3] == 0)) {
      // Completed a cycle
      _currentCycle++;
      if (_currentCycle >= _totalCycles) {
        _completeExercise();
        return;
      }
      _currentPhase = 0;
    } else {
      _currentPhase++;
      // Skip phases with 0 duration
      while (_phaseDurations[_currentPhase] == 0 && _currentPhase < 3) {
        _currentPhase++;
      }
    }
    
    setState(() {});
    _startPhase();
  }

  void _completeExercise() {
    HapticFeedback.heavyImpact();
    _phaseTimer?.cancel();
    setState(() => _isRunning = false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FitnessTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: FitnessTheme.borderRadiusLg,
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: FitnessTheme.success, size: 28),
            const SizedBox(width: 12),
            Text('Well Done!', style: FitnessTheme.headingSm),
          ],
        ),
        content: Text(
          'You completed $_totalCycles cycles of $_title.\n\nTake a moment to notice how you feel.',
          style: FitnessTheme.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Done',
              style: FitnessTheme.button.copyWith(color: FitnessTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _stopExercise() {
    _phaseTimer?.cancel();
    _breatheController.stop();
    setState(() => _isRunning = false);
  }

  String get _phaseLabel {
    switch (_currentPhase) {
      case 0:
        return 'Inhale';
      case 1:
        return 'Hold';
      case 2:
        return 'Exhale';
      case 3:
        return 'Hold';
      default:
        return '';
    }
  }

  Color get _phaseColor {
    switch (_currentPhase) {
      case 0:
        return const Color(0xFF4CAF50);
      case 1:
        return const Color(0xFFFF9800);
      case 2:
        return const Color(0xFF2196F3);
      case 3:
        return const Color(0xFF9C27B0);
      default:
        return FitnessTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(_title, style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _buildBreathingCircle(),
                ),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreathingCircle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cycle counter
        if (_isRunning)
          Text(
            'Cycle ${_currentCycle + 1} of $_totalCycles',
            style: FitnessTheme.titleSm.copyWith(
              color: FitnessTheme.textSecondary,
            ),
          ),
        const SizedBox(height: FitnessTheme.spacingLg),
        
        // Breathing circle
        AnimatedBuilder(
          animation: _isRunning ? _breatheController : _pulseController,
          builder: (context, child) {
            double scale;
            if (_isRunning) {
              if (_currentPhase == 0) {
                scale = 0.6 + (_breatheController.value * 0.4);
              } else if (_currentPhase == 2) {
                scale = 1.0 - (_breatheController.value * 0.4) + 0.6;
              } else {
                scale = _currentPhase == 1 ? 1.0 : 0.6;
              }
            } else {
              scale = 0.8 + (_pulseController.value * 0.1);
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: 280 * scale,
                  height: 280 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_isRunning ? _phaseColor : FitnessTheme.primary)
                        .withValues(alpha: 0.1),
                  ),
                ),
                // Middle ring
                Container(
                  width: 220 * scale,
                  height: 220 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_isRunning ? _phaseColor : FitnessTheme.primary)
                        .withValues(alpha: 0.2),
                  ),
                ),
                // Inner circle
                Container(
                  width: 160 * scale,
                  height: 160 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (_isRunning ? _phaseColor : FitnessTheme.primary)
                            .withValues(alpha: 0.8),
                        (_isRunning ? _phaseColor : FitnessTheme.primary)
                            .withValues(alpha: 0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRunning ? _phaseColor : FitnessTheme.primary)
                            .withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isRunning
                        ? Text(
                            '$_phaseSeconds',
                            style: FitnessTheme.timerLarge.copyWith(
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.play_arrow_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
        
        const SizedBox(height: FitnessTheme.spacingLg),
        
        // Phase label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isRunning ? _phaseLabel : 'Tap to Start',
            key: ValueKey(_isRunning ? _phaseLabel : 'start'),
            style: FitnessTheme.headingMd.copyWith(
              color: _isRunning ? _phaseColor : FitnessTheme.textSecondary,
            ),
          ),
        ),
        
        if (!_isRunning) ...[
          const SizedBox(height: FitnessTheme.spacingMd),
          _buildPatternInfo(),
        ],
      ],
    );
  }

  Widget _buildPatternInfo() {
    final phases = <String>[];
    if (_phaseDurations[0] > 0) phases.add('Inhale ${_phaseDurations[0]}s');
    if (_phaseDurations[1] > 0) phases.add('Hold ${_phaseDurations[1]}s');
    if (_phaseDurations[2] > 0) phases.add('Exhale ${_phaseDurations[2]}s');
    if (_phaseDurations[3] > 0) phases.add('Hold ${_phaseDurations[3]}s');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FitnessTheme.spacingMd,
        vertical: FitnessTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: FitnessTheme.surface,
        borderRadius: FitnessTheme.borderRadiusRound,
      ),
      child: Text(
        phases.join(' → '),
        style: FitnessTheme.bodySm,
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingLg),
      child: Column(
        children: [
          if (_isRunning)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _stopExercise,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: FitnessTheme.error),
                ),
                child: Text(
                  'Stop',
                  style: FitnessTheme.button.copyWith(color: FitnessTheme.error),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startExercise,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: FitnessTheme.primary,
                ),
                child: Text(
                  'Start Exercise',
                  style: FitnessTheme.button,
                ),
              ),
            ),
          const SizedBox(height: FitnessTheme.spacingMd),
          Text(
            '$_totalCycles cycles • ~${_calculateDuration()} min',
            style: FitnessTheme.bodySm,
          ),
        ],
      ),
    );
  }

  int _calculateDuration() {
    final cycleSeconds = _phaseDurations.reduce((a, b) => a + b);
    return ((cycleSeconds * _totalCycles) / 60).ceil();
  }
}
