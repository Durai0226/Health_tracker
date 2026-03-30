import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exam Study Schedule Settings Screen
class ExamScheduleSettingsScreen extends StatefulWidget {
  const ExamScheduleSettingsScreen({super.key});

  @override
  State<ExamScheduleSettingsScreen> createState() => _ExamScheduleSettingsScreenState();
}

class _ExamScheduleSettingsScreenState extends State<ExamScheduleSettingsScreen> {
  TimeOfDay _studyStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _studyEnd = const TimeOfDay(hour: 17, minute: 0);
  int _sessionLength = 45;
  int _breakLength = 15;
  List<bool> _studyDays = [true, true, true, true, true, true, false];
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF6366F1);
  final _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Schedule saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating));
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
        title: const Text('Study Schedule', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: _primaryColor)) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeCard(),
            const SizedBox(height: 16),
            _buildSessionCard(),
            const SizedBox(height: 16),
            _buildDaysCard(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Study Hours', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTimeSelector('Start', _studyStart, (t) => setState(() => _studyStart = t))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('to')),
              Expanded(child: _buildTimeSelector('End', _studyEnd, (t) => setState(() => _studyEnd = t))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) { HapticFeedback.lightImpact(); onChanged(picked); }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Text(time.format(context), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildSliderRow('Session Length', '$_sessionLength min', _sessionLength.toDouble(), 15, 90, (v) => setState(() => _sessionLength = v.round())),
          const Divider(height: 24),
          _buildSliderRow('Break Length', '$_breakLength min', _breakLength.toDouble(), 5, 30, (v) => setState(() => _breakLength = v.round())),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String title, String value, double current, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w500)), const Spacer(), Text(value, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600))]),
        Slider(value: current, min: min, max: max, divisions: ((max - min) / 5).round(), activeColor: _primaryColor, onChanged: (v) { HapticFeedback.selectionClick(); onChanged(v); }),
      ],
    );
  }

  Widget _buildDaysCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Study Days', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final isSelected = _studyDays[i];
              return GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); setState(() => _studyDays[i] = !isSelected); },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: isSelected ? _primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? _primaryColor : Colors.grey)),
                  child: Center(child: Text(_dayNames[i][0], style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w600))),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}
