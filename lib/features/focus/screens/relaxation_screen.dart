import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../models/relaxation_music.dart';
import '../services/relaxation_service.dart';

class RelaxationScreen extends StatefulWidget {
  const RelaxationScreen({super.key});

  @override
  State<RelaxationScreen> createState() => _RelaxationScreenState();
}

class _RelaxationScreenState extends State<RelaxationScreen> with TickerProviderStateMixin {
  final RelaxationService _relaxationService = RelaxationService();
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _relaxationService.init();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _relaxationService,
      builder: (context, _) {
        if (_relaxationService.isRunning) {
          return _buildLockedSessionScreen();
        }
        return _buildSelectionScreen();
      },
    );
  }

  Widget _buildSelectionScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildCategorySelector(),
                    const SizedBox(height: 24),
                    _buildMusicList(),
                    const SizedBox(height: 24),
                    _buildDurationSelector(),
                    const SizedBox(height: 24),
                    if (_relaxationService.selectedMusic != null)
                      _buildStartButton(),
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relaxation',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Select music & set your session',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Goal',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: RelaxationCategory.values.length,
            itemBuilder: (context, index) {
              final category = RelaxationCategory.values[index];
              final isSelected = _relaxationService.selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      _hapticService.tap();
                      _vitaVibeService.tap();
                      _relaxationService.setCategory(category);
                    },
                    borderRadius: BorderRadius.circular(20),
                    splashColor: category.color.withOpacity(0.3),
                    highlightColor: category.color.withOpacity(0.15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 130,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  category.color,
                                  category.color.withOpacity(0.8),
                                ],
                              )
                            : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? category.color : Colors.grey.shade200,
                          width: isSelected ? 0 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: category.color.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const Spacer(),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category.description,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected 
                                  ? Colors.white.withOpacity(0.8) 
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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

  Widget _buildMusicList() {
    final tracks = _relaxationService.selectedCategory.tracks;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Music',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${tracks.length} tracks',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isSelected = _relaxationService.selectedMusic == track;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    _hapticService.selectionClick();
                    _relaxationService.setMusic(track);
                  },
                  borderRadius: BorderRadius.circular(16),
                  splashColor: track.color.withOpacity(0.2),
                  highlightColor: track.color.withOpacity(0.1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? track.color.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? track.color : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: track.color.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: track.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              track.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? track.color : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track.description,
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
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: track.color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    final durations = [5, 10, 15, 20, 30, 45, 60];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session Duration',
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
            final isSelected = _relaxationService.selectedMinutes == mins;
            final color = _relaxationService.selectedCategory.color;
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  _hapticService.selectionClick();
                  _relaxationService.setDuration(mins);
                },
                borderRadius: BorderRadius.circular(16),
                splashColor: color.withOpacity(0.3),
                highlightColor: color.withOpacity(0.15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade200,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.3),
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
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    final music = _relaxationService.selectedMusic!;
    final category = _relaxationService.selectedCategory;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: () {
                _hapticService.success();
                _vitaVibeService.playPattern(VibePattern.meditationBell);
                _relaxationService.startSession();
              },
              borderRadius: BorderRadius.circular(24),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      category.color,
                      category.color.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: category.color.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Start ${_relaxationService.selectedMinutes} min Session',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${music.emoji} ${music.name}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    final stats = _relaxationService.stats;
    final color = _relaxationService.selectedCategory.color;
    
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
            'Your Relaxation Journey',
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
                value: '${stats.totalMinutes}',
                label: 'Minutes',
                color: color,
              ),
              const SizedBox(width: 12),
              _buildStatItem(
                icon: Icons.spa_rounded,
                value: '${stats.completedSessions}',
                label: 'Sessions',
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildStatItem(
                icon: Icons.trending_up_rounded,
                value: '${(stats.completionRate * 100).toInt()}%',
                label: 'Completion',
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
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
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

  // LOCKED SESSION SCREEN
  Widget _buildLockedSessionScreen() {
    final music = _relaxationService.selectedMusic!;
    final category = _relaxationService.selectedCategory;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showAbandonDialog();
        }
      },
      child: Scaffold(
        backgroundColor: category.color.withOpacity(0.05),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildLockedHeader(category),
                const Spacer(),
                _buildTimerDisplay(category),
                const Spacer(),
                _buildMusicInfo(music, category),
                const SizedBox(height: 40),
                _buildControlButtons(category),
                const SizedBox(height: 20),
                _buildAbandonButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedHeader(RelaxationCategory category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: category.color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_rounded,
            color: category.color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'Session Locked',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(RelaxationCategory category) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Column(
          children: [
            // Animated breathing circle
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    category.color.withOpacity(0.2),
                    category.color.withOpacity(0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: category.color.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: category.color.withOpacity(0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _relaxationService.formattedTime,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: category.color,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _relaxationService.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(category.color),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_relaxationService.progress * 100).toInt()}% complete',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMusicInfo(RelaxationMusicType music, RelaxationCategory category) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: music.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    music.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      music.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: category.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Volume indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      color: category.color,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(_relaxationService.volume * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: category.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Volume slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: category.color,
              inactiveTrackColor: category.color.withOpacity(0.2),
              thumbColor: category.color,
              overlayColor: category.color.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _relaxationService.volume,
              onChanged: (value) {
                _relaxationService.setVolume(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(RelaxationCategory category) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause/Resume button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (_relaxationService.isPaused) {
              _relaxationService.resumeSession();
            } else {
              _relaxationService.pauseSession();
            }
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: category.color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _relaxationService.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              color: category.color,
              size: 40,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbandonButton() {
    return GestureDetector(
      onTap: () => _showAbandonDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Abandon Session',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbandonDialog() {
    final category = _relaxationService.selectedCategory;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Text('End Session?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your relaxation session is still in progress. Are you sure you want to end it now?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_rounded, color: category.color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Time remaining: ${_relaxationService.formattedTime}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: category.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: category.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _relaxationService.abandonSession();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Session ended'),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}
