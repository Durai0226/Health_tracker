import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/services/haptic_service.dart';
import '../theme/manrope_theme.dart';
import '../models/meditation_activity.dart';
import '../models/ambient_sound.dart';
import '../services/manrope_wellness_service.dart';
import '../widgets/breathing_widget.dart';
import '../models/breathing_exercise.dart';

class ManropeActivityScreen extends StatefulWidget {
  final WellnessActivityType activityType;

  const ManropeActivityScreen({
    super.key,
    required this.activityType,
  });

  @override
  State<ManropeActivityScreen> createState() => _ManropeActivityScreenState();
}

class _ManropeActivityScreenState extends State<ManropeActivityScreen>
    with TickerProviderStateMixin {
  final ManropeWellnessService _wellnessService = ManropeWellnessService();
  final HapticService _hapticService = HapticService();

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _breatheController;
  late AnimationController _shimmerController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _breatheAnimation;
  late Animation<double> _shimmerAnimation;

  bool _showBreathing = false;
  BreathingPattern? _selectedBreathingPattern;

  @override
  void initState() {
    super.initState();
    _wellnessService.setSelectedActivity(widget.activityType);
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _breatheController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _breatheAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
    _breatheController.repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _breatheController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ManropeTheme.isDark(context);
    final activity = widget.activityType;

    return ListenableBuilder(
      listenable: _wellnessService,
      builder: (context, _) {
        if (_showBreathing && _selectedBreathingPattern != null) {
          return Scaffold(
            body: BreathingWidget(
              pattern: _selectedBreathingPattern!,
              targetCycles: _selectedBreathingPattern!.recommendedCycles,
              onComplete: () {
                setState(() => _showBreathing = false);
                _showCompletionSnackbar('Breathing exercise completed!');
              },
              onClose: () => setState(() => _showBreathing = false),
            ),
          );
        }

        return PopScope(
          canPop: !_wellnessService.isRunning,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _wellnessService.isRunning) {
              _showLeaveSessionDialog();
            }
          },
          child: Scaffold(
            backgroundColor: isDark
                ? ManropeTheme.backgroundDark
                : ManropeTheme.background,
            body: Stack(
              children: [
                _buildAmbientBackground(isDark, activity),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(isDark, activity),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              _buildTimerSection(isDark, activity),
                              const SizedBox(height: 32),
                              if (!_wellnessService.isRunning) ...[
                                _buildDurationSelector(isDark, activity),
                                const SizedBox(height: 24),
                                if (activity.supportsAmbientSound)
                                  _buildSoundSelector(isDark),
                                if (activity.supportsBreathingGuide) ...[
                                  const SizedBox(height: 24),
                                  _buildBreathingSection(isDark),
                                ],
                              ],
                              const SizedBox(height: 32),
                              _buildActionButton(isDark, activity),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmbientBackground(bool isDark, WellnessActivityType activity) {
    final color = activity.primaryColor;
    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5 * _breatheAnimation.value,
              colors: isDark
                  ? [
                      color.withOpacity(0.15),
                      color.withOpacity(0.05),
                      ManropeTheme.backgroundDark,
                    ]
                  : [
                      color.withOpacity(0.1),
                      color.withOpacity(0.03),
                      ManropeTheme.background,
                    ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, WellnessActivityType activity) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_wellnessService.isRunning) {
                _showLeaveSessionDialog();
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(
              Symbols.arrow_back_rounded,
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.displayName,
                  style: ManropeTheme.titleLarge.copyWith(
                    color: isDark
                        ? ManropeTheme.textPrimaryDark
                        : ManropeTheme.textPrimary,
                  ),
                ),
                Text(
                  _wellnessService.isRunning
                      ? 'Session in progress'
                      : 'Ready to start',
                  style: ManropeTheme.bodySmall.copyWith(
                    color: isDark
                        ? ManropeTheme.textTertiaryDark
                        : ManropeTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: activity.gradient,
              borderRadius: ManropeTheme.borderRadiusMedium,
            ),
            child: Icon(
              activity.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(bool isDark, WellnessActivityType activity) {
    final progress = _wellnessService.progress;
    final color = activity.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _wellnessService.isRunning ? 1.0 : _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? ManropeTheme.backgroundDarkCard
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: _CircularProgressPainter(
                        progress: progress,
                        primaryColor: color,
                        backgroundColor: color.withOpacity(0.1),
                        strokeWidth: 12,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activity.icon,
                        size: 48,
                        color: color,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _wellnessService.isRunning
                            ? _wellnessService.formattedTime
                            : '${_wellnessService.selectedMinutes}:00',
                        style: ManropeTheme.displaySmall.copyWith(
                          color: isDark
                              ? ManropeTheme.textPrimaryDark
                              : ManropeTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _wellnessService.isRunning
                            ? 'remaining'
                            : 'minutes',
                        style: ManropeTheme.bodyMedium.copyWith(
                          color: isDark
                              ? ManropeTheme.textTertiaryDark
                              : ManropeTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDurationSelector(bool isDark, WellnessActivityType activity) {
    final durations = activity.suggestedDurations;
    final selectedDuration = _wellnessService.selectedMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Duration',
            style: ManropeTheme.titleSmall.copyWith(
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: durations.length,
            itemBuilder: (context, index) {
              final duration = durations[index];
              final isSelected = duration == selectedDuration;

              return GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  _wellnessService.setSelectedDuration(duration);
                },
                child: AnimatedContainer(
                  duration: ManropeTheme.durationFast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? activity.gradient : null,
                    color: isSelected
                        ? null
                        : (isDark
                            ? ManropeTheme.backgroundDarkCard
                            : Colors.white),
                    borderRadius: ManropeTheme.borderRadiusRound,
                    boxShadow: isSelected
                        ? ManropeTheme.shadowColored(activity.primaryColor)
                        : ManropeTheme.shadowSmall,
                  ),
                  child: Text(
                    '$duration min',
                    style: ManropeTheme.labelLarge.copyWith(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? ManropeTheme.textPrimaryDark
                              : ManropeTheme.textPrimary),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSelector(bool isDark) {
    final sounds = AmbientSoundType.values;
    final selectedSound = _wellnessService.selectedSound;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Ambient Sound',
            style: ManropeTheme.titleSmall.copyWith(
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sounds.length,
            itemBuilder: (context, index) {
              final sound = sounds[index];
              final isSelected = sound == selectedSound;

              return GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  _wellnessService.setSelectedSound(sound);
                },
                child: AnimatedContainer(
                  duration: ManropeTheme.durationFast,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(12),
                  width: 80,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.activityType.primaryColor.withOpacity(0.15)
                        : (isDark
                            ? ManropeTheme.backgroundDarkCard
                            : Colors.white),
                    borderRadius: ManropeTheme.borderRadiusLarge,
                    border: isSelected
                        ? Border.all(
                            color: widget.activityType.primaryColor,
                            width: 2,
                          )
                        : null,
                    boxShadow: ManropeTheme.shadowSmall,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        sound.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sound.name,
                        style: ManropeTheme.labelSmall.copyWith(
                          color: isDark
                              ? ManropeTheme.textSecondaryDark
                              : ManropeTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBreathingSection(bool isDark) {
    final patterns = BreathingPattern.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Breathing Exercises',
            style: ManropeTheme.titleSmall.copyWith(
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: patterns.length,
            itemBuilder: (context, index) {
              final pattern = patterns[index];

              return GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  setState(() {
                    _selectedBreathingPattern = pattern;
                    _showBreathing = true;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(16),
                  width: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ManropeTheme.calmTeal.withOpacity(0.8),
                        ManropeTheme.calmTealLight,
                      ],
                    ),
                    borderRadius: ManropeTheme.borderRadiusLarge,
                    boxShadow: ManropeTheme.shadowMedium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Symbols.air_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pattern.name,
                            style: ManropeTheme.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${pattern.totalCycleDuration}s cycle',
                            style: ManropeTheme.labelSmall.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(bool isDark, WellnessActivityType activity) {
    final isRunning = _wellnessService.isRunning;
    final isPaused = _wellnessService.isPaused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return GestureDetector(
                onTap: () {
                  _hapticService.medium();
                  if (isRunning) {
                    if (isPaused) {
                      _wellnessService.resumeSession();
                    } else {
                      _wellnessService.pauseSession();
                    }
                  } else {
                    _wellnessService.startSession();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: activity.gradient,
                    borderRadius: ManropeTheme.borderRadiusXLarge,
                    boxShadow: ManropeTheme.shadowColored(activity.primaryColor),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isRunning)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: ManropeTheme.borderRadiusXLarge,
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  begin: Alignment(_shimmerAnimation.value - 1, 0),
                                  end: Alignment(_shimmerAnimation.value, 0),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcATop,
                              child: Container(color: Colors.white),
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isRunning
                                ? (isPaused
                                    ? Symbols.play_arrow_rounded
                                    : Symbols.pause_rounded)
                                : Symbols.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRunning
                                ? (isPaused ? 'Resume' : 'Pause')
                                : 'Start Session',
                            style: ManropeTheme.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (isRunning) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _showAbandonDialog(),
              child: Text(
                'Abandon Session',
                style: ManropeTheme.labelLarge.copyWith(
                  color: ManropeTheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLeaveSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session?'),
        content: const Text(
          'You have an active session. Are you sure you want to leave? Your progress will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _wellnessService.abandonSession();
              Navigator.pop(context);
            },
            child: Text(
              'Leave',
              style: TextStyle(color: ManropeTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbandonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Session?'),
        content: const Text(
          'Are you sure you want to abandon this session? Your partial progress will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _wellnessService.abandonSession();
            },
            child: Text(
              'Abandon',
              style: TextStyle(color: ManropeTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ManropeTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: ManropeTheme.borderRadiusMedium,
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.primaryColor,
    required this.backgroundColor,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );

      // Glow effect
      final glowPaint = Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor;
  }
}
