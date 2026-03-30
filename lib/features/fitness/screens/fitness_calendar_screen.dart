import 'package:flutter/material.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../models/workout_session.dart';
import '../services/fitness_storage_service.dart';

class FitnessCalendarScreen extends StatefulWidget {
  const FitnessCalendarScreen({super.key});

  @override
  State<FitnessCalendarScreen> createState() => _FitnessCalendarScreenState();
}

class _FitnessCalendarScreenState extends State<FitnessCalendarScreen> {
  final FitnessStorageService _storage = FitnessStorageService();
  
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  Map<DateTime, List<WorkoutSession>> _sessionsByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    
    final sessions = await _storage.getAllSessions();
    final byDate = <DateTime, List<WorkoutSession>>{};
    
    for (final session in sessions) {
      final dateKey = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      byDate.putIfAbsent(dateKey, () => []).add(session);
    }

    if (mounted) {
      setState(() {
        _sessionsByDate = byDate;
        _isLoading = false;
      });
    }
  }

  List<WorkoutSession> get _selectedDateSessions {
    if (_selectedDate == null) return [];
    final dateKey = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    return _sessionsByDate[dateKey] ?? [];
  }

  int get _monthWorkouts {
    return _sessionsByDate.entries
        .where((e) => e.key.year == _selectedMonth.year && e.key.month == _selectedMonth.month)
        .fold(0, (sum, e) => sum + e.value.length);
  }

  int get _monthCalories {
    return _sessionsByDate.entries
        .where((e) => e.key.year == _selectedMonth.year && e.key.month == _selectedMonth.month)
        .fold(0, (sum, e) => sum + e.value.fold(0, (s, session) => s + session.caloriesBurned));
  }

  int get _monthMinutes {
    return _sessionsByDate.entries
        .where((e) => e.key.year == _selectedMonth.year && e.key.month == _selectedMonth.month)
        .fold(0, (sum, e) => sum + e.value.fold(0, (s, session) => s + (session.durationSeconds ~/ 60)));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: const Text('Workout Calendar', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FitnessTheme.primary))
            : Column(
                children: [
                  _buildMonthSelector(),
                  _buildMonthStats(),
                  _buildCalendar(),
                  if (_selectedDate != null) ...[
                    const Divider(color: FitnessTheme.surface, height: 1),
                    Expanded(child: _buildSelectedDateWorkouts()),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];

    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                _selectedDate = null;
              });
            },
          ),
          Text(
            '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
            style: FitnessTheme.titleLg,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final now = DateTime.now();
              if (_selectedMonth.year < now.year || 
                  (_selectedMonth.year == now.year && _selectedMonth.month < now.month)) {
                setState(() {
                  _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  _selectedDate = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingMd),
      child: FitnessCard(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(Icons.fitness_center, '$_monthWorkouts', 'Workouts', FitnessTheme.primary),
            _buildStatItem(Icons.local_fire_department, '$_monthCalories', 'Calories', FitnessTheme.warning),
            _buildStatItem(Icons.timer, '$_monthMinutes', 'Minutes', FitnessTheme.info),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: FitnessTheme.titleMd.copyWith(color: color)),
        Text(label, style: FitnessTheme.caption),
      ],
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startingWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(day, style: FitnessTheme.caption),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: FitnessTheme.spacingSm),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayOffset = index - (startingWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox.shrink();
              }

              final day = dayOffset + 1;
              final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final dateKey = DateTime(date.year, date.month, date.day);
              final hasWorkout = _sessionsByDate.containsKey(dateKey);
              final isToday = date.year == today.year && 
                              date.month == today.month && 
                              date.day == today.day;
              final isSelected = _selectedDate != null &&
                                 date.year == _selectedDate!.year &&
                                 date.month == _selectedDate!.month &&
                                 date.day == _selectedDate!.day;
              final isFuture = date.isAfter(today);

              return GestureDetector(
                onTap: isFuture ? null : () {
                  setState(() => _selectedDate = date);
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FitnessTheme.primary
                        : isToday
                            ? FitnessTheme.primary.withValues(alpha: 0.2)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: FitnessTheme.primary, width: 1)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: FitnessTheme.titleSm.copyWith(
                          color: isSelected
                              ? FitnessTheme.textOnPrimary
                              : isFuture
                                  ? FitnessTheme.textMuted
                                  : FitnessTheme.textPrimary,
                        ),
                      ),
                      if (hasWorkout && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: FitnessTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateWorkouts() {
    final sessions = _selectedDateSessions;
    
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: FitnessTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text(
              'No workouts on this day',
              style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.textMuted),
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              'Rest day or time to get moving!',
              style: FitnessTheme.bodySm,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return FitnessCard(
          margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: session.wasCompleted
                      ? FitnessTheme.success.withValues(alpha: 0.2)
                      : FitnessTheme.warning.withValues(alpha: 0.2),
                  borderRadius: FitnessTheme.borderRadiusSm,
                ),
                child: Icon(
                  session.wasCompleted ? Icons.check_circle : Icons.timer,
                  color: session.wasCompleted ? FitnessTheme.success : FitnessTheme.warning,
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.workoutName, style: FitnessTheme.titleSm),
                    Text(
                      _formatTime(session.startedAt),
                      style: FitnessTheme.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    session.formattedDuration,
                    style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.primary),
                  ),
                  Text('${session.caloriesBurned} cal', style: FitnessTheme.caption),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
}
