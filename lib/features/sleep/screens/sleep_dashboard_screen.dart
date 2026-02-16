import 'package:flutter/material.dart';
import 'dart:math' as math;

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({super.key});

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Sleep data
  final int _lastNightScore = 82;
  final String _lastNightDuration = '7h 24m';
  final String _bedTime = '10:45 PM';
  final String _wakeTime = '6:09 AM';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildSleepScoreCard()),
          SliverToBoxAdapter(child: _buildSleepStages()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.purple.shade300,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Insights'),
                  Tab(text: 'Schedule'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildInsightsTab(),
            _buildScheduleTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A2E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.alarm, color: Colors.white70), onPressed: () {}, tooltip: 'Sleep Schedule'),
        IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white70), onPressed: () {}),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Sleep', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF1A1A2E), Colors.purple.shade900.withOpacity(0.5)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: 20, bottom: 60, child: Icon(Icons.bedtime_rounded, size: 50, color: Colors.purple.withOpacity(0.3))),
              Positioned(right: 80, top: 40, child: Icon(Icons.star, size: 12, color: Colors.white.withOpacity(0.3))),
              Positioned(right: 50, top: 60, child: Icon(Icons.star, size: 8, color: Colors.white.withOpacity(0.2))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepScoreCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple.shade800, Colors.purple.shade600]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(painter: _SleepScorePainter(score: _lastNightScore / 100)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_lastNightScore', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        const Text('Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last Night', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_lastNightDuration, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTimeChip(Icons.bedtime, _bedTime),
                        const SizedBox(width: 12),
                        _buildTimeChip(Icons.wb_sunny, _wakeTime),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Great sleep! You spent 1h 48m in deep sleep, above your average.', style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(time, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSleepStages() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF252542), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep Stages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStageBar('Awake', 12, Colors.red.shade300, 0.08)),
              const SizedBox(width: 8),
              Expanded(child: _buildStageBar('REM', 96, Colors.cyan, 0.22)),
              const SizedBox(width: 8),
              Expanded(child: _buildStageBar('Light', 198, Colors.blue.shade300, 0.45)),
              const SizedBox(width: 8),
              Expanded(child: _buildStageBar('Deep', 108, Colors.indigo, 0.25)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSleepTimeline(),
        ],
      ),
    );
  }

  Widget _buildStageBar(String label, int minutes, Color color, double percentage) {
    return Column(
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 80 * percentage * 2,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text('${minutes}m', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildSleepTimeline() {
    return Container(
      height: 40,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(flex: 5, child: Container(color: Colors.blue.shade300)),
            Expanded(flex: 8, child: Container(color: Colors.indigo)),
            Expanded(flex: 2, child: Container(color: Colors.red.shade300)),
            Expanded(flex: 12, child: Container(color: Colors.blue.shade300)),
            Expanded(flex: 6, child: Container(color: Colors.cyan)),
            Expanded(flex: 10, child: Container(color: Colors.blue.shade300)),
            Expanded(flex: 4, child: Container(color: Colors.indigo)),
            Expanded(flex: 8, child: Container(color: Colors.cyan)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWeeklyChart(),
        const SizedBox(height: 16),
        _buildSleepMetrics(),
        const SizedBox(height: 16),
        _buildSleepFactors(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final scores = [75, 68, 82, 79, 85, 72, 82];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF252542), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('This Week', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('Avg: 78', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final score = scores[index];
                final isToday = index == 6;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$score', style: TextStyle(color: isToday ? Colors.purple.shade300 : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: score.toDouble(),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isToday ? [Colors.purple.shade400, Colors.purple.shade300] : [Colors.purple.shade800, Colors.purple.shade600],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(days[index], style: TextStyle(color: isToday ? Colors.white : Colors.white54, fontSize: 12)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF252542), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep Metrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Resting HR', '52', 'bpm', Icons.favorite, Colors.red)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('HRV', '45', 'ms', Icons.monitor_heart, Colors.cyan)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('SpO2', '97', '%', Icons.air, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Breathing', '14', '/min', Icons.waves, Colors.teal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSleepFactors() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF252542), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep Factors', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildFactorRow('Caffeine', 'None after 2 PM', Icons.coffee, Colors.brown, true),
          _buildFactorRow('Exercise', '45 min workout', Icons.fitness_center, Colors.orange, true),
          _buildFactorRow('Screen Time', '30 min before bed', Icons.phone_android, Colors.blue, false),
          _buildFactorRow('Stress Level', 'Low', Icons.spa, Colors.green, true),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String title, String subtitle, IconData icon, Color color, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Icon(isPositive ? Icons.check_circle : Icons.warning_amber_rounded, color: isPositive ? Colors.green : Colors.amber, size: 20),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInsightCard('Consistency is Key', 'Your bedtime varied by 2+ hours this week. Try to maintain a consistent schedule.', Icons.schedule, Colors.orange, 'high'),
        const SizedBox(height: 12),
        _buildInsightCard('Deep Sleep Champion', 'You\'re getting 25% deep sleep, above the 20% average. Keep it up!', Icons.emoji_events, Colors.green, 'positive'),
        const SizedBox(height: 12),
        _buildInsightCard('REM Recovery', 'Your REM sleep has improved 15% since last week.', Icons.trending_up, Colors.cyan, 'positive'),
        const SizedBox(height: 12),
        _buildWellnessReport(),
      ],
    );
  }

  Widget _buildInsightCard(String title, String description, IconData icon, Color color, String priority) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252542),
        borderRadius: BorderRadius.circular(20),
        border: priority == 'high' ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessReport() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo.shade800, Colors.purple.shade800]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.white),
              SizedBox(width: 10),
              Text('Weekly Wellness Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWellnessStat('Sleep', 78, Colors.purple.shade300),
              _buildWellnessStat('Recovery', 72, Colors.cyan),
              _buildWellnessStat('Stress', 25, Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('View Full Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessStat(String label, int value, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 55,
                height: 55,
                child: CircularProgressIndicator(value: value / 100, strokeWidth: 5, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(color)),
              ),
              Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildScheduleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBedtimeSchedule(),
        const SizedBox(height: 16),
        _buildSmartAlarm(),
        const SizedBox(height: 16),
        _buildSleepGoal(),
      ],
    );
  }

  Widget _buildBedtimeSchedule() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF252542), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bedtime Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Switch(value: true, onChanged: (v) {}, activeThumbColor: Colors.purple.shade300),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTimeSelector('Bedtime', '10:30 PM', Icons.bedtime, Colors.indigo),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: const Icon(Icons.arrow_forward, color: Colors.white24),
              ),
              Expanded(
                child: _buildTimeSelector('Wake Up', '6:30 AM', Icons.wb_sunny, Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, color: Colors.white54, size: 18),
              SizedBox(width: 8),
              Text('8 hours of sleep', style: TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Repeat', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((entry) {
              final isActive = entry.key < 5;
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? Colors.purple.shade400 : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isActive ? null : Border.all(color: Colors.white24),
                ),
                child: Center(child: Text(entry.value, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontWeight: FontWeight.w600))),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(String label, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(time, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSmartAlarm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF252542), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Smart Alarm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Switch(value: true, onChanged: (v) {}, activeThumbColor: Colors.purple.shade300),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Wakes you during light sleep within your chosen window for a more refreshed feeling.', style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('30 min window', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w600))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepGoal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF252542), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 32),
              ),
              const SizedBox(width: 20),
              const Text('8h 0m', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(width: 20),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add_circle_outline, color: Colors.purple, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 10),
                Text('You\'re meeting your goal 5/7 days this week!', style: TextStyle(color: Colors.green, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepScorePainter extends CustomPainter {
  final double score;
  _SleepScorePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    
    final bgPaint = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [Colors.purple.shade300, Colors.cyan],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * score, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: const Color(0xFF1A1A2E), child: tabBar);
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
