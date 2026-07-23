import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Focus Session Durations Settings Screen
class FocusDurationsSettingsScreen extends StatefulWidget {
  const FocusDurationsSettingsScreen({super.key});

  @override
  State<FocusDurationsSettingsScreen> createState() => _FocusDurationsSettingsScreenState();
}

class _FocusDurationsSettingsScreenState extends State<FocusDurationsSettingsScreen> {
  List<int> _durations = [15, 25, 45, 60, 90];
  int _defaultDuration = 25;
  int _shortBreak = 5;
  int _longBreak = 15;
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _defaultDuration = prefs.getInt('focus_default_duration') ?? 25;
        _shortBreak = prefs.getInt('focus_short_break') ?? 5;
        _longBreak = prefs.getInt('focus_long_break') ?? 15;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('focus_default_duration', _defaultDuration);
    await prefs.setInt('focus_short_break', _shortBreak);
    await prefs.setInt('focus_long_break', _longBreak);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Durations saved!'),
          backgroundColor: _primaryColor,
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Session Durations', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Default Focus Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildDurationSelector(),
                  const SizedBox(height: 24),
                  const Text('Break Durations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildBreakCard('Short Break', _shortBreak, 1, 15, (v) => setState(() => _shortBreak = v)),
                  const SizedBox(height: 12),
                  _buildBreakCard('Long Break', _longBreak, 10, 30, (v) => setState(() => _longBreak = v)),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDurationSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _durations.map((duration) {
        final isSelected = _defaultDuration == duration;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _defaultDuration = duration);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? _primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? _primaryColor : Colors.grey.shade300),
              boxShadow: isSelected ? [BoxShadow(color: _primaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
            ),
            child: Column(
              children: [
                Text('$duration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                Text('min', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBreakCard(String title, int value, int min, int max, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Symbols.coffee_rounded, color: _primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$value minutes', style: TextStyle(color: _primaryColor, fontSize: 13)),
              ],
            ),
          ),
          Row(
            children: [
              _buildAdjustButton(Symbols.remove_rounded, value > min ? () => onChanged(value - 1) : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
              ),
              _buildAdjustButton(Symbols.add_rounded, value < max ? () => onChanged(value + 1) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton(IconData icon, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: () { if (isEnabled) { HapticFeedback.lightImpact(); onTap(); } },
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: isEnabled ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: isEnabled ? _primaryColor : Colors.grey),
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
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Durations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
