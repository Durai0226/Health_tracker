import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/focus_session.dart';
import '../models/focus_plant.dart';
import '../services/focus_service.dart';
import '../widgets/plant_animation_widget.dart';
import '../widgets/breathing_widget.dart';
import '../models/breathing_exercise.dart';
import '../widgets/ambient_sound_widget.dart';
import '../models/ambient_sound.dart';
import 'focus_garden_screen.dart';
import 'focus_stats_screen.dart';
import 'relaxation_screen.dart';
import 'plant_real_trees_screen.dart';
import 'app_allow_list_screen.dart';
import 'custom_tags_screen.dart';
import 'detailed_stats_screen.dart';
import '../services/coins_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with TickerProviderStateMixin {
  final FocusService _focusService = FocusService();
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();
  
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _breatheController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _breatheAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _floatAnimation;
  
  bool _showBreathing = false;
  BreathingPattern? _selectedBreathingPattern;
  int _selectedQuickAction = -1;

  @override
  void initState() {
    super.initState();
    _focusService.init();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
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

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _breatheController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return ListenableBuilder(
      listenable: _focusService,
      builder: (context, _) {
        if (_showBreathing && _selectedBreathingPattern != null) {
          return Scaffold(
            body: BreathingWidget(
              pattern: _selectedBreathingPattern!,
              targetCycles: _selectedBreathingPattern!.recommendedCycles,
              onComplete: () {
                _focusService.incrementBreathingCount();
                setState(() => _showBreathing = false);
                _showCompletionSnackbar('Breathing exercise completed!');
              },
              onClose: () => setState(() => _showBreathing = false),
            ),
          );
        }
        
        return PopScope(
          canPop: !_focusService.isRunning,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _focusService.isRunning) {
              _showLeaveSessionDialog();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: Stack(
              children: [
                // Ambient background gradient
                _buildAmbientBackground(isDark),
                
                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      _buildPremiumHeader(isDark),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              _buildPremiumTimerSection(isDark),
                              const SizedBox(height: 28),
                              if (!_focusService.isRunning) ...[
                                _buildPremiumDurationSelector(isDark),
                                const SizedBox(height: 24),
                                _buildPremiumActivitySelector(isDark),
                                const SizedBox(height: 24),
                                _buildPremiumPlantSelector(isDark),
                                const SizedBox(height: 24),
                              ] else ...[
                                _buildActiveSessionCard(isDark),
                                const SizedBox(height: 24),
                              ],
                              _buildPremiumSoundSelector(isDark),
                              const SizedBox(height: 24),
                              if (!_focusService.isRunning) ...[
                                _buildPremiumBreathingSection(isDark),
                                const SizedBox(height: 24),
                                _buildPremiumRelaxationCard(isDark),
                                const SizedBox(height: 24),
                                _buildPremiumFeaturesGrid(isDark),
                              ],
                              const SizedBox(height: 24),
                              _buildPremiumQuickStats(isDark),
                              const SizedBox(height: 120),
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

  Widget _buildAmbientBackground(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5 * _breatheAnimation.value,
              colors: isDark ? [
                plantColor.withOpacity(0.15),
                plantColor.withOpacity(0.05),
                AppColors.darkBackground,
              ] : [
                plantColor.withOpacity(0.08),
                plantColor.withOpacity(0.02),
                AppColors.background,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          // Title Section with gradient text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      AppColors.getFocusAccent(context),
                      _focusService.selectedPlant.primaryColor,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'Focus Mode',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStreakBadge(isDark),
                    const SizedBox(width: 8),
                    Text(
                      _focusService.isRunning ? 'Stay focused!' : 'Ready to focus?',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action buttons
          Row(
            children: [
              _buildGlassIconButton(
                icon: Icons.spa_rounded,
                color: const Color(0xFF10B981),
                onTap: () => Navigator.push(
                  context,
                  _buildPageRoute(const RelaxationScreen()),
                ),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildGlassIconButton(
                icon: Icons.park_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () => Navigator.push(
                  context,
                  _buildPageRoute(const FocusGardenScreen()),
                ),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildGlassIconButton(
                icon: Icons.insights_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.push(
                  context,
                  _buildPageRoute(const FocusStatsScreen()),
                ),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(isDark ? 0.3 : 0.2),
            const Color(0xFFEF4444).withOpacity(isDark ? 0.3 : 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '${_focusService.stats.currentStreak}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        _hapticService.navigation();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(isDark ? 0.25 : 0.15),
                  color.withOpacity(isDark ? 0.1 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(isDark ? 0.3 : 0.2),
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  PageRoute _buildPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  Widget _buildPremiumTimerSection(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    final progress = _focusService.progress;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _focusService.isRunning ? 0 : _floatAnimation.value * 0.3),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark ? [
                    AppColors.darkCard,
                    AppColors.darkElevatedCard,
                  ] : [
                    Colors.white,
                    Colors.white.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: plantColor.withOpacity(isDark ? 0.3 : 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: plantColor.withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                    spreadRadius: -5,
                  ),
                  if (!isDark) BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Circular Timer with Plant
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress ring
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(
                          painter: _CircularProgressPainter(
                            progress: progress,
                            primaryColor: plantColor,
                            backgroundColor: plantColor.withOpacity(isDark ? 0.15 : 0.1),
                            strokeWidth: 10,
                            isAnimating: _focusService.isRunning,
                          ),
                        ),
                      ),
                      
                      // Inner glass circle with plant
                      ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  plantColor.withOpacity(isDark ? 0.15 : 0.08),
                                  plantColor.withOpacity(isDark ? 0.05 : 0.02),
                                ],
                              ),
                              border: Border.all(
                                color: plantColor.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Plant animation
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _focusService.isRunning ? 1.0 : _pulseAnimation.value,
                                      child: PlantAnimationWidget(
                                        plantType: _focusService.selectedPlant,
                                        progress: progress,
                                        isAlive: true,
                                        isAnimating: _focusService.isRunning,
                                        size: 80,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Timer display
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        plantColor,
                        plantColor.withOpacity(0.7),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      _focusService.isRunning
                          ? _focusService.formattedTime
                          : '${_focusService.selectedMinutes}:00',
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  
                  if (_focusService.isRunning) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}% completed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: plantColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Control buttons
                  _buildPremiumControlButtons(isDark, plantColor),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumControlButtons(bool isDark, Color plantColor) {
    if (!_focusService.isRunning) {
      return AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return GestureDetector(
            onTap: () {
              _hapticService.focusStart();
              _vitaVibeService.focusStart();
              _focusService.startSession();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [plantColor, plantColor.withOpacity(0.85)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: plantColor.withOpacity(0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Shimmer effect
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Transform.translate(
                        offset: Offset(_shimmerAnimation.value * 150, 0),
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Start Focus',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause/Resume button
        _buildControlCircleButton(
          icon: _focusService.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          color: plantColor,
          onTap: () {
            _hapticService.focusPause();
            _vitaVibeService.playPattern(VibePattern.doubleTap);
            if (_focusService.isPaused) {
              _focusService.resumeSession();
            } else {
              _focusService.pauseSession();
            }
          },
          isDark: isDark,
          isPrimary: true,
        ),
        const SizedBox(width: 20),
        // Abandon button
        _buildControlCircleButton(
          icon: Icons.close_rounded,
          color: AppColors.error,
          onTap: () => _showAbandonDialog(),
          isDark: isDark,
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildControlCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 18 : 14),
        decoration: BoxDecoration(
          color: isPrimary ? color : color.withOpacity(isDark ? 0.2 : 0.1),
          shape: BoxShape.circle,
          boxShadow: isPrimary ? [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ] : null,
          border: !isPrimary ? Border.all(color: color.withOpacity(0.3)) : null,
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : color,
          size: isPrimary ? 32 : 26,
        ),
      ),
    );
  }

  Widget _buildPremiumDurationSelector(bool isDark) {
    final durations = [5, 10, 15, 25, 30, 45, 60, 90];
    final plantColor = _focusService.selectedPlant.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Duration', Icons.timer_outlined, plantColor),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: durations.map((mins) {
                final isSelected = _focusService.selectedMinutes == mins;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      _hapticService.selection();
                      _focusService.setDuration(mins);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: isSelected ? LinearGradient(
                          colors: [plantColor, plantColor.withOpacity(0.85)],
                        ) : null,
                        color: isSelected ? null : (isDark ? AppColors.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? plantColor : (isDark ? AppColors.darkBorder : AppColors.divider),
                          width: isSelected ? 0 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: plantColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$mins min',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumActivitySelector(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Activity', Icons.category_outlined, plantColor),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: FocusActivityType.values.map((activity) {
                final isSelected = _focusService.selectedActivity == activity;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      _hapticService.selection();
                      _focusService.setActivity(activity);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected ? LinearGradient(
                          colors: [plantColor, plantColor.withOpacity(0.85)],
                        ) : null,
                        color: isSelected ? null : (isDark ? AppColors.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.divider),
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: plantColor.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(activity.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            activity.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlantSelector(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Choose Plant', Icons.local_florist_outlined, plantColor),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: plantColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_focusService.unlockedPlants.length}/${PlantType.values.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: plantColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: PlantType.values.length,
              itemBuilder: (context, index) {
                final plant = PlantType.values[index];
                final isUnlocked = _focusService.unlockedPlants.contains(plant);
                final isSelected = _focusService.selectedPlant == plant;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: isUnlocked ? () {
                      _hapticService.selection();
                      _focusService.setPlant(plant);
                    } : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 95,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: isSelected ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [plant.primaryColor.withOpacity(0.2), plant.primaryColor.withOpacity(0.1)],
                        ) : null,
                        color: isSelected ? null : (isDark ? AppColors.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? plant.primaryColor : (isDark ? AppColors.darkBorder : AppColors.divider),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: plant.primaryColor.withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isUnlocked ? plant.emoji : '🔒',
                            style: TextStyle(
                              fontSize: 34,
                              color: isUnlocked ? null : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            plant.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isUnlocked 
                                  ? (isSelected ? plant.primaryColor : AppColors.getTextPrimary(context))
                                  : AppColors.getTextSecondary(context),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isUnlocked)
                            Text(
                              '${plant.unlockMinutes}m',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSoundSelector(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    final sound = _focusService.selectedSound;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Ambient Sound', Icons.music_note_outlined, plantColor),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _showSoundPicker(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark ? [
                    AppColors.darkCard,
                    AppColors.darkElevatedCard,
                  ] : [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sound.color.withOpacity(isDark ? 0.3 : 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: sound.color.withOpacity(isDark ? 0.15 : 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [sound.color.withOpacity(0.2), sound.color.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(sound.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sound.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sound.category,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _focusService.toggleAudio(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [sound.color, sound.color.withOpacity(0.8)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: sound.color.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _focusService.isAudioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBreathingSection(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Breathing', Icons.air_outlined, plantColor),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: BreathingPattern.values.length,
              itemBuilder: (context, index) {
                final pattern = BreathingPattern.values[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      _hapticService.selection();
                      setState(() {
                        _selectedBreathingPattern = pattern;
                        _showBreathing = true;
                      });
                    },
                    child: Container(
                      width: 130,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            pattern.color.withOpacity(isDark ? 0.25 : 0.15),
                            pattern.color.withOpacity(isDark ? 0.1 : 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: pattern.color.withOpacity(isDark ? 0.4 : 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pattern.color.withOpacity(isDark ? 0.15 : 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: pattern.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(pattern.icon, color: pattern.color, size: 20),
                          ),
                          const Spacer(),
                          Text(
                            pattern.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: pattern.color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumRelaxationCard(bool isDark) {
    final focusColor = AppColors.getFocusAccent(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          _hapticService.navigation();
          _vitaVibeService.tap();
          Navigator.push(context, _buildPageRoute(const RelaxationScreen()));
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark ? [
                focusColor.withOpacity(0.2),
                focusColor.withOpacity(0.08),
              ] : [
                focusColor.withOpacity(0.12),
                const Color(0xFF6366F1).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: focusColor.withOpacity(isDark ? 0.35 : 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: focusColor.withOpacity(isDark ? 0.15 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [focusColor.withOpacity(0.3), focusColor.withOpacity(0.15)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('🧘', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relaxation Zone',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Binaural beats, 432Hz healing & more',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [focusColor, focusColor.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: focusColor.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumQuickStats(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark ? [
              AppColors.darkCard,
              AppColors.darkElevatedCard,
            ] : [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: plantColor.withOpacity(isDark ? 0.2 : 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSectionTitle("Today's Progress", Icons.trending_up_rounded, plantColor),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(context, _buildPageRoute(const DetailedStatsScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: plantColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: plantColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _buildPremiumStatItem(
                  icon: Icons.timer_rounded,
                  value: '${_focusService.todayMinutes}',
                  label: 'Minutes',
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildPremiumStatItem(
                  icon: Icons.local_florist_rounded,
                  value: '${_focusService.todayPlants.length}',
                  label: 'Plants',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildPremiumStatItem(
                  icon: Icons.local_fire_department_rounded,
                  value: '${_focusService.stats.currentStreak}',
                  label: 'Streak',
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(isDark ? 0.2 : 0.12), color.withOpacity(isDark ? 0.1 : 0.05)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeaturesGrid(bool isDark) {
    final coinsService = CoinsService();
    final plantColor = _focusService.selectedPlant.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('More Features', Icons.apps_rounded, plantColor),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPremiumFeatureCard(
                  emoji: '🌍',
                  title: 'Plant Trees',
                  subtitle: '${coinsService.totalCoins} coins',
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(context, _buildPageRoute(const PlantRealTreesScreen())),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPremiumFeatureCard(
                  emoji: '📊',
                  title: 'Statistics',
                  subtitle: 'Analytics',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.push(context, _buildPageRoute(const DetailedStatsScreen())),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPremiumFeatureCard(
                  emoji: '🏷️',
                  title: 'Tags',
                  subtitle: 'Organize',
                  color: const Color(0xFFEC4899),
                  onTap: () => Navigator.push(context, _buildPageRoute(const CustomTagsScreen())),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPremiumFeatureCard(
                  emoji: '📱',
                  title: 'App List',
                  subtitle: 'Focus Mode',
                  color: const Color(0xFF6366F1),
                  onTap: () => Navigator.push(context, _buildPageRoute(const AppAllowListScreen())),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        _hapticService.navigation();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(isDark ? 0.2 : 0.12),
              color.withOpacity(isDark ? 0.08 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.1 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSoundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.getModalBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getGrey300(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Ambient Sounds',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AmbientSoundSelector(
                    selectedSound: _focusService.selectedSound,
                    volume: _focusService.soundVolume,
                    onSoundChanged: (sound) {
                      _focusService.setSound(sound);
                      Navigator.pop(context);
                    },
                    onVolumeChanged: (volume) {
                      _focusService.setSoundVolume(volume);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbandonDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('🥀', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Text('Give up?'),
          ],
        ),
        content: const Text(
          'Your plant will wither if you stop now. Are you sure you want to abandon this session?',
        ),
        actions: [
          CommonButton(
            text: 'Keep Going',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CommonButton(
            text: 'Give Up',
            variant: ButtonVariant.danger,
            onPressed: () {
              Navigator.pop(context);
              _focusService.abandonSession();
              _showCompletionSnackbar('Session abandoned. Your plant has withered 🥀');
            },
          ),
        ],
      ),
    );
  }

  void _showLeaveSessionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.warning, size: 28),
            SizedBox(width: 12),
            Text('Session Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _focusService.selectedPlant.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your focus session is still running! Leaving now will kill your plant.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Time remaining: ${_focusService.formattedTime}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          CommonButton(
            text: 'Stay Focused',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CommonButton(
            text: 'Abandon & Leave',
            variant: ButtonVariant.danger,
            onPressed: () {
              Navigator.pop(context);
              _focusService.abandonSession();
              _showCompletionSnackbar('Session abandoned. Your plant has withered 🥀');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLockedSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warning.withOpacity(0.1),
            AppColors.success.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.lock_rounded,
                color: AppColors.warning,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Locked',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Stay focused! Your plant is growing...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSessionInfoItem(
                  icon: Icons.self_improvement_rounded,
                  label: 'Activity',
                  value: _focusService.selectedActivity.name,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSessionInfoItem(
                  icon: Icons.local_florist_rounded,
                  label: 'Plant',
                  value: _focusService.selectedPlant.name,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (_focusService.isPaused) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle_rounded, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Session Paused - Tap play to resume',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildActiveSessionCard(bool isDark) {
    final plantColor = _focusService.selectedPlant.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              plantColor.withOpacity(isDark ? 0.2 : 0.12),
              AppColors.success.withOpacity(isDark ? 0.15 : 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: plantColor.withOpacity(isDark ? 0.35 : 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: plantColor.withOpacity(isDark ? 0.15 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: plantColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.lock_rounded, color: plantColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stay focused! Your plant is growing...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_focusService.isPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_circle_rounded, color: AppColors.warning, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Paused',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActiveSessionInfoItem(
                    emoji: _focusService.selectedActivity.emoji,
                    label: 'Activity',
                    value: _focusService.selectedActivity.name,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActiveSessionInfoItem(
                    emoji: _focusService.selectedPlant.emoji,
                    label: 'Plant',
                    value: _focusService.selectedPlant.name,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionInfoItem({
    required String emoji,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color backgroundColor;
  final double strokeWidth;
  final bool isAnimating;

  _CircularProgressPainter({
    required this.progress,
    required this.primaryColor,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            primaryColor.withOpacity(0.6),
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
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

      // Glow effect at progress end
      if (isAnimating) {
        final glowAngle = -math.pi / 2 + 2 * math.pi * progress;
        final glowX = center.dx + radius * math.cos(glowAngle);
        final glowY = center.dy + radius * math.sin(glowAngle);
        
        final glowPaint = Paint()
          ..color = primaryColor.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        
        canvas.drawCircle(Offset(glowX, glowY), strokeWidth / 2 + 4, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isAnimating != isAnimating;
  }
}
