import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_colors_ext.dart';
import '../models/hydration_profile.dart';
import '../services/water_service.dart';

/// Hydration Profile Screen - Calculate personalized water goal
class HydrationProfileScreen extends StatefulWidget {
  const HydrationProfileScreen({super.key});

  @override
  State<HydrationProfileScreen> createState() => _HydrationProfileScreenState();
}

class _HydrationProfileScreenState extends State<HydrationProfileScreen> {
  // Eagerly initialized so build() never reads an unassigned `late` before the
  // async _initializeProfile() completes (was a LateInitializationError on first
  // frame). WaterService overwrites it once loaded.
  HydrationProfile _profile = HydrationProfile(id: 'profile', createdAt: DateTime.now());
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    try {
      await WaterService.init();
      _profile = WaterService.getProfile();
      _weightController.text = _profile.weightKg?.toString() ?? '';
      _ageController.text = _profile.age?.toString() ?? '';
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing profile: $e');
      if (mounted) {
        _profile = HydrationProfile(
          id: 'profile',
          createdAt: DateTime.now(),
        );
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    // Validation
    if (_validateInput()) {
      setState(() => _isSaving = true);

      try {
        await WaterService.init(); // Ensure service is initialized

        final weight = double.tryParse(_weightController.text.trim());
        final age = int.tryParse(_ageController.text.trim());

        final updated = _profile.copyWith(
          weightKg: weight,
          age: age,
          updatedAt: DateTime.now(),
        );

        await WaterService.saveProfile(updated);

        if (mounted) {
          final ext = AppColorsExt.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Profile saved! Daily goal: ${updated.effectiveGoalMl}ml',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: ext.success.base,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint('Error saving profile: $e');
        if (mounted) {
          final ext = AppColorsExt.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to save profile. Please try again.',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: ext.error.base,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  bool _validateInput() {
    final weight = double.tryParse(_weightController.text.trim());
    final age = int.tryParse(_ageController.text.trim());

    if (weight != null && (weight < 20 || weight > 300)) {
      _showValidationError('Please enter a valid weight between 20-300 kg');
      return false;
    }

    if (age != null && (age < 1 || age > 120)) {
      _showValidationError('Please enter a valid age between 1-120 years');
      return false;
    }

    return true;
  }

  void _showValidationError(String message) {
    if (mounted) {
      final ext = AppColorsExt.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: ext.warning.base,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Scaffold(
      backgroundColor: ext.background,
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
    final ext = AppColorsExt.of(context);
    // Saturated teal that keeps white text readable in both themes.
    final heroBg = ext.isDark ? ext.water.container : ext.water.strong;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [heroBg, heroBg.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ext.water.base.withOpacity(0.3),
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
    final ext = AppColorsExt.of(context);
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
              Text('Gender:', style: TextStyle(fontWeight: FontWeight.w500, color: ext.textPrimary)),
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
    final ext = AppColorsExt.of(context);
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
          color: isSelected ? ext.fillBg(ext.water) : ext.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? ext.fillFg(ext.water) : ext.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLevel() {
    final ext = AppColorsExt.of(context);
    final waterMark = ext.mark(ext.water);
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
                color: isSelected ? waterMark.withOpacity(0.12) : ext.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? waterMark : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getActivityIcon(level),
                    color: isSelected ? waterMark : ext.textSecondary,
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
                            color: isSelected ? waterMark : ext.textPrimary,
                          ),
                        ),
                        Text(
                          _getActivityDescription(level),
                          style: TextStyle(
                            fontSize: 12,
                            color: ext.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: waterMark),
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
    final ext = AppColorsExt.of(context);
    final waterMark = ext.mark(ext.water);
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
                color: isSelected ? waterMark.withOpacity(0.12) : ext.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? waterMark : Colors.transparent,
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
                      color: isSelected ? waterMark : ext.textPrimary,
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
    final ext = AppColorsExt.of(context);
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
            Center(
              child: Text(
                'No special conditions applicable',
                style: TextStyle(color: ext.textSecondary),
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
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? ext.mark(ext.water).withOpacity(0.12) : ext.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, color: ext.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ext.water.base,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomGoal() {
    final ext = AppColorsExt.of(context);
    final waterMark = ext.mark(ext.water);
    return _buildSection(
      title: 'Custom Goal',
      icon: Icons.tune,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Use custom goal instead of calculated',
                  style: TextStyle(color: ext.textSecondary),
                ),
              ),
              Switch(
                value: _profile.useCustomGoal,
                onChanged: (value) {
                  setState(() {
                    _profile = _profile.copyWith(useCustomGoal: value);
                  });
                },
                activeThumbColor: ext.water.base,
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
                      color: waterMark.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.remove, color: waterMark),
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  '${_profile.customGoalMl}ml',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: waterMark,
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
                      color: waterMark.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: waterMark),
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
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
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
              Icon(icon, color: ext.mark(ext.water)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ext.textPrimary,
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
    final ext = AppColorsExt.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: ext.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.mark(ext.water), width: 2),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final ext = AppColorsExt.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: ext.fillBg(ext.water),
          foregroundColor: ext.fillFg(ext.water),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: ext.fillFg(ext.water),
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
