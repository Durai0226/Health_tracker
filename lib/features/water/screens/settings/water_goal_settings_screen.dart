import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/aqua_theme.dart';

/// Water Daily Goal Settings Screen
class WaterGoalSettingsScreen extends StatefulWidget {
  const WaterGoalSettingsScreen({super.key});

  @override
  State<WaterGoalSettingsScreen> createState() => _WaterGoalSettingsScreenState();
}

class _WaterGoalSettingsScreenState extends State<WaterGoalSettingsScreen> {
  int _dailyGoalMl = 2000;
  String _unit = 'ml';
  bool _isLoading = true;

  final List<int> _presetGoals = [1500, 2000, 2500, 3000, 3500, 4000];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dailyGoalMl = prefs.getInt('water_daily_goal') ?? 2000;
        _unit = prefs.getString('water_unit') ?? 'ml';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_daily_goal', _dailyGoalMl);
    await prefs.setString('water_unit', _unit);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Goal saved!'),
          backgroundColor: AquaTheme.waterPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  String _formatGoal(int ml) {
    if (_unit == 'oz') {
      return '${(ml / 29.5735).round()} oz';
    }
    return '$ml ml';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AquaTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AquaTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AquaTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Daily Goal', style: TextStyle(color: AquaTheme.textPrimary, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AquaTheme.waterPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentGoalCard(),
                  const SizedBox(height: 24),
                  _buildPresetGoals(),
                  const SizedBox(height: 24),
                  _buildUnitSelector(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentGoalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AquaTheme.waterPrimary, AquaTheme.waterSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AquaTheme.waterPrimary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.water_drop, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            _formatGoal(_dailyGoalMl),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Daily Target', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPresetGoals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Select', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AquaTheme.textPrimary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _presetGoals.map((goal) {
            final isSelected = _dailyGoalMl == goal;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _dailyGoalMl = goal);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AquaTheme.waterPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AquaTheme.waterPrimary : AquaTheme.textTertiary.withValues(alpha: 0.3),
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: AquaTheme.waterPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ] : null,
                ),
                child: Text(
                  _formatGoal(goal),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AquaTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUnitSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.straighten, color: AquaTheme.textSecondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Measurement Unit', style: TextStyle(color: AquaTheme.textPrimary, fontWeight: FontWeight.w500)),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ml', label: Text('ml')),
              ButtonSegment(value: 'oz', label: Text('oz')),
            ],
            selected: {_unit},
            onSelectionChanged: (v) {
              HapticFeedback.lightImpact();
              setState(() => _unit = v.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AquaTheme.waterPrimary;
                return Colors.transparent;
              }),
            ),
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
          backgroundColor: AquaTheme.waterPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
