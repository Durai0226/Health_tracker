import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../../core/services/storage_service.dart';
import 'focus_mode_screen.dart';

/// Focus Dashboard - Forest/Todoist-style productivity tracking
/// Features: Today's focus time, weekly progress, activity breakdown, history
class FocusDashboardScreen extends StatefulWidget {
  const FocusDashboardScreen({super.key});

  @override
  State<FocusDashboardScreen> createState() => _FocusDashboardScreenState();
}

class _FocusDashboardScreenState extends State<FocusDashboardScreen> {
  final FocusModeService _focusService = FocusModeService();
  bool _isLoading = true;
  
  // Stats
  int _todayMinutes = 0;
  int _weekMinutes = 0;
  int _totalSessions = 0;
  int _weeklyGoal = 300; // 5 hours default
  List<Map<String, dynamic>> _recentSessions = [];
  
  final List<Map<String, dynamic>> _activities = [
    {'id': 'reading', 'name': 'Reading', 'icon': Icons.menu_book_rounded, 'color': AppColors.primary},
    {'id': 'studying', 'name': 'Studying', 'icon': Icons.school_rounded, 'color': AppColors.info},
    {'id': 'working', 'name': 'Working', 'icon': Icons.work_rounded, 'color': AppColors.warning},
    {'id': 'meditating', 'name': 'Meditating', 'icon': Icons.self_improvement_rounded, 'color': AppColors.success},
    {'id': 'writing', 'name': 'Writing', 'icon': Icons.edit_rounded, 'color': AppColors.error},
    {'id': 'coding', 'name': 'Coding', 'icon': Icons.code_rounded, 'color': const Color(0xFF9C27B0)},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await _focusService.init();
      
      final prefs = StorageService.getAppPreferences();
      final today = _getTodayKey();
      
      if (mounted) {
        setState(() {
          _todayMinutes = prefs['focusTodayMinutes_$today'] ?? 0;
          _weekMinutes = prefs['focusWeekMinutes'] ?? 0;
          _totalSessions = prefs['focusTotalSessions'] ?? 0;
          _weeklyGoal = prefs['focusWeeklyGoalMinutes'] ?? 300;
          _recentSessions = _focusService.getRecentSessions();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading focus data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final weekProgress = _weeklyGoal > 0 ? (_weekMinutes / _weeklyGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildTodayCard(),
                        const SizedBox(height: 20),
                        _buildWeeklyGoalCard(weekProgress),
                        const SizedBox(height: 20),
                        _buildQuickStartButtons(),
                        const SizedBox(height: 20),
                        _buildWeeklyChart(),
                        const SizedBox(height: 20),
                        _buildActivityBreakdown(),
                        const SizedBox(height: 20),
                        _buildRecentSessions(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startFocusSession,
        backgroundColor: AppColors.success,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: const Text('Start Focus', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.success,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: _showGoalDialog,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Focus Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: 50,
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 50,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.timer_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Focus',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatMinutes(_todayMinutes),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Tree/plant icon (Forest-style)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _todayMinutes >= 60 ? Icons.park : Icons.eco,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniStat('Sessions', '$_totalSessions', Icons.repeat),
              const SizedBox(width: 16),
              _buildMiniStat('This Week', _formatMinutes(_weekMinutes), Icons.calendar_today),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyGoalCard(double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Weekly Goal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1 ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatMinutes(_weekMinutes)} of ${_formatMinutes(_weeklyGoal)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Start',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];
                return GestureDetector(
                  onTap: () => _startFocusWithActivity(activity['id'] as String),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (activity['color'] as Color).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (activity['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activity['icon'] as IconData,
                            color: activity['color'] as Color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activity['name'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final isToday = index + 1 == today;
                final isPast = index + 1 < today;
                // Placeholder data - would come from analytics
                final minutes = isToday ? _todayMinutes : (isPast ? 30 + (index * 10) : 0);
                final height = (minutes / 120).clamp(0.1, 1.0) * 80;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (minutes > 0)
                      Text(
                        '${minutes}m',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.success
                            : (isPast ? AppColors.success.withOpacity(0.5) : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[index],
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? AppColors.success : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBreakdown() {
    // Calculate activity breakdown from recent sessions
    final breakdown = <String, int>{};
    for (final session in _recentSessions) {
      final activity = session['activity'] as String? ?? 'other';
      final minutes = session['minutes'] as int? ?? 0;
      breakdown[activity] = (breakdown[activity] ?? 0) + minutes;
    }

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...breakdown.entries.map((entry) {
            final activity = _activities.firstWhere(
              (a) => a['id'] == entry.key,
              orElse: () => {'name': entry.key, 'color': AppColors.textSecondary, 'icon': Icons.circle},
            );
            final total = breakdown.values.fold(0, (a, b) => a + b);
            final percentage = total > 0 ? entry.value / total : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    activity['icon'] as IconData,
                    color: activity['color'] as Color,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              activity['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              _formatMinutes(entry.value),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(activity['color'] as Color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentSessions() {
    if (_recentSessions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'No focus sessions yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a session to track your focus time',
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Sessions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._recentSessions.take(5).map((session) {
            final activity = _activities.firstWhere(
              (a) => a['id'] == session['activity'],
              orElse: () => {'name': 'Focus', 'color': AppColors.success, 'icon': Icons.timer},
            );
            final date = DateTime.tryParse(session['date'] ?? '');
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (activity['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      color: activity['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          date != null ? _formatDate(date) : 'Recently',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${session['minutes']} min',
                    style: TextStyle(
                      color: activity['color'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today';
    }
    if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}';
  }

  void _startFocusSession() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FocusModeScreen()),
    ).then((_) => _loadData());
  }

  void _startFocusWithActivity(String activityId) {
    _focusService.setActivity(activityId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FocusModeScreen()),
    ).then((_) => _loadData());
  }

  void _showGoalDialog() {
    int newGoal = _weeklyGoal;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Weekly Focus Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setModalState(() {
                      newGoal = (newGoal - 60).clamp(60, 1200);
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 36,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 24),
                  Text(
                    _formatMinutes(newGoal),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: () => setModalState(() {
                      newGoal = (newGoal + 60).clamp(60, 1200);
                    }),
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 36,
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await StorageService.setAppPreference('focusWeeklyGoalMinutes', newGoal);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}
