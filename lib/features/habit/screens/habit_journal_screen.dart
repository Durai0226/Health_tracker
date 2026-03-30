import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/habit_service.dart';
import '../theme/habit_theme.dart';

/// Journal/Statistics Screen
/// Shows process overview, all habits, and detailed statistics
class HabitJournalScreen extends StatefulWidget {
  const HabitJournalScreen({super.key});

  @override
  State<HabitJournalScreen> createState() => _HabitJournalScreenState();
}

class _HabitJournalScreenState extends State<HabitJournalScreen>
    with SingleTickerProviderStateMixin {
  final HabitService _habitService = HabitService();
  
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  bool _isWeekView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.white,
        elevation: 0,
        title: Text('Journal', style: HabitTheme.h1),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: HabitTheme.primary,
          unselectedLabelColor: HabitTheme.gray,
          indicatorColor: HabitTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: HabitTheme.label,
          tabs: const [
            Tab(text: 'PROCESS'),
            Tab(text: 'ALL HABITS'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _habitService,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildProcessTab(),
              _buildAllHabitsTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProcessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week calendar with completion indicators
          _buildWeekCalendar(),
          const SizedBox(height: 24),
          // Statistics section
          _buildStatisticsSection(),
          const SizedBox(height: 24),
          // Streak card
          _buildStreakCard(),
          const SizedBox(height: 24),
          // Calendar overview
          _buildCalendarOverview(),
          const SizedBox(height: 24),
          // Completion comparison
          _buildCompletionComparison(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        children: [
          // Week header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final summary = _habitService.getDailySummary(date);
              final isToday = _isSameDay(date, today);
              
              return Column(
                children: [
                  Text(
                    HabitTheme.dayLabelsFull[index],
                    style: HabitTheme.caption.copyWith(
                      color: isToday ? HabitTheme.primary : HabitTheme.gray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isToday ? HabitTheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: summary.isAllCompleted && !isToday
                          ? Border.all(color: HabitTheme.success, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: HabitTheme.b2.copyWith(
                          color: isToday ? HabitTheme.white : HabitTheme.dark,
                          fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Completion indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (summary.completedHabits > 0)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: summary.isAllCompleted
                                ? HabitTheme.success
                                : HabitTheme.primary.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final stats = _habitService.getOverallStats();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Statistics', style: HabitTheme.h2),
              Row(
                children: [
                  _buildToggleButton('Week', _isWeekView, () {
                    setState(() => _isWeekView = true);
                  }),
                  const SizedBox(width: 8),
                  _buildToggleButton('Month', !_isWeekView, () {
                    setState(() => _isWeekView = false);
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Month/Week selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    if (_isWeekView) {
                      _selectedMonth = _selectedMonth.subtract(const Duration(days: 7));
                    } else {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                    }
                  });
                },
              ),
              Text(
                _isWeekView
                    ? _formatWeekRange(_selectedMonth)
                    : _formatMonth(_selectedMonth),
                style: HabitTheme.b1.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    if (_isWeekView) {
                      _selectedMonth = _selectedMonth.add(const Duration(days: 7));
                    } else {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Completion rate
          Row(
            children: [
              Text(
                '${_isWeekView ? stats.weeklyPercentage : stats.monthlyPercentage}%',
                style: HabitTheme.h1.copyWith(
                  color: HabitTheme.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Avg. completion rate',
                style: HabitTheme.b3,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bar chart
          _buildCompletionChart(),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? HabitTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
          border: Border.all(
            color: isSelected ? HabitTheme.primary : HabitTheme.grayLight,
          ),
        ),
        child: Text(
          label,
          style: HabitTheme.caption.copyWith(
            color: isSelected ? HabitTheme.white : HabitTheme.gray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionChart() {
    final chartData = _habitService.getWeeklyChartData();
    final maxHeight = 80.0;
    
    return SizedBox(
      height: maxHeight + 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chartData.map((data) {
          final rate = data['rate'] as double;
          final height = rate * maxHeight;
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: HabitTheme.animationMedium,
                width: 24,
                height: height.clamp(4.0, maxHeight),
                decoration: BoxDecoration(
                  color: HabitTheme.primary.withOpacity(0.2 + rate * 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data['dayLabel'] as String,
                style: HabitTheme.caption,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStreakCard() {
    // Calculate overall streak
    int currentStreak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      final summary = _habitService.getDailySummary(date);
      if (summary.totalHabits > 0 && summary.isAllCompleted) {
        currentStreak++;
      } else if (i > 0) {
        break;
      }
    }

    // Find best streak (simplified)
    int bestStreak = currentStreak;
    for (final streak in _habitService.streaks.values) {
      if (streak.bestStreak > bestStreak) {
        bestStreak = streak.bestStreak;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: HabitTheme.primaryGradient,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: HabitTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Habit streak',
            style: HabitTheme.b2.copyWith(
              color: HabitTheme.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStreakItem('$currentStreak', 'Current\nStreak', true),
              Container(
                width: 1,
                height: 60,
                color: HabitTheme.white.withOpacity(0.3),
              ),
              _buildStreakItem('$bestStreak', 'Best\nStreak', false),
              Container(
                width: 1,
                height: 60,
                color: HabitTheme.white.withOpacity(0.3),
              ),
              _buildStreakItem(
                '${_habitService.getOverallStats().weeklyPercentage}%',
                'Completion\nRate',
                false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakItem(String value, String label, bool isMain) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isMain ? 36 : 24,
            fontWeight: FontWeight.w700,
            color: HabitTheme.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: HabitTheme.caption.copyWith(
            color: HabitTheme.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCalendarOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calendar overview', style: HabitTheme.h2),
          const SizedBox(height: 16),
          _buildMiniCalendar(),
        ],
      ),
    );
  }

  Widget _buildMiniCalendar() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    return Column(
      children: [
        // Month header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                });
              },
            ),
            Text(_formatMonth(_selectedMonth), style: HabitTheme.b1),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: HabitTheme.dayLabelsShort.map((day) {
            return SizedBox(
              width: 28,
              child: Center(
                child: Text(day, style: HabitTheme.caption),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // Days grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final dayOffset = index - (startWeekday - 1);
            if (dayOffset < 1 || dayOffset > daysInMonth) {
              return const SizedBox();
            }

            final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayOffset);
            final summary = _habitService.getDailySummary(date);
            final isToday = _isSameDay(date, DateTime.now());

            Color? dotColor;
            if (summary.totalHabits > 0) {
              if (summary.isAllCompleted) {
                dotColor = HabitTheme.success;
              } else if (summary.completedHabits > 0) {
                dotColor = HabitTheme.primary.withOpacity(0.5);
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: isToday ? HabitTheme.primary.withOpacity(0.1) : null,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$dayOffset',
                    style: HabitTheme.caption.copyWith(
                      color: isToday ? HabitTheme.primary : HabitTheme.dark,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 11,
                    ),
                  ),
                  if (dotColor != null)
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompletionComparison() {
    final habits = _habitService.activeHabits;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Habit completion rate comparison', style: HabitTheme.h2),
          const SizedBox(height: 16),
          ...habits.take(5).map((habit) {
            final streak = _habitService.getStreak(habit.id);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: habit.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(habit.icon, color: habit.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit.name, style: HabitTheme.b2),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: streak.completionRate,
                          backgroundColor: HabitTheme.grayLight,
                          valueColor: AlwaysStoppedAnimation(habit.color),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${streak.completionPercentage}%',
                    style: HabitTheme.b2.copyWith(
                      color: habit.color,
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

  Widget _buildAllHabitsTab() {
    final activeHabits = _habitService.activeHabits;
    final archivedHabits = _habitService.archivedHabits;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HabitTheme.grayLight,
              borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
            ),
            child: TabBar(
              labelColor: HabitTheme.dark,
              unselectedLabelColor: HabitTheme.gray,
              indicator: BoxDecoration(
                color: HabitTheme.white,
                borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                boxShadow: HabitTheme.subtleShadow,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Active (${activeHabits.length})'),
                Tab(text: 'Archived (${archivedHabits.length})'),
                const Tab(text: 'Tags'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHabitList(activeHabits),
                _buildHabitList(archivedHabits),
                _buildTagsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitList(List<Habit> habits) {
    if (habits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: HabitTheme.grayLight),
            const SizedBox(height: 16),
            Text('No habits', style: HabitTheme.b1.copyWith(color: HabitTheme.gray)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final streak = _habitService.getStreak(habit.id);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HabitTheme.white,
            borderRadius: BorderRadius.circular(HabitTheme.radiusL),
            boxShadow: HabitTheme.subtleShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(habit.icon, color: habit.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: HabitTheme.b1.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      habit.repeatDescription,
                      style: HabitTheme.description,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${streak.currentStreak}🔥',
                    style: HabitTheme.b2.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${streak.completionPercentage}%',
                    style: HabitTheme.caption.copyWith(color: habit.color),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagsView() {
    final groups = _habitService.groups.where((g) => g.id != 'all').toList();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final habitsInGroup = _habitService.getHabitsByGroup(group.id);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HabitTheme.white,
            borderRadius: BorderRadius.circular(HabitTheme.radiusL),
            boxShadow: HabitTheme.subtleShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: group.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(group.icon, color: group.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(group.name, style: HabitTheme.b1),
              ),
              Text(
                '${habitsInGroup.length} habits',
                style: HabitTheme.description,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: HabitTheme.gray),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMonth(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatWeekRange(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}';
  }
}
