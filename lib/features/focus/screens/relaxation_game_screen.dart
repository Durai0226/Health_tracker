import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/relaxation_game_models.dart';
import '../services/relaxation_game_service.dart';
import '../widgets/relaxation_game_widgets.dart';
import 'experience_mode_screens.dart';

class RelaxationGameScreen extends StatefulWidget {
  const RelaxationGameScreen({super.key});

  @override
  State<RelaxationGameScreen> createState() => _RelaxationGameScreenState();
}

class _RelaxationGameScreenState extends State<RelaxationGameScreen>
    with TickerProviderStateMixin {
  final RelaxationGameService _service = RelaxationGameService();
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _service.init();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final theme = _service.settings.theme;
        
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: theme == RelaxationTheme.pearlMinimal
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: theme.backgroundColor,
            body: AnimatedGradientBackground(
              theme: theme,
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    children: [
                      _buildHeader(theme),
                      _buildTabBar(theme),
                      Expanded(
                        child: _buildTabContent(theme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(RelaxationTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: GlassmorphicContainer(
              blur: 10,
              opacity: 0.1,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.arrow_back_rounded,
                color: theme.textColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relaxation Experience',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  _service.isSessionActive
                      ? 'Session: ${_service.formattedSessionTime}'
                      : 'Choose your experience',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showSettingsSheet(theme),
            child: GlassmorphicContainer(
              blur: 10,
              opacity: 0.1,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.tune_rounded,
                color: theme.primaryColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showThemeSheet(theme),
            child: GlassmorphicContainer(
              blur: 10,
              opacity: 0.1,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.palette_rounded,
                color: theme.secondaryColor,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(RelaxationTheme theme) {
    final tabs = ['Experiences', 'Therapy', 'Play'];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GlassmorphicContainer(
        blur: 15,
        opacity: 0.08,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTab == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tabs[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? theme.primaryColor : theme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent(RelaxationTheme theme) {
    switch (_selectedTab) {
      case 0:
        return _buildExperiencesTab(theme);
      case 1:
        return _buildTherapyTab(theme);
      case 2:
        return _buildPlayTab(theme);
      default:
        return _buildExperiencesTab(theme);
    }
  }

  Widget _buildExperiencesTab(RelaxationTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Exclusive Experiences', theme),
          const SizedBox(height: 16),
          _buildExperienceGrid(theme),
          const SizedBox(height: 32),
          _buildProEliteSection(theme),
          const SizedBox(height: 32),
          _buildQuickStats(theme),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, RelaxationTheme theme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceGrid(RelaxationTheme theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: ExperienceMode.values.length,
      itemBuilder: (context, index) {
        final mode = ExperienceMode.values[index];
        final isUnlocked = _service.isModeUnlocked(mode);
        final minutesToUnlock = _service.getMinutesToUnlock(mode);
        
        return ModeSelectionCard(
          title: mode.name,
          emoji: mode.emoji,
          description: mode.description,
          color: mode.primaryColor,
          isSelected: _service.currentMode == mode,
          isLocked: !isUnlocked,
          minutesToUnlock: minutesToUnlock > 0 ? minutesToUnlock : null,
          onTap: () {
            _service.triggerTapHaptic();
            _service.setExperienceMode(mode);
            _navigateToExperience(mode);
          },
        );
      },
    );
  }

  void _navigateToExperience(ExperienceMode mode) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return ExperienceModeScreen(mode: mode);
        },
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
  }

  Widget _buildProEliteSection(RelaxationTheme theme) {
    final isUnlocked = _service.settings.proEliteUnlocked;
    final totalMinutes = _service.settings.totalMinutesUsed;
    final streak = _service.settings.currentStreak;
    final mastered = _service.settings.masteredModes.length;

    return GlassmorphicContainer(
      blur: 15,
      opacity: 0.1,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUnlocked
                        ? [const Color(0xFFD4AF37), const Color(0xFFFACC15)]
                        : [Colors.grey, Colors.grey.shade600],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isUnlocked ? Icons.workspace_premium : Icons.lock_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro Elite Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked
                            ? const Color(0xFFD4AF37)
                            : theme.textColor,
                      ),
                    ),
                    Text(
                      isUnlocked
                          ? 'All premium features unlocked!'
                          : 'Unlock advanced experiences',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isUnlocked) ...[
            const SizedBox(height: 20),
            _buildUnlockProgress(
              'Total Usage',
              totalMinutes / 300,
              '$totalMinutes / 300 min',
              Icons.timer_rounded,
              theme,
            ),
            const SizedBox(height: 12),
            _buildUnlockProgress(
              '7-Day Streak',
              streak / 7,
              '$streak / 7 days',
              Icons.local_fire_department_rounded,
              theme,
            ),
            const SizedBox(height: 12),
            _buildUnlockProgress(
              'Modes Mastered',
              mastered / 3,
              '$mastered / 3 modes',
              Icons.star_rounded,
              theme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnlockProgress(
    String label,
    double progress,
    String value,
    IconData icon,
    RelaxationTheme theme,
  ) {
    return Row(
      children: [
        Icon(icon, color: theme.primaryColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: theme.primaryColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(RelaxationTheme theme) {
    return GlassmorphicContainer(
      blur: 15,
      opacity: 0.1,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Journey',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                Icons.timer_rounded,
                '${_service.settings.totalMinutesUsed}',
                'Minutes',
                theme.primaryColor,
                theme,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.local_fire_department_rounded,
                '${_service.settings.currentStreak}',
                'Streak',
                const Color(0xFFF59E0B),
                theme,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                Icons.stars_rounded,
                '${_service.settings.masteredModes.length}',
                'Mastered',
                const Color(0xFF8B5CF6),
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
    RelaxationTheme theme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
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
              style: TextStyle(
                fontSize: 11,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapyTab(RelaxationTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Haptic Therapy Modes', theme),
          const SizedBox(height: 8),
          Text(
            'Advanced vibration patterns designed for stress relief and relaxation',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ...HapticTherapyMode.values.map((mode) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTherapyModeCard(mode, theme),
          )),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTherapyModeCard(HapticTherapyMode mode, RelaxationTheme theme) {
    final isSelected = _service.currentTherapyMode == mode;
    
    return GestureDetector(
      onTap: () {
        _service.triggerTapHaptic();
        _service.setTherapyMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [mode.color.withOpacity(0.2), mode.color.withOpacity(0.1)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? mode.color : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: mode.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(mode.icon, color: mode.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        mode.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mode.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? mode.color : theme.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              GestureDetector(
                onTap: () {
                  _service.triggerTapHaptic();
                  _runTherapyMode(mode);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: mode.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _runTherapyMode(HapticTherapyMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TherapySessionSheet(
        mode: mode,
        service: _service,
      ),
    );
  }

  Widget _buildPlayTab(RelaxationTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Interactive Play Modes', theme),
          const SizedBox(height: 8),
          Text(
            'Satisfying interactive experiences with premium haptic feedback',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: PlayMode.values.length,
            itemBuilder: (context, index) {
              final mode = PlayMode.values[index];
              return _buildPlayModeCard(mode, theme);
            },
          ),
          const SizedBox(height: 24),
          _buildElementSelector(theme),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPlayModeCard(PlayMode mode, RelaxationTheme theme) {
    final isSelected = _service.currentPlayMode == mode;
    
    return GestureDetector(
      onTap: () {
        _service.triggerTapHaptic();
        _service.setPlayMode(mode);
        _navigateToPlayMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [mode.color, mode.color.withOpacity(0.7)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? mode.color : Colors.white.withOpacity(0.15),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: mode.color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : mode.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                mode.icon,
                color: isSelected ? Colors.white : mode.color,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              mode.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              mode.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : theme.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mode.description,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : theme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPlayMode(PlayMode mode) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return PlayModeScreen(mode: mode);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildElementSelector(RelaxationTheme theme) {
    return GlassmorphicContainer(
      blur: 15,
      opacity: 0.1,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Energy Orb Elements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Each element has unique haptic texture',
            style: TextStyle(
              fontSize: 12,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: OrbElement.values.map((element) {
              final isSelected = _service.currentElement == element;
              return GestureDetector(
                onTap: () {
                  _service.setElement(element);
                  _service.triggerElementHaptic(element);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? element.color
                        : element.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: element.color,
                      width: isSelected ? 0 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(element.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        element.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : element.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(RelaxationTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsSheet(service: _service),
    );
  }

  void _showThemeSheet(RelaxationTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ThemeSelectionSheet(service: _service),
    );
  }
}

/// Settings bottom sheet
class SettingsSheet extends StatelessWidget {
  final RelaxationGameService service;

  const SettingsSheet({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final theme = service.settings.theme;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Customization',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Haptic Settings', theme),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                'Haptic Feedback',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: service.settings.hapticEnabled,
                                onChanged: service.setHapticEnabled,
                                activeThumbColor: theme.primaryColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Haptic Intensity',
                            icon: Icons.vibration_rounded,
                            value: service.settings.hapticIntensity,
                            color: theme.primaryColor,
                            onChanged: service.setHapticIntensity,
                          ),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Pattern Speed',
                            icon: Icons.speed_rounded,
                            value: service.settings.hapticSpeed,
                            color: theme.primaryColor,
                            onChanged: service.setHapticSpeed,
                          ),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Visual Settings', theme),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Particle Density',
                            icon: Icons.blur_on_rounded,
                            value: service.settings.particleDensity,
                            color: theme.secondaryColor,
                            onChanged: service.setParticleDensity,
                          ),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Animation Speed',
                            icon: Icons.animation_rounded,
                            value: service.settings.animationSpeed,
                            color: theme.secondaryColor,
                            onChanged: service.setAnimationSpeed,
                          ),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Glow Intensity',
                            icon: Icons.light_mode_rounded,
                            value: service.settings.glowIntensity,
                            color: theme.secondaryColor,
                            onChanged: service.setGlowIntensity,
                          ),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Blur Intensity',
                            icon: Icons.blur_circular_rounded,
                            value: service.settings.blurIntensity,
                            color: theme.secondaryColor,
                            onChanged: service.setBlurIntensity,
                          ),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Motion Sensitivity',
                            icon: Icons.motion_photos_auto_rounded,
                            value: service.settings.motionSensitivity,
                            color: theme.secondaryColor,
                            onChanged: service.setMotionSensitivity,
                          ),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Sound Settings', theme),
                          const SizedBox(height: 16),
                          SettingsSlider(
                            label: 'Volume',
                            icon: Icons.volume_up_rounded,
                            value: service.settings.soundVolume,
                            color: const Color(0xFF10B981),
                            onChanged: service.setSoundVolume,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.sync_rounded,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sync Sound with Haptics',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: service.settings.soundHapticSync,
                                onChanged: service.setSoundHapticSync,
                                activeThumbColor: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, RelaxationTheme theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: theme.textSecondary,
        letterSpacing: 1,
      ),
    );
  }
}

/// Theme selection sheet
class ThemeSelectionSheet extends StatelessWidget {
  final RelaxationGameService service;

  const ThemeSelectionSheet({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final currentTheme = service.settings.theme;
        
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: currentTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Theme Selection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: currentTheme.textColor,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: RelaxationTheme.values.map((theme) {
                  final isSelected = currentTheme == theme;
                  return GestureDetector(
                    onTap: () {
                      service.setTheme(theme);
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: theme.gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.primaryColor.withOpacity(0.4),
                                  blurRadius: 15,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            theme.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            theme.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

/// Therapy session sheet
class TherapySessionSheet extends StatefulWidget {
  final HapticTherapyMode mode;
  final RelaxationGameService service;

  const TherapySessionSheet({
    super.key,
    required this.mode,
    required this.service,
  });

  @override
  State<TherapySessionSheet> createState() => _TherapySessionSheetState();
}

class _TherapySessionSheetState extends State<TherapySessionSheet> {
  bool _isRunning = false;

  @override
  void dispose() {
    widget.service.stopTherapyLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.mode.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            widget.mode.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.mode.color,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.mode.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => _isRunning = !_isRunning);
              if (_isRunning) {
                widget.service.startTherapyLoop(widget.mode);
              } else {
                widget.service.stopTherapyLoop();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRunning
                      ? [widget.mode.color, widget.mode.color.withOpacity(0.7)]
                      : [Colors.grey, Colors.grey.shade600],
                ),
                boxShadow: _isRunning
                    ? [
                        BoxShadow(
                          color: widget.mode.color.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRunning ? 'Tap to stop' : 'Tap to start',
            style: TextStyle(
              fontSize: 14,
              color: theme.textSecondary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
