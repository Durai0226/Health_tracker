import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exam Study Reminders Settings Screen
class ExamRemindersSettingsScreen extends StatefulWidget {
  const ExamRemindersSettingsScreen({super.key});

  @override
  State<ExamRemindersSettingsScreen> createState() => _ExamRemindersSettingsScreenState();
}

class _ExamRemindersSettingsScreenState extends State<ExamRemindersSettingsScreen> {
  bool _studyReminders = true;
  bool _examReminders = true;
  bool _breakReminders = true;
  bool _progressAlerts = true;
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _studyReminders = prefs.getBool('exam_study_reminders') ?? true;
        _examReminders = prefs.getBool('exam_exam_reminders') ?? true;
        _breakReminders = prefs.getBool('exam_break_reminders') ?? true;
        _progressAlerts = prefs.getBool('exam_progress_alerts') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('exam_study_reminders', _studyReminders);
    await prefs.setBool('exam_exam_reminders', _examReminders);
    await prefs.setBool('exam_break_reminders', _breakReminders);
    await prefs.setBool('exam_progress_alerts', _progressAlerts);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Reminders saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Study Reminders', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: _primaryColor)) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildToggleCard(Icons.school, 'Study Session Reminders', 'Daily study time alerts', _studyReminders, (v) => setState(() => _studyReminders = v)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.event, 'Exam Reminders', 'Upcoming exam alerts', _examReminders, (v) => setState(() => _examReminders = v)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.coffee, 'Break Reminders', 'Take a break alerts', _breakReminders, (v) => setState(() => _breakReminders = v)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.trending_up, 'Progress Alerts', 'Weekly progress updates', _progressAlerts, (v) => setState(() => _progressAlerts = v)),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: value ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: value ? _primaryColor : Colors.grey)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13))])),
          Switch.adaptive(value: value, onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); }, activeColor: _primaryColor),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}
