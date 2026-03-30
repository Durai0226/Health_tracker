import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/habit_theme.dart';
import '../../services/habit_service.dart';

/// Habit Goals Settings Screen
/// Allows users to set daily/weekly habit targets and streak goals
class HabitGoalsSettingsScreen extends StatefulWidget {
  const HabitGoalsSettingsScreen({super.key});

  @override
  State<HabitGoalsSettingsScreen> createState() => _HabitGoalsSettingsScreenState();
}

class _HabitGoalsSettingsScreenState extends State<HabitGoalsSettingsScreen> {
  final HabitService _habitService = HabitService();
  
  int _dailyHabitTarget = 3;
  int _weeklyHabitTarget = 5;
  int _streakGoal = 30;
  bool _showStreakReminders = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _habitService.getGoalSettings();
    if (mounted) {
      setState(() {
        _dailyHabitTarget = settings['dailyTarget'] ?? 3;
        _weeklyHabitTarget = settings['weeklyTarget'] ?? 5;
        _streakGoal = settings['streakGoal'] ?? 30;
        _showStreakReminders = settings['showStreakReminders'] ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    await _habitService.saveGoalSettings({
      'dailyTarget': _dailyHabitTarget,
      'weeklyTarget': _weeklyHabitTarget,
      'streakGoal': _streakGoal,
      'showStreakReminders': _showStreakReminders,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Goals saved successfully!'),
          backgroundColor: HabitTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: HabitTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Goals',
          style: HabitTheme.h2.copyWith(color: HabitTheme.dark),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: HabitTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(HabitTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Daily Goals'),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildGoalCard(
                    title: 'Daily Habit Target',
                    subtitle: 'Number of habits to complete each day',
                    value: _dailyHabitTarget,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() => _dailyHabitTarget = v),
                  ),
                  const SizedBox(height: HabitTheme.spacingM),
                  
                  _buildSectionTitle('Weekly Goals'),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildGoalCard(
                    title: 'Weekly Habit Target',
                    subtitle: 'Days per week to maintain habits',
                    value: _weeklyHabitTarget,
                    min: 1,
                    max: 7,
                    onChanged: (v) => setState(() => _weeklyHabitTarget = v),
                  ),
                  const SizedBox(height: HabitTheme.spacingM),
                  
                  _buildSectionTitle('Streak Goals'),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildGoalCard(
                    title: 'Streak Target',
                    subtitle: 'Days to maintain your streak',
                    value: _streakGoal,
                    min: 7,
                    max: 365,
                    step: 7,
                    onChanged: (v) => setState(() => _streakGoal = v),
                  ),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildToggleCard(
                    title: 'Streak Reminders',
                    subtitle: 'Get notified when streak is at risk',
                    value: _showStreakReminders,
                    onChanged: (v) => setState(() => _showStreakReminders = v),
                  ),
                  const SizedBox(height: HabitTheme.spacingXL),
                  
                  _buildSaveButton(),
                  const SizedBox(height: HabitTheme.spacingL),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: HabitTheme.label.copyWith(
          color: HabitTheme.dark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(HabitTheme.spacingM),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HabitTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HabitTheme.label.copyWith(color: HabitTheme.dark)),
          const SizedBox(height: 4),
          Text(subtitle, style: HabitTheme.b3.copyWith(color: HabitTheme.gray)),
          const SizedBox(height: HabitTheme.spacingM),
          Row(
            children: [
              _buildAdjustButton(
                icon: Icons.remove,
                onTap: value > min ? () => onChanged(value - step) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: HabitTheme.h1.copyWith(
                      color: HabitTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildAdjustButton(
                icon: Icons.add,
                onTap: value < max ? () => onChanged(value + step) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: () {
        if (isEnabled) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isEnabled ? HabitTheme.primarySoft : HabitTheme.grayLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isEnabled ? HabitTheme.primary : HabitTheme.gray,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(HabitTheme.spacingM),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HabitTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HabitTheme.label.copyWith(color: HabitTheme.dark)),
                const SizedBox(height: 4),
                Text(subtitle, style: HabitTheme.b3.copyWith(color: HabitTheme.gray)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeColor: HabitTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: HabitTheme.primary,
          foregroundColor: HabitTheme.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Save Goals',
          style: HabitTheme.label.copyWith(
            color: HabitTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
