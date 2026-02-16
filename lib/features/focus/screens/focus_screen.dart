import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../models/focus_plant.dart';
import '../models/focus_session.dart';
import '../models/breathing_exercise.dart';
import '../services/focus_service.dart';
import '../widgets/plant_animation_widget.dart';
import '../widgets/breathing_widget.dart';
import '../widgets/ambient_sound_widget.dart';
import 'focus_garden_screen.dart';
import 'focus_stats_screen.dart';
import 'relaxation_screen.dart';
import 'relaxation_game_screen.dart';
import 'plant_real_trees_screen.dart';
import 'app_allow_list_screen.dart';
import 'custom_tags_screen.dart';
import 'detailed_stats_screen.dart';
import 'leaderboard_screen.dart';
import 'group_focus_screen.dart';
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
  late Animation<double> _pulseAnimation;
  bool _showBreathing = false;
  BreathingPattern? _selectedBreathingPattern;

  @override
  void initState() {
    super.initState();
    _focusService.init();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildTimerSection(),
                          const SizedBox(height: 24),
                          if (!_focusService.isRunning) ...[
                            _buildDurationSelector(),
                            const SizedBox(height: 20),
                            _buildActivitySelector(),
                            const SizedBox(height: 20),
                            _buildPlantSelector(),
                            const SizedBox(height: 20),
                          ] else ...[
                            // Show locked session info when running
                            _buildLockedSessionInfo(),
                            const SizedBox(height: 20),
                          ],
                          _buildSoundSelector(),
                          const SizedBox(height: 20),
                          if (!_focusService.isRunning) ...[
                            _buildBreathingSection(),
                            const SizedBox(height: 20),
                            _buildRelaxationCard(),
                            const SizedBox(height: 16),
                            _buildPremiumRelaxationGameCard(),
                            const SizedBox(height: 24),
                            _buildNewFeaturesSection(),
                          ],
                          const SizedBox(height: 24),
                          _buildQuickStats(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Mode',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _focusService.isRunning ? 'Stay focused!' : 'Ready to focus?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          _buildHeaderButton(
            icon: Icons.spa_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RelaxationScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _buildHeaderButton(
            icon: Icons.park_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FocusGardenScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _buildHeaderButton(
            icon: Icons.bar_chart_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FocusStatsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Widget _buildTimerSection() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _focusService.isRunning ? 1.0 : _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _focusService.selectedPlant.primaryColor.withOpacity(0.1),
                  _focusService.selectedPlant.secondaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: _focusService.selectedPlant.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                // Plant animation
                PlantAnimationWidget(
                  plantType: _focusService.selectedPlant,
                  progress: _focusService.progress,
                  isAlive: true,
                  isAnimating: _focusService.isRunning,
                  size: 180,
                ),
                const SizedBox(height: 16),
                
                // Timer display
                Text(
                  _focusService.isRunning
                      ? _focusService.formattedTime
                      : '${_focusService.selectedMinutes}:00',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: _focusService.selectedPlant.primaryColor,
                    letterSpacing: 2,
                  ),
                ),
                
                // Progress bar
                if (_focusService.isRunning) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _focusService.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        _focusService.selectedPlant.primaryColor,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Control buttons
                _buildControlButtons(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    if (!_focusService.isRunning) {
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
              colors: [
                _focusService.selectedPlant.primaryColor,
                _focusService.selectedPlant.primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _focusService.selectedPlant.primaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                'Start Focus',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause/Resume button
        GestureDetector(
          onTap: () {
            _hapticService.focusPause();
            _vitaVibeService.playPattern(VibePattern.doubleTap);
            if (_focusService.isPaused) {
              _focusService.resumeSession();
            } else {
              _focusService.pauseSession();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _focusService.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: _focusService.selectedPlant.primaryColor,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Abandon button
        GestureDetector(
          onTap: () => _showAbandonDialog(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    final durations = [5, 10, 15, 25, 30, 45, 60, 90];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: durations.map((mins) {
            final isSelected = _focusService.selectedMinutes == mins;
            return GestureDetector(
              onTap: () => _focusService.setDuration(mins),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '$mins min',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActivitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: FocusActivityType.values.map((activity) {
              final isSelected = _focusService.selectedActivity == activity;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _focusService.setActivity(activity),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(activity.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          activity.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
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
    );
  }

  Widget _buildPlantSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Choose Your Plant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${_focusService.unlockedPlants.length}/${PlantType.values.length} unlocked',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: PlantType.values.length,
            itemBuilder: (context, index) {
              final plant = PlantType.values[index];
              final isUnlocked = _focusService.unlockedPlants.contains(plant);
              final isSelected = _focusService.selectedPlant == plant;
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 90,
                  child: PlantGridItem(
                    type: plant,
                    isUnlocked: isUnlocked,
                    isSelected: isSelected,
                    unlockMinutes: isUnlocked ? null : plant.unlockMinutes,
                    onTap: () => _focusService.setPlant(plant),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ambient Sound',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        AmbientSoundMiniPlayer(
          sound: _focusService.selectedSound,
          isPlaying: _focusService.isAudioPlaying,
          volume: _focusService.soundVolume,
          onToggle: () => _focusService.toggleAudio(),
          onTap: () => _showSoundPicker(),
        ),
      ],
    );
  }

  Widget _buildBreathingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Breathing Exercises',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: BreathingPattern.values.length,
            itemBuilder: (context, index) {
              final pattern = BreathingPattern.values[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBreathingPattern = pattern;
                      _showBreathing = true;
                    });
                  },
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pattern.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: pattern.color.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(pattern.icon, color: pattern.color, size: 24),
                        const Spacer(),
                        Text(
                          pattern.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildRelaxationCard() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          _hapticService.navigation();
          _vitaVibeService.tap();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const RelaxationScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        splashColor: const Color(0xFF8B5CF6).withOpacity(0.2),
        highlightColor: const Color(0xFF8B5CF6).withOpacity(0.1),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B5CF6).withOpacity(0.1),
                const Color(0xFF6366F1).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text('🧘', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relaxation & Deep Focus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Binaural beats, 432Hz healing, nature sounds & more',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumRelaxationGameCard() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          _hapticService.navigation();
          _vitaVibeService.tap();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const RelaxationGameScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                    ),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        splashColor: const Color(0xFFD4AF37).withOpacity(0.2),
        highlightColor: const Color(0xFFD4AF37).withOpacity(0.1),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF0D0221),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD4AF37),
                      Color(0xFFFACC15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('✨', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Premium Relaxation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFD4AF37),
                                Color(0xFFFACC15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Haptic therapy, visual experiences, bubble pop & more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD4AF37),
                      Color(0xFFFACC15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.timer_rounded,
                value: '${_focusService.todayMinutes}',
                label: 'Minutes',
                color: AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                icon: Icons.local_florist_rounded,
                value: '${_focusService.todayPlants.length}',
                label: 'Plants',
                color: AppColors.success,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                icon: Icons.local_fire_department_rounded,
                value: '${_focusService.stats.currentStreak}',
                label: 'Streak',
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewFeaturesSection() {
    final coinsService = CoinsService();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More Features',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                emoji: '🌍',
                title: 'Plant Real Trees',
                subtitle: '${coinsService.totalCoins} coins',
                color: const Color(0xFF4CAF50),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlantRealTreesScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                emoji: '👥',
                title: 'Plant Together',
                subtitle: 'Group Focus',
                color: const Color(0xFF2196F3),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupFocusScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                emoji: '🏆',
                title: 'Leaderboards',
                subtitle: 'Compete & Compare',
                color: const Color(0xFFFF9800),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                emoji: '📊',
                title: 'Detailed Stats',
                subtitle: 'Daily/Weekly/Monthly',
                color: const Color(0xFF9C27B0),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DetailedStatsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                emoji: '🏷️',
                title: 'Custom Tags',
                subtitle: 'Organize Sessions',
                color: const Color(0xFFE91E63),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomTagsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                emoji: '📱',
                title: 'App Allow List',
                subtitle: 'Focus Settings',
                color: const Color(0xFF607D8B),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppAllowListScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        _hapticService.navigation();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ambient Sounds',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _focusService.abandonSession();
              _showCompletionSnackbar('Session abandoned. Your plant has withered 🥀');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Give Up'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Stay Focused',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _focusService.abandonSession();
              _showCompletionSnackbar('Session abandoned. Your plant has withered 🥀');
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Abandon & Leave'),
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
}
