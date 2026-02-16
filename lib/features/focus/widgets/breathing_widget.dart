import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/breathing_exercise.dart';
import '../../../core/constants/app_colors.dart';

class BreathingWidget extends StatefulWidget {
  final BreathingPattern pattern;
  final int targetCycles;
  final VoidCallback? onComplete;
  final VoidCallback? onClose;

  const BreathingWidget({
    super.key,
    required this.pattern,
    this.targetCycles = 4,
    this.onComplete,
    this.onClose,
  });

  @override
  State<BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<BreathingWidget>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  Timer? _phaseTimer;
  BreathingPhase _currentPhase = BreathingPhase.inhale;
  int _currentCount = 0;
  int _completedCycles = 0;
  bool _isActive = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    
    _breathController = AnimationController(
      duration: Duration(seconds: widget.pattern.inhaleSeconds),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pulseController.dispose();
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _isActive = true;
      _isPaused = false;
      _currentPhase = BreathingPhase.inhale;
      _completedCycles = 0;
    });
    _runPhase();
  }

  void _pause() {
    setState(() => _isPaused = true);
    _phaseTimer?.cancel();
    _breathController.stop();
  }

  void _resume() {
    setState(() => _isPaused = false);
    _runPhase();
  }

  void _stop() {
    _phaseTimer?.cancel();
    _breathController.reset();
    setState(() {
      _isActive = false;
      _isPaused = false;
      _currentPhase = BreathingPhase.inhale;
      _completedCycles = 0;
    });
  }

  void _runPhase() {
    if (!_isActive || _isPaused) return;

    final duration = _getPhaseDuration(_currentPhase);
    if (duration == 0) {
      _nextPhase();
      return;
    }

    setState(() => _currentCount = duration);

    // Animate breathing circle
    if (_currentPhase == BreathingPhase.inhale) {
      _breathController.duration = Duration(seconds: duration);
      _breathController.forward(from: 0);
    } else if (_currentPhase == BreathingPhase.exhale) {
      _breathController.duration = Duration(seconds: duration);
      _breathController.reverse(from: 1);
    }

    // Countdown timer
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isActive || _isPaused) {
        timer.cancel();
        return;
      }

      setState(() => _currentCount--);
      HapticFeedback.selectionClick();

      if (_currentCount <= 0) {
        timer.cancel();
        _nextPhase();
      }
    });
  }

  int _getPhaseDuration(BreathingPhase phase) {
    switch (phase) {
      case BreathingPhase.inhale:
        return widget.pattern.inhaleSeconds;
      case BreathingPhase.holdAfterInhale:
        return widget.pattern.holdAfterInhaleSeconds;
      case BreathingPhase.exhale:
        return widget.pattern.exhaleSeconds;
      case BreathingPhase.holdAfterExhale:
        return widget.pattern.holdAfterExhaleSeconds;
    }
  }

  void _nextPhase() {
    if (!_isActive) return;

    switch (_currentPhase) {
      case BreathingPhase.inhale:
        if (widget.pattern.holdAfterInhaleSeconds > 0) {
          setState(() => _currentPhase = BreathingPhase.holdAfterInhale);
        } else {
          setState(() => _currentPhase = BreathingPhase.exhale);
        }
        break;
      case BreathingPhase.holdAfterInhale:
        setState(() => _currentPhase = BreathingPhase.exhale);
        break;
      case BreathingPhase.exhale:
        if (widget.pattern.holdAfterExhaleSeconds > 0) {
          setState(() => _currentPhase = BreathingPhase.holdAfterExhale);
        } else {
          _completeCycle();
        }
        break;
      case BreathingPhase.holdAfterExhale:
        _completeCycle();
        break;
    }

    if (_isActive && _completedCycles < widget.targetCycles) {
      _runPhase();
    }
  }

  void _completeCycle() {
    setState(() {
      _completedCycles++;
      _currentPhase = BreathingPhase.inhale;
    });

    HapticFeedback.mediumImpact();

    if (_completedCycles >= widget.targetCycles) {
      _isActive = false;
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.pattern.color.withOpacity(0.1),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBreathingCircle()),
            _buildControls(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _stop();
              widget.onClose?.call();
            },
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.pattern.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.pattern.color,
                  ),
                ),
                Text(
                  '$_completedCycles / ${widget.targetCycles} cycles',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBreathingCircle() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathController, _pulseController]),
        builder: (context, child) {
          final scale = _isActive
              ? _scaleAnimation.value
              : _pulseAnimation.value * 0.6;
          
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 280 * scale,
                height: 280 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _currentPhase.color.withOpacity(0.3),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
              // Main circle
              Container(
                width: 240 * scale,
                height: 240 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _currentPhase.color.withOpacity(0.8),
                      _currentPhase.color,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _currentPhase.color.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isActive ? '$_currentCount' : '',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isActive
                            ? _currentPhase.instruction
                            : 'Tap to start',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isActive)
            _buildControlButton(
              icon: Icons.play_arrow_rounded,
              label: 'Start',
              onPressed: _start,
              isPrimary: true,
            )
          else if (_isPaused)
            _buildControlButton(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              onPressed: _resume,
              isPrimary: true,
            )
          else
            _buildControlButton(
              icon: Icons.pause_rounded,
              label: 'Pause',
              onPressed: _pause,
              isPrimary: true,
            ),
          if (_isActive) ...[
            const SizedBox(width: 16),
            _buildControlButton(
              icon: Icons.stop_rounded,
              label: 'Stop',
              onPressed: _stop,
              isPrimary: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [widget.pattern.color, widget.pattern.color.withOpacity(0.8)],
                )
              : null,
          color: isPrimary ? null : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: widget.pattern.color.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BreathingPatternCard extends StatelessWidget {
  final BreathingPattern pattern;
  final bool isSelected;
  final VoidCallback? onTap;

  const BreathingPatternCard({
    super.key,
    required this.pattern,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? pattern.color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? pattern.color : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: pattern.color.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: pattern.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                pattern.icon,
                color: pattern.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pattern.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? pattern.color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pattern.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: pattern.color,
              ),
          ],
        ),
      ),
    );
  }
}
