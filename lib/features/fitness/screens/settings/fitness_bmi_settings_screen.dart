import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/fitness_theme.dart';

/// Fitness BMI & Body Stats Settings Screen
class FitnessBmiSettingsScreen extends StatefulWidget {
  const FitnessBmiSettingsScreen({super.key});

  @override
  State<FitnessBmiSettingsScreen> createState() => _FitnessBmiSettingsScreenState();
}

class _FitnessBmiSettingsScreenState extends State<FitnessBmiSettingsScreen> {
  double _height = 170;
  double _weight = 70;
  double _targetWeight = 65;
  bool _isLoading = true;

  double get _bmi => _weight / ((_height / 100) * (_height / 100));
  String get _bmiCategory {
    if (_bmi < 18.5) return 'Underweight';
    if (_bmi < 25) return 'Normal';
    if (_bmi < 30) return 'Overweight';
    return 'Obese';
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _height = prefs.getDouble('fitness_height') ?? 170;
        _weight = prefs.getDouble('fitness_weight') ?? 70;
        _targetWeight = prefs.getDouble('fitness_target_weight') ?? 65;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fitness_height', _height);
    await prefs.setDouble('fitness_weight', _weight);
    await prefs.setDouble('fitness_target_weight', _targetWeight);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Body stats saved!'),
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
          title: const Text('BMI & Body Stats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: FitnessTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                child: Column(
                  children: [
                    _buildBmiCard(),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    _buildStatCard('Height', '${_height.toInt()} cm', Icons.height, _height, 120, 220, (v) => setState(() => _height = v)),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    _buildStatCard('Current Weight', '${_weight.toStringAsFixed(1)} kg', Icons.monitor_weight, _weight, 30, 200, (v) => setState(() => _weight = v), decimal: true),
                    const SizedBox(height: FitnessTheme.spacingMd),
                    _buildStatCard('Target Weight', '${_targetWeight.toStringAsFixed(1)} kg', Icons.flag, _targetWeight, 30, 200, (v) => setState(() => _targetWeight = v), decimal: true),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildSaveButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBmiCard() {
    final bmiColor = _bmi < 18.5 ? Colors.orange : (_bmi < 25 ? FitnessTheme.success : (_bmi < 30 ? Colors.orange : FitnessTheme.error));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [FitnessTheme.primary, FitnessTheme.primary.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Your BMI', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(_bmi.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: bmiColor, borderRadius: BorderRadius.circular(20)),
            child: Text(_bmiCategory, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, double current, double min, double max, ValueChanged<double> onChanged, {bool decimal = false}) {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(color: FitnessTheme.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: FitnessTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
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
          Slider(
            value: current,
            min: min,
            max: max,
            divisions: decimal ? ((max - min) * 2).toInt() : (max - min).toInt(),
            activeColor: FitnessTheme.primary,
            inactiveColor: FitnessTheme.primary.withValues(alpha: 0.3),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(decimal ? double.parse(v.toStringAsFixed(1)) : v.roundToDouble());
            },
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
          backgroundColor: FitnessTheme.primary,
          foregroundColor: FitnessTheme.background,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
