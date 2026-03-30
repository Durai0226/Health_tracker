import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../models/fitness_profile.dart';
import '../models/exercise.dart';
import '../services/fitness_storage_service.dart';
import 'fitness_reminder_screen.dart';

class FitnessSettingsScreen extends StatefulWidget {
  const FitnessSettingsScreen({super.key});

  @override
  State<FitnessSettingsScreen> createState() => _FitnessSettingsScreenState();
}

class _FitnessSettingsScreenState extends State<FitnessSettingsScreen> {
  final FitnessStorageService _storage = FitnessStorageService();
  FitnessProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _storage.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_profile != null) {
      await _storage.saveProfile(_profile!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved'),
            backgroundColor: FitnessTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusSm),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: const Text('Settings', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FitnessTheme.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReminderSection(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildWorkoutPreferences(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildSoundSettings(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildGoals(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildFitnessLevel(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildDangerZone(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reminders', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FitnessReminderScreen()),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitnessTheme.primary.withOpacity(0.2),
                  borderRadius: FitnessTheme.borderRadiusSm,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: FitnessTheme.primary,
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workout Reminders', style: FitnessTheme.titleMd),
                    Text(
                      'Set up daily workout reminders',
                      style: FitnessTheme.bodySm,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: FitnessTheme.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workout Preferences', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          child: Column(
            children: [
              _buildSliderSetting(
                'Rest Duration',
                'Time between exercises',
                _profile?.restBetweenExercisesSeconds ?? 30,
                10,
                60,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(
                      restBetweenExercisesSeconds: value.toInt(),
                    );
                  });
                },
                suffix: 's',
              ),
              const Divider(color: FitnessTheme.surface, height: 24),
              _buildSliderSetting(
                'Countdown',
                'Seconds before exercise starts',
                _profile?.countdownSeconds ?? 3,
                3,
                10,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(
                      countdownSeconds: value.toInt(),
                    );
                  });
                },
                suffix: 's',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSetting(
    String title,
    String subtitle,
    int value,
    int min,
    int max,
    Function(double) onChanged, {
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FitnessTheme.titleSm),
                Text(subtitle, style: FitnessTheme.caption),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FitnessTheme.spacingSm,
                vertical: FitnessTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: FitnessTheme.primary.withOpacity(0.2),
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Text(
                '$value${suffix ?? ''}',
                style: FitnessTheme.titleSm.copyWith(
                  color: FitnessTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: FitnessTheme.primary,
            inactiveTrackColor: FitnessTheme.surface,
            thumbColor: FitnessTheme.primary,
            overlayColor: FitnessTheme.primary.withOpacity(0.2),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
            onChangeEnd: (_) => _saveProfile(),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sound & Feedback', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          child: Column(
            children: [
              _buildSwitchSetting(
                'Sound Effects',
                'Play sounds during workout',
                Icons.volume_up_outlined,
                _profile?.soundEnabled ?? true,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(soundEnabled: value);
                  });
                  _saveProfile();
                },
              ),
              const Divider(color: FitnessTheme.surface, height: 24),
              _buildSwitchSetting(
                'Vibration',
                'Haptic feedback during workout',
                Icons.vibration,
                _profile?.vibrationEnabled ?? true,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(vibrationEnabled: value);
                  });
                  _saveProfile();
                },
              ),
              const Divider(color: FitnessTheme.surface, height: 24),
              _buildSwitchSetting(
                'Voice Guidance',
                'Voice instructions for exercises',
                Icons.record_voice_over_outlined,
                _profile?.voiceGuidanceEnabled ?? true,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(voiceGuidanceEnabled: value);
                  });
                  _saveProfile();
                },
              ),
              const Divider(color: FitnessTheme.surface, height: 24),
              _buildSwitchSetting(
                'Exercise Tips',
                'Show tips during exercises',
                Icons.lightbulb_outline,
                _profile?.showExerciseTips ?? true,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(showExerciseTips: value);
                  });
                  _saveProfile();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FitnessTheme.surface,
            borderRadius: FitnessTheme.borderRadiusSm,
          ),
          child: Icon(icon, color: FitnessTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: FitnessTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FitnessTheme.titleSm),
              Text(subtitle, style: FitnessTheme.caption),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: FitnessTheme.primary,
        ),
      ],
    );
  }

  Widget _buildGoals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly Goals', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          child: Column(
            children: [
              _buildSliderSetting(
                'Workouts per Week',
                'Your weekly workout target',
                _profile?.weeklyWorkoutTarget ?? 3,
                1,
                7,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(
                      weeklyWorkoutTarget: value.toInt(),
                    );
                  });
                },
              ),
              const Divider(color: FitnessTheme.surface, height: 24),
              _buildSliderSetting(
                'Daily Calorie Goal',
                'Calories to burn per workout',
                _profile?.dailyCalorieTarget ?? 300,
                100,
                1000,
                (value) {
                  setState(() {
                    _profile = _profile?.copyWith(
                      dailyCalorieTarget: value.toInt(),
                    );
                  });
                },
                suffix: ' cal',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFitnessLevel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fitness Level', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          child: Column(
            children: FitnessLevel.values.map((level) {
              final isSelected = _profile?.fitnessLevel == level;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _profile = _profile?.copyWith(fitnessLevel: level);
                  });
                  _saveProfile();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: FitnessTheme.spacingSm),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? FitnessTheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? FitnessTheme.primary
                                : FitnessTheme.textMuted,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: FitnessTheme.textOnPrimary,
                              )
                            : null,
                      ),
                      const SizedBox(width: FitnessTheme.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(level.displayName, style: FitnessTheme.titleSm),
                            Text(level.description, style: FitnessTheme.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          backgroundColor: FitnessTheme.error.withOpacity(0.1),
          borderColor: FitnessTheme.error.withOpacity(0.3),
          child: Column(
            children: [
              GestureDetector(
                onTap: _showClearDataDialog,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FitnessTheme.error.withOpacity(0.2),
                        borderRadius: FitnessTheme.borderRadiusSm,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: FitnessTheme.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: FitnessTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clear All Data',
                            style: FitnessTheme.titleSm.copyWith(
                              color: FitnessTheme.error,
                            ),
                          ),
                          Text(
                            'Delete all workout history and settings',
                            style: FitnessTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FitnessTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusLg),
        title: Text('Clear All Data?', style: FitnessTheme.headingSm),
        content: Text(
          'This will delete all your workout history, custom workouts, and settings. This action cannot be undone.',
          style: FitnessTheme.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: FitnessTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storage.clearAllData();
              await _loadProfile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Data cleared'),
                    backgroundColor: FitnessTheme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: FitnessTheme.borderRadiusSm,
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Clear',
              style: TextStyle(color: FitnessTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
