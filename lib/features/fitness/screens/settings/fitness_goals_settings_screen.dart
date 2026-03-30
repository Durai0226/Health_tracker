import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/fitness_theme.dart';

/// Fitness Goals Settings Screen
class FitnessGoalsSettingsScreen extends StatefulWidget {
  const FitnessGoalsSettingsScreen({super.key});

  @override
  State<FitnessGoalsSettingsScreen> createState() => _FitnessGoalsSettingsScreenState();
}

class _FitnessGoalsSettingsScreenState extends State<FitnessGoalsSettingsScreen> {
  int _weeklyWorkouts = 4;
  int _dailySteps = 10000;
  int _dailyCalories = 500;
  int _dailyActiveMinutes = 30;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _weeklyWorkouts = prefs.getInt('fitness_weekly_workouts') ?? 4;
        _dailySteps = prefs.getInt('fitness_daily_steps') ?? 10000;
        _dailyCalories = prefs.getInt('fitness_daily_calories') ?? 500;
        _dailyActiveMinutes = prefs.getInt('fitness_daily_active_minutes') ?? 30;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fitness_weekly_workouts', _weeklyWorkouts);
    await prefs.setInt('fitness_daily_steps', _dailySteps);
    await prefs.setInt('fitness_daily_calories', _dailyCalories);
    await prefs.setInt('fitness_daily_active_minutes', _dailyActiveMinutes);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Goals saved!'),
          backgroundColor: FitnessTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
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
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Fitness Goals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: FitnessTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                child: Column(
                  children: [
                    _buildGoalCard('Weekly Workouts', '$_weeklyWorkouts sessions', Icons.fitness_center, 
                      _weeklyWorkouts, 1, 7, (v) => setState(() => _weeklyWorkouts = v)),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    _buildGoalCard('Daily Steps', '${_dailySteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} steps', Icons.directions_walk,
                      _dailySteps ~/ 1000, 3, 20, (v) => setState(() => _dailySteps = v * 1000), suffix: 'k'),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    _buildGoalCard('Daily Calories', '$_dailyCalories kcal', Icons.local_fire_department,
                      _dailyCalories ~/ 100, 2, 15, (v) => setState(() => _dailyCalories = v * 100), suffix: '00'),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    _buildGoalCard('Active Minutes', '$_dailyActiveMinutes min', Icons.timer,
                      _dailyActiveMinutes, 15, 120, (v) => setState(() => _dailyActiveMinutes = v), step: 15),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildSaveButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGoalCard(String title, String value, IconData icon, int current, int min, int max, ValueChanged<int> onChanged, {String suffix = '', int step = 1}) {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(
        color: FitnessTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: FitnessTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FitnessTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(value, style: TextStyle(color: FitnessTheme.primary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildAdjustButton(Icons.remove, current > min ? () => onChanged(current - step) : null),
              Expanded(
                child: Center(
                  child: Text('$current$suffix', style: TextStyle(color: FitnessTheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildAdjustButton(Icons.add, current < max ? () => onChanged(current + step) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton(IconData icon, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: () {
        if (isEnabled) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isEnabled ? FitnessTheme.primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isEnabled ? FitnessTheme.primary : Colors.grey),
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
          backgroundColor: FitnessTheme.primary,
          foregroundColor: FitnessTheme.background,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
