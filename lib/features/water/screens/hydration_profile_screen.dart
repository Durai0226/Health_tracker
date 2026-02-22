import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/hydration_profile.dart';
import '../services/water_service.dart';

/// Hydration Profile Screen - Calculate personalized water goal
class HydrationProfileScreen extends StatefulWidget {
  const HydrationProfileScreen({super.key});

  @override
  State<HydrationProfileScreen> createState() => _HydrationProfileScreenState();
}

class _HydrationProfileScreenState extends State<HydrationProfileScreen> {
  late HydrationProfile _profile;
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profile = WaterService.getProfile();
    _weightController.text = _profile.weightKg?.toString() ?? '';
    _ageController.text = _profile.age?.toString() ?? '';
  }

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final weight = double.tryParse(_weightController.text);
      final age = int.tryParse(_ageController.text);

      final updated = _profile.copyWith(
        weightKg: weight,
        age: age,
        updatedAt: DateTime.now(),
      );

      await WaterService.saveProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Daily goal updated to ${updated.effectiveGoalMl}ml'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Hydration Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoalCard(),
            const SizedBox(height: 24),
            _buildPersonalInfo(),
            const SizedBox(height: 24),
            _buildActivityLevel(),
            const SizedBox(height: 24),
            _buildClimate(),
            const SizedBox(height: 24),
            _buildSpecialConditions(),
            const SizedBox(height: 24),
            _buildCustomGoal(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.info, AppColors.info.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.water_drop, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            _profile.useCustomGoal ? 'Custom Goal' : 'Recommended Goal',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_profile.effectiveGoalMl}ml',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${(_profile.effectiveGoalMl / 250).round()} glasses per day',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          if (!_profile.useCustomGoal && _profile.weightKg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Based on your profile',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return _buildSection(
      title: 'Personal Information',
      icon: Icons.person_outline,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Weight (kg)',
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final weight = double.tryParse(value);
                    setState(() {
                      _profile = _profile.copyWith(weightKg: weight);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Age',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final age = int.tryParse(value);
                    setState(() {
                      _profile = _profile.copyWith(age: age);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Gender:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              _buildGenderChip('Male', true),
              const SizedBox(width: 8),
              _buildGenderChip('Female', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, bool isMale) {
    final isSelected = _profile.isMale == isMale;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _profile = _profile.copyWith(isMale: isMale);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.info : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLevel() {
    return _buildSection(
      title: 'Activity Level',
      icon: Icons.directions_run,
      child: Column(
        children: ActivityLevel.values.map((level) {
          final isSelected = _profile.activityLevel == level;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _profile = _profile.copyWith(activityLevel: level);
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.info.withOpacity(0.1) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.info : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getActivityIcon(level),
                    color: isSelected ? AppColors.info : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getActivityLabel(level),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.info : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _getActivityDescription(level),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.info),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getActivityIcon(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return Icons.weekend;
      case ActivityLevel.light:
        return Icons.directions_walk;
      case ActivityLevel.moderate:
        return Icons.directions_run;
      case ActivityLevel.active:
        return Icons.fitness_center;
      case ActivityLevel.veryActive:
        return Icons.sports_martial_arts;
    }
  }

  String _getActivityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Lightly Active';
      case ActivityLevel.moderate:
        return 'Moderately Active';
      case ActivityLevel.active:
        return 'Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
    }
  }

  String _getActivityDescription(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Little to no exercise, desk job';
      case ActivityLevel.light:
        return 'Light exercise 1-3 days/week';
      case ActivityLevel.moderate:
        return 'Moderate exercise 3-5 days/week';
      case ActivityLevel.active:
        return 'Hard exercise 6-7 days/week';
      case ActivityLevel.veryActive:
        return 'Very hard exercise, physical job';
    }
  }

  Widget _buildClimate() {
    return _buildSection(
      title: 'Climate',
      icon: Icons.thermostat,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ClimateType.values.map((climate) {
          final isSelected = _profile.climate == climate;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _profile = _profile.copyWith(climate: climate);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.info.withOpacity(0.1) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.info : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getClimateEmoji(climate),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getClimateLabel(climate),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.info : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getClimateEmoji(ClimateType climate) {
    switch (climate) {
      case ClimateType.cold:
        return '❄️';
      case ClimateType.moderate:
        return '🌤️';
      case ClimateType.warm:
        return '☀️';
      case ClimateType.hot:
        return '🔥';
      case ClimateType.veryHot:
        return '🥵';
    }
  }

  String _getClimateLabel(ClimateType climate) {
    switch (climate) {
      case ClimateType.cold:
        return 'Cold (<10°C)';
      case ClimateType.moderate:
        return 'Moderate';
      case ClimateType.warm:
        return 'Warm';
      case ClimateType.hot:
        return 'Hot';
      case ClimateType.veryHot:
        return 'Very Hot (>35°C)';
    }
  }

  Widget _buildSpecialConditions() {
    return _buildSection(
      title: 'Special Conditions',
      icon: Icons.favorite_outline,
      child: Column(
        children: [
          if (!_profile.isMale) ...[
            _buildToggleRow(
              label: 'Pregnant',
              emoji: '🤰',
              value: _profile.isPregnant,
              onChanged: (value) {
                setState(() {
                  _profile = _profile.copyWith(isPregnant: value);
                });
              },
            ),
            const SizedBox(height: 12),
            _buildToggleRow(
              label: 'Breastfeeding',
              emoji: '🤱',
              value: _profile.isBreastfeeding,
              onChanged: (value) {
                setState(() {
                  _profile = _profile.copyWith(isBreastfeeding: value);
                });
              },
            ),
          ],
          if (_profile.isMale)
            const Center(
              child: Text(
                'No special conditions applicable',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String emoji,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? AppColors.info.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomGoal() {
    return _buildSection(
      title: 'Custom Goal',
      icon: Icons.tune,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Use custom goal instead of calculated',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Switch(
                value: _profile.useCustomGoal,
                onChanged: (value) {
                  setState(() {
                    _profile = _profile.copyWith(useCustomGoal: value);
                  });
                },
                activeThumbColor: AppColors.info,
              ),
            ],
          ),
          if (_profile.useCustomGoal) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _profile = _profile.copyWith(
                        customGoalMl: (_profile.customGoalMl - 250).clamp(500, 5000),
                      );
                    });
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.remove, color: AppColors.info),
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  '${_profile.customGoalMl}ml',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _profile = _profile.copyWith(
                        customGoalMl: (_profile.customGoalMl + 250).clamp(500, 5000),
                      );
                    });
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.info, width: 2),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.info,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
