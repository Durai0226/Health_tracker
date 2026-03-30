import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Exam Subjects Settings Screen
class ExamSubjectsSettingsScreen extends StatefulWidget {
  const ExamSubjectsSettingsScreen({super.key});

  @override
  State<ExamSubjectsSettingsScreen> createState() => _ExamSubjectsSettingsScreenState();
}

class _ExamSubjectsSettingsScreenState extends State<ExamSubjectsSettingsScreen> {
  static const _primaryColor = Color(0xFF6366F1);

  final List<Map<String, dynamic>> _subjects = [
    {'name': 'Mathematics', 'icon': Icons.calculate, 'color': Colors.blue, 'progress': 0.75},
    {'name': 'Physics', 'icon': Icons.science, 'color': Colors.orange, 'progress': 0.60},
    {'name': 'Chemistry', 'icon': Icons.biotech, 'color': Colors.green, 'progress': 0.45},
    {'name': 'Biology', 'icon': Icons.eco, 'color': Colors.teal, 'progress': 0.80},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Subjects', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [IconButton(icon: Icon(Icons.add_circle_outline, color: _primaryColor), onPressed: _addSubject)],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _subjects.length,
        itemBuilder: (context, index) => _buildSubjectCard(_subjects[index], index),
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: (subject['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(subject['icon'], color: subject['color']),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: subject['progress'], backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(subject['color']), minHeight: 6),
                ),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.edit_outlined, color: _primaryColor), onPressed: () => _editSubject(index)),
        ],
      ),
    );
  }

  void _addSubject() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Add subject'), backgroundColor: _primaryColor));
  }

  void _editSubject(int index) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Edit ${_subjects[index]['name']}'), backgroundColor: _primaryColor));
  }
}
