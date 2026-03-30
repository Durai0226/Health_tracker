import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/auth_service.dart';
import '../../theme/fitness_theme.dart';
import '../../models/fitness_profile.dart';
import '../../services/fitness_storage_service.dart';
import '../fitness_main_screen.dart';

/// Fitness onboarding flow with modern animated UI
/// Steps: Gender → Equipment → Fitness Level → Goals → Schedule
class FitnessOnboardingScreen extends StatefulWidget {
  final bool isEditMode;
  
  const FitnessOnboardingScreen({super.key, this.isEditMode = false});

  @override
  State<FitnessOnboardingScreen> createState() => _FitnessOnboardingScreenState();
}

class _FitnessOnboardingScreenState extends State<FitnessOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final FitnessStorageService _storageService = FitnessStorageService();
  final AuthService _authService = AuthService();
  int _currentStep = 0;
  
  // Onboarding data
  Gender? _selectedGender;
  EquipmentPreference _selectedEquipment = EquipmentPreference.none;
  FitnessLevel _selectedLevel = FitnessLevel.beginner;
  FitnessGoal _selectedGoal = FitnessGoal.stayFit;
  int _workoutsPerWeek = 3;
  int _workoutDuration = 30;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _stepTitles = [
    'What\'s your gender?',
    'Equipment access?',
    'Fitness level?',
    'What\'s your goal?',
    'Weekly schedule?',
  ];

  final List<String> _stepSubtitles = [
    'This helps personalize your workout recommendations',
    'We\'ll tailor exercises based on what you have',
    'Be honest - we\'ll build you up gradually',
    'Your primary fitness objective',
    'How often can you commit to working out?',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    
    // Load existing profile values in edit mode
    if (widget.isEditMode) {
      _loadExistingProfile();
    }
  }
  
  Future<void> _loadExistingProfile() async {
    final profile = await _storageService.getProfile();
    if (mounted && profile.hasCompletedOnboarding) {
      setState(() {
        _selectedGender = profile.gender;
        _selectedEquipment = profile.equipmentPreference;
        _selectedLevel = profile.fitnessLevel;
        _selectedGoal = profile.fitnessGoal;
        _workoutsPerWeek = profile.weeklyWorkoutTarget;
        _workoutDuration = (profile.dailyCalorieTarget / 10).round().clamp(15, 90);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      HapticFeedback.lightImpact();
      _fadeController.reverse().then((_) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        _fadeController.forward();
      });
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _fadeController.reverse().then((_) {
        setState(() => _currentStep--);
        _pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        _fadeController.forward();
      });
    }
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    
    // Save profile for ALL users (guests and logged-in)
    // Profile is stored locally via SharedPreferences
    final profile = FitnessProfile(
      id: _authService.currentUser?.id ?? 'local_user',
      gender: _selectedGender,
      equipmentPreference: _selectedEquipment,
      fitnessLevel: _selectedLevel,
      fitnessGoal: _selectedGoal,
      weeklyWorkoutTarget: _workoutsPerWeek,
      dailyCalorieTarget: _workoutDuration * 10,
      hasCompletedOnboarding: true,
      createdAt: DateTime.now(),
    );
    await _storageService.saveProfile(profile);
    
    if (!mounted) return;
    
    // In edit mode, just pop back; otherwise replace with main screen
    if (widget.isEditMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FitnessMainScreen()),
      );
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedGender != null;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildGenderStep(),
                    _buildEquipmentStep(),
                    _buildLevelStep(),
                    _buildGoalStep(),
                    _buildScheduleStep(),
                  ],
                ),
              ),
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Column(
        children: [
          // Progress indicator
          Row(
            children: List.generate(5, (index) {
              final isActive = index <= _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? FitnessTheme.primary
                        : FitnessTheme.surface,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: FitnessTheme.primary.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          // Title and subtitle
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  _stepTitles[_currentStep],
                  style: FitnessTheme.headingLg,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FitnessTheme.spacingSm),
                Text(
                  _stepSubtitles[_currentStep],
                  style: FitnessTheme.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: _GenderCard(
                    gender: Gender.male,
                    isSelected: _selectedGender == Gender.male,
                    onTap: () => setState(() => _selectedGender = Gender.male),
                  ),
                ),
                const SizedBox(width: FitnessTheme.spacingMd),
                Expanded(
                  child: _GenderCard(
                    gender: Gender.female,
                    isSelected: _selectedGender == Gender.female,
                    onTap: () => setState(() => _selectedGender = Gender.female),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            _buildOptionChip(
              'Prefer not to say',
              _selectedGender == Gender.other,
              () => setState(() => _selectedGender = Gender.other),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: EquipmentPreference.values.map((equipment) {
            return Padding(
              padding: const EdgeInsets.only(bottom: FitnessTheme.spacingMd),
              child: _EquipmentCard(
                equipment: equipment,
                isSelected: _selectedEquipment == equipment,
                onTap: () => setState(() => _selectedEquipment = equipment),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLevelStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: FitnessLevel.values.map((level) {
            return Padding(
              padding: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
              child: _LevelCard(
                level: level,
                isSelected: _selectedLevel == level,
                onTap: () => setState(() => _selectedLevel = level),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGoalStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: FitnessTheme.spacingMd,
          crossAxisSpacing: FitnessTheme.spacingMd,
          shrinkWrap: true,
          children: FitnessGoal.values.map((goal) {
            return _GoalCard(
              goal: goal,
              isSelected: _selectedGoal == goal,
              onTap: () => setState(() => _selectedGoal = goal),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScheduleStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Workouts per week
            _buildScheduleSection(
              'Workouts per week',
              _workoutsPerWeek,
              1,
              7,
              (value) => setState(() => _workoutsPerWeek = value),
            ),
            const SizedBox(height: FitnessTheme.spacingXl),
            // Workout duration
            _buildDurationSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: FitnessTheme.cardDecoration,
      child: Column(
        children: [
          Text(label, style: FitnessTheme.titleMd),
          const SizedBox(height: FitnessTheme.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCircleButton(
                Icons.remove,
                value > min,
                () => onChanged(value - 1),
              ),
              const SizedBox(width: FitnessTheme.spacingLg),
              Text(
                '$value',
                style: FitnessTheme.headingXl.copyWith(
                  color: FitnessTheme.primary,
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingLg),
              _buildCircleButton(
                Icons.add,
                value < max,
                () => onChanged(value + 1),
              ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingSm),
          Text(
            'days',
            style: FitnessTheme.bodySm,
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSection() {
    final durations = [15, 30, 45, 60];
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: FitnessTheme.cardDecoration,
      child: Column(
        children: [
          Text('Workout duration', style: FitnessTheme.titleMd),
          const SizedBox(height: FitnessTheme.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: durations.map((duration) {
              final isSelected = _workoutDuration == duration;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _workoutDuration = duration);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: FitnessTheme.spacingMd,
                    vertical: FitnessTheme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FitnessTheme.primary
                        : FitnessTheme.surface,
                    borderRadius: FitnessTheme.borderRadiusMd,
                    border: Border.all(
                      color: isSelected
                          ? FitnessTheme.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${duration}m',
                    style: FitnessTheme.titleSm.copyWith(
                      color: isSelected
                          ? FitnessTheme.textOnPrimary
                          : FitnessTheme.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? FitnessTheme.surface : FitnessTheme.surface.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? FitnessTheme.primary : FitnessTheme.textMuted,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? FitnessTheme.primary : FitnessTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildOptionChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? FitnessTheme.primary.withValues(alpha: 0.2) : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusRound,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: FitnessTheme.bodyMd.copyWith(
            color: isSelected ? FitnessTheme.primary : FitnessTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: FitnessTheme.textMuted),
                ),
                child: Text(
                  'Back',
                  style: FitnessTheme.button.copyWith(
                    color: FitnessTheme.textSecondary,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: FitnessTheme.spacingMd),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: _canProceed ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _canProceed
                      ? FitnessTheme.primary
                      : FitnessTheme.surface,
                ),
                child: Text(
                  _currentStep == 4 ? 'Let\'s Go!' : 'Continue',
                  style: FitnessTheme.button.copyWith(
                    color: _canProceed
                        ? FitnessTheme.textOnPrimary
                        : FitnessTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Gender selection card
class _GenderCard extends StatelessWidget {
  final Gender gender;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.gender,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = gender == Gender.male ? Icons.male : Icons.female;
    final color = gender == Gender.male
        ? const Color(0xFF4FC3F7)
        : const Color(0xFFFF8A80);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(FitnessTheme.spacingLg),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusLg,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(FitnessTheme.spacingMd),
              decoration: BoxDecoration(
                color: isSelected ? color : FitnessTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: isSelected ? Colors.white : FitnessTheme.textSecondary,
              ),
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text(
              gender.displayName,
              style: FitnessTheme.titleMd.copyWith(
                color: isSelected ? color : FitnessTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Equipment selection card
class _EquipmentCard extends StatelessWidget {
  final EquipmentPreference equipment;
  final bool isSelected;
  final VoidCallback onTap;

  const _EquipmentCard({
    required this.equipment,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (equipment) {
      case EquipmentPreference.none:
        return Icons.accessibility_new;
      case EquipmentPreference.minimal:
        return Icons.fitness_center;
      case EquipmentPreference.full:
        return Icons.sports_gymnastics;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          color: isSelected
              ? FitnessTheme.primary.withValues(alpha: 0.15)
              : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? FitnessTheme.primary
                    : FitnessTheme.surfaceLight,
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Icon(
                _icon,
                color: isSelected ? FitnessTheme.textOnPrimary : FitnessTheme.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipment.displayName,
                    style: FitnessTheme.titleMd.copyWith(
                      color: isSelected
                          ? FitnessTheme.primary
                          : FitnessTheme.textPrimary,
                    ),
                  ),
                  Text(
                    equipment.description,
                    style: FitnessTheme.bodySm,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: FitnessTheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// Fitness level card
class _LevelCard extends StatelessWidget {
  final FitnessLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          color: isSelected
              ? FitnessTheme.primary.withValues(alpha: 0.15)
              : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.displayName,
                    style: FitnessTheme.titleMd.copyWith(
                      color: isSelected
                          ? FitnessTheme.primary
                          : FitnessTheme.textPrimary,
                    ),
                  ),
                  Text(
                    level.description,
                    style: FitnessTheme.bodySm,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: FitnessTheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// Goal selection card
class _GoalCard extends StatelessWidget {
  final FitnessGoal goal;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FitnessTheme.primary.withValues(alpha: 0.2),
                    FitnessTheme.primary.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isSelected ? null : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              goal.emoji,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              goal.displayName,
              style: FitnessTheme.titleSm.copyWith(
                color: isSelected
                    ? FitnessTheme.primary
                    : FitnessTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
