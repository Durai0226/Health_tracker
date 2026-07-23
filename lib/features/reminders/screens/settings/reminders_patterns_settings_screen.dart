import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reminders Repeat Patterns Settings Screen
class RemindersPatternsSettingsScreen extends StatefulWidget {
  const RemindersPatternsSettingsScreen({super.key});

  @override
  State<RemindersPatternsSettingsScreen> createState() => _RemindersPatternsSettingsScreenState();
}

class _RemindersPatternsSettingsScreenState extends State<RemindersPatternsSettingsScreen> {
  String _defaultPattern = 'once';
  bool _isLoading = true;

  static const _primaryColor = Color(0xFFEC4899);

  final List<Map<String, dynamic>> _patterns = [
    {'id': 'once', 'name': 'Once', 'description': 'Single occurrence', 'icon': Symbols.looks_one_rounded},
    {'id': 'daily', 'name': 'Daily', 'description': 'Every day', 'icon': Symbols.today_rounded},
    {'id': 'weekly', 'name': 'Weekly', 'description': 'Same day each week', 'icon': Symbols.date_range_rounded},
    {'id': 'monthly', 'name': 'Monthly', 'description': 'Same date each month', 'icon': Symbols.calendar_month_rounded},
    {'id': 'yearly', 'name': 'Yearly', 'description': 'Annual reminder', 'icon': Symbols.event_rounded},
    {'id': 'weekdays', 'name': 'Weekdays', 'description': 'Monday to Friday', 'icon': Symbols.work_rounded},
    {'id': 'custom', 'name': 'Custom', 'description': 'Create your own pattern', 'icon': Symbols.tune_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _defaultPattern = prefs.getString('reminders_default_pattern') ?? 'once';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminders_default_pattern', _defaultPattern);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Repeat pattern saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF2F8),
        elevation: 0,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Repeat Patterns', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: _primaryColor)) : Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Set your default repeat pattern for new reminders', style: TextStyle(color: Colors.grey[600]))),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _patterns.length,
              itemBuilder: (context, index) => _buildPatternCard(_patterns[index]),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: _buildSaveButton()),
        ],
      ),
    );
  }

  Widget _buildPatternCard(Map<String, dynamic> pattern) {
    final isSelected = _defaultPattern == pattern['id'];
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _defaultPattern = pattern['id']); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? _primaryColor : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: isSelected ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(pattern['icon'], color: isSelected ? _primaryColor : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pattern['name'], style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? _primaryColor : Colors.black87)),
                  Text(pattern['description'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            if (isSelected) Icon(Symbols.check_circle_rounded, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Pattern', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}
