import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../focus/models/relaxation_game_models.dart';
import '../../focus/services/relaxation_game_service.dart';
import '../../focus/widgets/relaxation_game_widgets.dart';
import '../../focus/screens/experience_mode_screens.dart';

class FunRelaxDashboard extends StatefulWidget {
  const FunRelaxDashboard({super.key});

  @override
  State<FunRelaxDashboard> createState() => _FunRelaxDashboardState();
}

class _FunRelaxDashboardState extends State<FunRelaxDashboard>
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
                Row(
                  children: [
                    Text(
                      'Fun & Relax',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                 
                  ],
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
          _buildSectionTitle('Visual Experiences', theme),
          const SizedBox(height: 16),
          _buildExperienceGrid(theme),
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

        return ModeSelectionCard(
          title: mode.name,
          emoji: mode.emoji,
          description: mode.description,
          color: mode.primaryColor,
          isSelected: _service.currentMode == mode,
          isLocked: false,
          minutesToUnlock: null,
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

/// Therapy Session Sheet
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
          Icon(widget.mode.icon, color: widget.mode.color, size: 64),
          const SizedBox(height: 16),
          Text(
            widget.mode.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            widget.mode.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
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
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [widget.mode.color, widget.mode.color.withOpacity(0.7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.mode.color.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRunning ? 'Tap to pause' : 'Tap to start',
            style: TextStyle(
              fontSize: 14,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.service.stopTherapyLoop();
    super.dispose();
  }
}

/// Settings Sheet
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
                                onChanged: (v) => service.setHapticEnabled(v),
                                activeColor: theme.primaryColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSlider(
                            'Haptic Intensity',
                            service.settings.hapticIntensity,
                            (v) => service.setHapticIntensity(v),
                            theme,
                          ),
                          const SizedBox(height: 16),
                          _buildSlider(
                            'Haptic Speed',
                            service.settings.hapticSpeed,
                            (v) => service.setHapticSpeed(v),
                            theme,
                          ),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Visual Settings', theme),
                          const SizedBox(height: 16),
                          _buildSlider(
                            'Particle Density',
                            service.settings.particleDensity,
                            (v) => service.setParticleDensity(v),
                            theme,
                          ),
                          const SizedBox(height: 16),
                          _buildSlider(
                            'Animation Speed',
                            service.settings.animationSpeed,
                            (v) => service.setAnimationSpeed(v),
                            theme,
                          ),
                          const SizedBox(height: 16),
                          _buildSlider(
                            'Glow Intensity',
                            service.settings.glowIntensity,
                            (v) => service.setGlowIntensity(v),
                            theme,
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
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: theme.primaryColor,
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
    RelaxationTheme theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: theme.textColor),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: theme.primaryColor,
            inactiveTrackColor: theme.primaryColor.withOpacity(0.2),
            thumbColor: theme.primaryColor,
            overlayColor: theme.primaryColor.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Theme Selection Sheet
class ThemeSelectionSheet extends StatelessWidget {
  final RelaxationGameService service;

  const ThemeSelectionSheet({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final currentTheme = service.settings.theme;

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: currentTheme.surfaceColor,
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
            'Choose Theme',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: currentTheme.textColor,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: RelaxationTheme.values.length,
              itemBuilder: (context, index) {
                final theme = RelaxationTheme.values[index];
                final isSelected = currentTheme == theme;

                return GestureDetector(
                  onTap: () {
                    service.setTheme(theme);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: theme.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: theme.primaryColor, width: 3)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          theme.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
}
