import 'package:flutter/material.dart';

class MindfulnessScreen extends StatefulWidget {
  const MindfulnessScreen({super.key});

  @override
  State<MindfulnessScreen> createState() => _MindfulnessScreenState();
}

class _MindfulnessScreenState extends State<MindfulnessScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  int _stressLevel = 3; // 1-5 scale
  final int _meditationMinutesToday = 15;
  final int _currentStreak = 7;

  final List<Map<String, dynamic>> _sessions = [
    {'name': 'Morning Calm', 'duration': 10, 'category': 'Meditation', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'name': 'Stress Relief', 'duration': 15, 'category': 'Breathing', 'icon': Icons.air, 'color': Colors.blue},
    {'name': 'Deep Sleep', 'duration': 20, 'category': 'Sleep', 'icon': Icons.bedtime, 'color': Colors.indigo},
    {'name': 'Focus Boost', 'duration': 5, 'category': 'Focus', 'icon': Icons.center_focus_strong, 'color': Colors.purple},
    {'name': 'Body Scan', 'duration': 12, 'category': 'Relaxation', 'icon': Icons.accessibility_new, 'color': Colors.teal},
    {'name': 'Gratitude', 'duration': 8, 'category': 'Mindfulness', 'icon': Icons.favorite, 'color': Colors.pink},
  ];

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildBreathingExercise()),
          SliverToBoxAdapter(child: _buildStressTracker()),
          SliverToBoxAdapter(child: _buildQuickSessions()),
          SliverToBoxAdapter(child: _buildDailyProgress()),
          SliverToBoxAdapter(child: _buildMoodJournal()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1E1E2E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.history, color: Colors.white70), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white70), onPressed: () {}),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Mindfulness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF1E1E2E), Colors.purple.shade900.withOpacity(0.5)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: 20, bottom: 60, child: Icon(Icons.self_improvement, size: 50, color: Colors.purple.withOpacity(0.3))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreathingExercise() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.indigo.shade700]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('Breathing Exercise', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) {
              final scale = 0.8 + (_breatheController.value * 0.4);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _breatheController.value < 0.5 ? 'Breathe In' : 'Breathe Out',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBreathingButton('4-7-8', false),
              const SizedBox(width: 12),
              _buildBreathingButton('Box', true),
              const SizedBox(width: 12),
              _buildBreathingButton('Calm', false),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startBreathingSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text('Start Session', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingButton(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildStressTracker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _getStressColor().withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.psychology, color: _getStressColor()),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Stress Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _getStressColor().withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(_getStressLabel(), style: TextStyle(color: _getStressColor(), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (index) {
              final level = index + 1;
              final isSelected = level == _stressLevel;
              return GestureDetector(
                onTap: () => setState(() => _stressLevel = level),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected ? _getStressColorForLevel(level) : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: _getStressColorForLevel(level), width: 2) : null,
                      ),
                      child: Center(child: Text(_getStressEmoji(level), style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(height: 6),
                    Text('$level', style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _getStressColor() => _getStressColorForLevel(_stressLevel);

  Color _getStressColorForLevel(int level) {
    switch (level) {
      case 1: return Colors.green;
      case 2: return Colors.lightGreen;
      case 3: return Colors.amber;
      case 4: return Colors.orange;
      case 5: return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStressLabel() {
    switch (_stressLevel) {
      case 1: return 'Calm';
      case 2: return 'Relaxed';
      case 3: return 'Moderate';
      case 4: return 'Stressed';
      case 5: return 'Overwhelmed';
      default: return '';
    }
  }

  String _getStressEmoji(int level) {
    switch (level) {
      case 1: return '😌';
      case 2: return '🙂';
      case 3: return '😐';
      case 4: return '😟';
      case 5: return '😰';
      default: return '';
    }
  }

  Widget _buildQuickSessions() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quick Sessions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return _buildSessionCard(session);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    return GestureDetector(
      onTap: () => _startMeditationSession(session),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [(session['color'] as Color).withOpacity(0.8), session['color'] as Color],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(session['icon'] as IconData, color: Colors.white, size: 28),
            const Spacer(),
            Text(session['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text('${session['duration']} min', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProgress() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today\'s Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildProgressCard(
                  icon: Icons.self_improvement,
                  value: '$_meditationMinutesToday',
                  unit: 'min',
                  label: 'Meditated',
                  color: Colors.purple,
                  progress: _meditationMinutesToday / 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProgressCard(
                  icon: Icons.local_fire_department,
                  value: '$_currentStreak',
                  unit: 'days',
                  label: 'Streak',
                  color: Colors.orange,
                  progress: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Goal Achieved!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('You\'ve reached your 15 min goal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 4,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodJournal() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Colors.white),
              SizedBox(width: 10),
              Text('Mood Journal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openJournalEntry,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.purple.shade300),
                  const SizedBox(width: 12),
                  Text('How are you feeling today?', style: TextStyle(color: Colors.purple.shade200)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent Entries', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          _buildJournalEntry('Feeling grateful for today\'s progress', '2 hours ago', '😊'),
          _buildJournalEntry('Morning meditation helped with focus', 'Yesterday', '🧘'),
        ],
      ),
    );
  }

  Widget _buildJournalEntry(String text, String time, String emoji) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(time, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startBreathingSession() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.indigo.shade900, Colors.purple.shade900]),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Spacer(),
            const Text('Box Breathing', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 4),
              ),
              child: const Center(
                child: Text('4', style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w200)),
              ),
            ),
            const SizedBox(height: 40),
            const Text('Breathe In', style: TextStyle(color: Colors.white70, fontSize: 18)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('End Session', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startMeditationSession(Map<String, dynamic> session) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting ${session['name']}...'),
        backgroundColor: session['color'] as Color,
      ),
    );
  }

  void _openJournalEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A3E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('How are you feeling?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['😊', '😌', '😐', '😔', '😢'].map((emoji) => GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write your thoughts...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Entry', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
