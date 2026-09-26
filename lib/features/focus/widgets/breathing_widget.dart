import 'dart:async';
import '../../../core/services/haptic_service.dart';
import 'package:flutter/material.dart';
import '../../../core/design/app_design.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app/app_button.dart';
import '../models/breathing_exercise.dart';

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
    // The idle pulse is started from didChangeDependencies, where MediaQuery can
    // safely be read.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The ambient "ready" pulse behind the breathing circle repeats forever. The
    // guided breath itself (`_breathController`) is deliberately left alone: its
    // motion IS the instruction — a breathing exercise with no expanding circle
    // is not a reduced-motion version of the feature, it is the feature removed.
    // WCAG 2.2 SC 2.3.3 asks for non-essential motion to be suppressible, and
    // draws exactly this distinction.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
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
      HapticService().focusBreathing();

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

      HapticService().focusComplete();

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
            AppColorsExt.of(context).surface,
          ],
        ),
        borderRadius: AppRadius.brSheet,
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _stop();
              widget.onClose?.call();
            },
            tooltip: 'Close',
            icon: const Icon(Symbols.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: ext.surface,
              foregroundColor: ext.textSecondary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.pattern.name,
                  textAlign: TextAlign.center,
                  // `pattern.color` as text is the same trap the plant and tag
                  // hues are: a mid-tone model constant on the card. The title
                  // takes the text token and the circle below carries the hue.
                  style: tt.headlineSmall,
                ),
                Text(
                  '$_completedCycles / ${widget.targetCycles} cycles',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// The AA-verified pair for a breathing phase.
  ///
  /// `BreathingPhase.color` is a raw model constant used as a FILL with white
  /// text on top, and measured that is the same defect as the tree-shop header:
  /// white on inhale's #22C55E is **2.28:1**. Each phase maps onto a palette
  /// swatch, so the hue family survives and the countdown becomes legible.
  /// hold-after-exhale is the rest beat and has no hue — it takes the neutral.
  ({Color bg, Color fg}) _phaseColors(BreathingPhase phase) {
    final ext = AppColorsExt.of(context);
    switch (phase) {
      case BreathingPhase.inhale:
        return (bg: ext.fillBg(ext.steps), fg: ext.fillFg(ext.steps));
      case BreathingPhase.holdAfterInhale:
        return (bg: ext.fillBg(ext.info), fg: ext.fillFg(ext.info));
      case BreathingPhase.exhale:
        return (bg: ext.fillBg(ext.focus), fg: ext.fillFg(ext.focus));
      case BreathingPhase.holdAfterExhale:
        return (bg: ext.surfaceVariant, fg: ext.textPrimary);
    }
  }

  Widget _buildBreathingCircle() {
    final tt = Theme.of(context).textTheme;
    final phase = _phaseColors(_currentPhase);
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathController, _pulseController]),
        builder: (context, child) {
          final scale = _isActive
              ? _scaleAnimation.value
              : _pulseAnimation.value * 0.6;
          final diameter = 240 * scale;

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
                      color: phase.bg.withOpacity(0.3),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
              // Main circle
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: phase.bg,
                  boxShadow: AppShadows.elevated(context),
                ),
                // The disc SHRINKS to 0.6x while idle and the readout does not:
                // a 64pt count plus a 20pt instruction needs ~100pt of height
                // inside a 144pt circle at 1.0x, and at 2.0x text it is ~200pt
                // inside the same 144. scaleDown never enlarges, so the resting
                // rendering is unchanged and only the cases that would have
                // spilled shrink to fit.
                child: Center(
                  child: SizedBox(
                    // 0.707 = 1/sqrt(2): the largest square that fits a circle.
                    width: diameter * 0.707,
                    height: diameter * 0.707,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isActive ? '$_currentCount' : '',
                            maxLines: 1,
                            softWrap: false,
                            style: tt.displayLarge?.copyWith(
                              // No scale slot exists above 32 for a countdown;
                              // this keeps the display face and overrides size.
                              fontSize: 64,
                              color: phase.fg,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _isActive
                                ? _currentPhase.instruction
                                : 'Tap to start',
                            maxLines: 1,
                            softWrap: false,
                            style: tt.headlineMedium?.copyWith(color: phase.fg),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The two controls, on [AppButton].
  ///
  /// They were bare `GestureDetector`s wrapping a hand-rolled Container: no ink,
  /// no pressed state, no disabled handling, no enforced 48pt height, and a
  /// gradient fill from `pattern.color` carrying white text — 2.28:1 on the
  /// relaxing pattern's green. AppButton is the design system's answer to all
  /// of that, and `size: lg` keeps the generous 56pt target these had.
  Widget _buildControls() {
    final ext = AppColorsExt.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: AppButton(
              label: !_isActive
                  ? 'Start'
                  : _isPaused
                      ? 'Resume'
                      : 'Pause',
              leadingIcon: _isActive && !_isPaused
                  ? Symbols.pause_rounded
                  : Symbols.play_arrow_rounded,
              size: AppButtonSize.lg,
              accent: ext.focus,
              onPressed: !_isActive
                  ? _start
                  : _isPaused
                      ? _resume
                      : _pause,
            ),
          ),
          if (_isActive) ...[
            const SizedBox(width: AppSpacing.lg),
            Flexible(
              child: AppButton(
                label: 'Stop',
                leadingIcon: Symbols.stop_rounded,
                size: AppButtonSize.lg,
                variant: AppButtonVariant.secondary,
                onPressed: _stop,
              ),
            ),
          ],
        ],
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? pattern.color.withOpacity(0.15) : ext.surface,
          borderRadius: AppRadius.brCard,
          border: Border.all(
            color: isSelected ? pattern.color : ext.outline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppShadows.resting(context),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: pattern.color.withOpacity(0.2),
                borderRadius: AppRadius.brLg,
              ),
              child: Icon(pattern.icon, color: ext.mark(ext.focus), size: 24),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pattern.name, style: tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    pattern.description,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Symbols.check_circle_rounded, color: ext.mark(ext.focus)),
          ],
        ),
      ),
    );
  }
}
