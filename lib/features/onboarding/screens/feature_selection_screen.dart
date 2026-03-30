import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/services/feature_navigation_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../main.dart';
import '../../settings/screens/notification_settings_screen.dart';
import '../../settings/screens/haptic_settings_screen.dart';
import '../../settings/screens/vitavibe_settings_screen.dart';

/// Feature configuration for the selection screen
class FeatureConfig {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;

  const FeatureConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class FeatureSelectionScreen extends StatefulWidget {
  const FeatureSelectionScreen({super.key});

  @override
  State<FeatureSelectionScreen> createState() => _FeatureSelectionScreenState();
}

class _FeatureSelectionScreenState extends State<FeatureSelectionScreen>
    with TickerProviderStateMixin {
  final HapticService _hapticService = HapticService();
  final FeatureNavigationService _navService = FeatureNavigationService();

  late AnimationController _mainController;
  late AnimationController _staggerController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<FeatureConfig> allFeatures = [
    FeatureConfig(
      id: 'medicine',
      name: 'Medicine',
      subtitle: 'Track medications & reminders',
      icon: Icons.medication_rounded,
      color: Color(0xFF6366F1),
    ),
    FeatureConfig(
      id: 'water',
      name: 'Water',
      subtitle: 'Stay hydrated daily',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF06B6D4),
    ),
    FeatureConfig(
      id: 'reminders',
      name: 'Reminders',
      subtitle: 'Never miss a thing',
      icon: Icons.notifications_rounded,
      color: Color(0xFFF59E0B),
    ),
    FeatureConfig(
      id: 'focus',
      name: 'Focus',
      subtitle: 'Deep work sessions',
      icon: Icons.self_improvement_rounded,
      color: Color(0xFF8B5CF6),
    ),
    FeatureConfig(
      id: 'notes',
      name: 'Notes',
      subtitle: 'Capture your thoughts',
      icon: Icons.note_alt_rounded,
      color: Color(0xFF10B981),
    ),
    FeatureConfig(
      id: 'exam_prep',
      name: 'Exam Prep',
      subtitle: 'Study smarter',
      icon: Icons.school_rounded,
      color: Color(0xFF3B82F6),
    ),
    FeatureConfig(
      id: 'fitness',
      name: 'Fitness',
      subtitle: 'Track your workouts',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFEF4444),
    ),
    FeatureConfig(
      id: 'finance',
      name: 'Finance',
      subtitle: 'Manage expenses',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF22C55E),
    ),
    FeatureConfig(
      id: 'period',
      name: 'Luna Cycle',
      subtitle: 'Cycle tracking',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFFEC4899),
    ),
    FeatureConfig(
      id: 'mood',
      name: 'Mood',
      subtitle: 'Track emotions',
      icon: Icons.mood_rounded,
      color: Color(0xFFFF6B9D),
    ),
    FeatureConfig(
      id: 'habit',
      name: 'Habits',
      subtitle: 'Build routines',
      icon: Icons.track_changes_rounded,
      color: Color(0xFF7C91F4),
    ),
    FeatureConfig(
      id: 'fun',
      name: 'Fun & Relax',
      subtitle: 'Games & relaxation',
      icon: Icons.spa_rounded,
      color: Color(0xFF9333EA),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _initAnimations();
  }

  void _initAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ));

    _mainController.forward();
    _staggerController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _staggerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToFeature(FeatureConfig feature) {
    HapticFeedback.mediumImpact();
    _hapticService.selection();
    // Auth is now handled at welcome screen - no per-feature auth gate
    _navService.navigateToFeature(context, feature.id);
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    _showSettingsBottomSheet();
  }

  void _showSettingsBottomSheet() {
    final isDark = AppColors.isDark(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _SettingsBottomSheet(isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFC),
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(size, isDark),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Header with logo and settings
                    _buildHeader(isDark),

                    // Title section
                    _buildTitleSection(isDark),

                    // Feature Grid
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildFeatureGrid(isDark),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(Size size, bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Stack(
          children: [
            Positioned(
              top: -size.height * 0.1,
              right: -size.width * 0.2,
              child: Transform.scale(
                scale: 1.0 + pulse * 0.03,
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(isDark ? 0.15 : 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.2,
              left: -size.width * 0.15,
              child: Transform.scale(
                scale: 1.0 + (1 - pulse) * 0.03,
                child: Container(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(isDark ? 0.12 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo on the left
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, const Color(0xFF4ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 26,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dlyminder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Premium Lifestyle Suite',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Settings icon on the right
          GestureDetector(
            onTap: _openSettings,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.15),
                ),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: AppColors.getTextSecondary(context),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, const Color(0xFF4ECDC4)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text(
                  'PICK YOUR FEATURE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Title
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                isDark ? Colors.white : const Color(0xFF1A1D29),
                AppColors.primary,
              ],
            ).createShader(bounds),
            child: const Text(
              "What Would You\nLike to Track?",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'Select a feature to get started',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: allFeatures.length,
      itemBuilder: (context, index) {
        return _buildFeatureCard(allFeatures[index], index, isDark);
      },
    );
  }

  Widget _buildFeatureCard(FeatureConfig feature, int index, bool isDark) {
    final delay = index * 0.08;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animValue = Curves.easeOutBack.transform(
          ((_staggerController.value - delay) * 1.5).clamp(0.0, 1.0),
        );
        return Transform.scale(
          scale: 0.8 + (0.2 * animValue),
          child: Opacity(
            opacity: animValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _navigateToFeature(feature),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: feature.color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppColors.darkCard,
                            AppColors.darkElevatedCard,
                          ]
                        : [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.7),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? feature.color.withOpacity(0.2)
                        : feature.color.withOpacity(0.15),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [feature.color, feature.color.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: feature.color.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        feature.icon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    // Feature name
                    Text(
                      feature.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtitle
                    Text(
                      feature.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Arrow indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: feature.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: feature.color,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings bottom sheet with General settings only
class _SettingsBottomSheet extends StatefulWidget {
  final bool isDark;

  const _SettingsBottomSheet({required this.isDark});

  @override
  State<_SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<_SettingsBottomSheet> {
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.85)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, const Color(0xFF4ECDC4)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Settings list
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildThemeToggle(context, isDark),
                      const SizedBox(height: 8),
                      _buildSettingsTile(
                        context,
                        icon: Icons.notifications_outlined,
                        iconColor: AppColors.info,
                        title: 'Notifications',
                        subtitle: 'Reminder sounds and timing',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildHapticTile(context, isDark),
                      const SizedBox(height: 8),
                      _buildVitaVibeTile(context, isDark),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    final settings = CleanStorageService.getUserSettings();
    final isDarkMode = settings.darkModeEnabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          _hapticService.tap();
          final newDarkMode = !isDarkMode;
          final updated = settings.copyWith(darkModeEnabled: newDarkMode);
          await CleanStorageService.saveUserSettings(updated);
          MyApp.of(context)?.setThemeMode(
            newDarkMode ? ThemeMode.dark : ThemeMode.light,
          );
          setState(() {});
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDarkMode ? Colors.indigo : AppColors.warning).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDarkMode ? Colors.indigo : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDarkMode ? 'Dark mode enabled' : 'Light mode enabled',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDarkMode,
                onChanged: (value) async {
                  _hapticService.tap();
                  final updated = settings.copyWith(darkModeEnabled: value);
                  await CleanStorageService.saveUserSettings(updated);
                  MyApp.of(context)?.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHapticTile(BuildContext context, bool isDark) {
    return ListenableBuilder(
      listenable: _hapticService,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _hapticService.tap();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HapticSettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getCardBg(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.vibration_rounded, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haptic Feedback',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hapticService.isEnabled 
                              ? 'Enabled • ${_getIntensityLabel(_hapticService.globalIntensity)}'
                              : 'Disabled',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hapticService.isEnabled,
                    onChanged: (value) async {
                      await _hapticService.setEnabled(value);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVitaVibeTile(BuildContext context, bool isDark) {
    return ListenableBuilder(
      listenable: _vitaVibeService,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _vitaVibeService.tap();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VitaVibeSettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getCardBg(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vibration_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Haptix',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _vitaVibeService.isEnabled 
                              ? 'Advanced haptic patterns enabled'
                              : 'Advanced vibration patterns',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _vitaVibeService.isEnabled,
                    onChanged: (value) async {
                      await _vitaVibeService.setEnabled(value);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.getTextSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getIntensityLabel(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.light:
        return 'Light';
      case HapticIntensity.medium:
        return 'Medium';
      case HapticIntensity.heavy:
        return 'Strong';
      case HapticIntensity.custom:
        return 'Custom';
    }
  }
}
