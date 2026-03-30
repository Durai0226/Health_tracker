import 'package:flutter/material.dart';

/// Exam Performance Analytics Screen
class ExamPerformanceSettingsScreen extends StatelessWidget {
  const ExamPerformanceSettingsScreen({super.key});

  static const _primaryColor = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Performance', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildWeeklyChart(),
            const SizedBox(height: 16),
            _buildSubjectBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _StatItem(label: 'Study Hours', value: '24.5', icon: Icons.timer),
            _StatItem(label: 'Sessions', value: '32', icon: Icons.event),
            _StatItem(label: 'Streak', value: '7', icon: Icons.local_fire_department),
          ]),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This Week', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                final heights = [0.6, 0.8, 0.5, 0.9, 0.7, 0.3, 0.0];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(width: 30, height: 80 * heights[e.key], decoration: BoxDecoration(color: _primaryColor.withValues(alpha: heights[e.key] > 0 ? 1 : 0.2), borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Text(e.value, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBreakdown() {
    final subjects = [
      {'name': 'Mathematics', 'hours': 8.5, 'color': Colors.blue},
      {'name': 'Physics', 'hours': 6.0, 'color': Colors.orange},
      {'name': 'Chemistry', 'hours': 5.5, 'color': Colors.green},
      {'name': 'Biology', 'hours': 4.5, 'color': Colors.teal},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subject Breakdown', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...subjects.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: s['color'] as Color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 12),
                Expanded(child: Text(s['name'] as String)),
                Text('${s['hours']}h', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
