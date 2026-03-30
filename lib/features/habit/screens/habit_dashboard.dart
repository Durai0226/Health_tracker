import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/habit_service.dart';
import '../theme/habit_theme.dart';
import '../widgets/week_selector.dart';
import '../widgets/habit_card.dart';
import '../widgets/progress_header.dart';
import 'create_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_journal_screen.dart';

/// Main Habit Dashboard Screen
/// Matches the Habit Land home screen design
class HabitDashboard extends StatefulWidget {
  const HabitDashboard({super.key});

  @override
  State<HabitDashboard> createState() => _HabitDashboardState();
}

class _HabitDashboardState extends State<HabitDashboard>
    with TickerProviderStateMixin {
  final HabitService _habitService = HabitService();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isHabitsTab = true;
  String _selectedGroupId = 'all';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initService();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: HabitTheme.animationMedium,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  Future<void> _initService() async {
    await _habitService.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ListenableBuilder(
            listenable: _habitService,
            builder: (context, _) {
              return CustomScrollView(
                slivers: [
                  // Header with date
                  _buildHeader(),
                  // Week selector
                  SliverToBoxAdapter(child: _buildWeekSelector()),
                  // Progress card
                  SliverToBoxAdapter(child: _buildProgressCard()),
                  // Tabs toggle
                  SliverToBoxAdapter(child: _buildTabsAndFilter()),
                  // Habits/Tasks list
                  _isHabitsTab ? _buildHabitsList() : _buildTasksList(),
                  // Bottom padding
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () {
                // Navigate to character/profile
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: HabitTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HabitTheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: HabitTheme.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: HabitTheme.h1,
                  ),
                  Text(
                    _formatDate(_habitService.selectedDate),
                    style: HabitTheme.description,
                  ),
                ],
              ),
            ),
            // Add button
            GestureDetector(
              onTap: _navigateToCreateHabit,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HabitTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HabitTheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: HabitTheme.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    return WeekSelector(
      selectedDate: _habitService.selectedDate,
      onDateSelected: (date) {
        _habitService.setSelectedDate(date);
      },
    );
  }

  Widget _buildProgressCard() {
    final summary = _habitService.getDailySummary(_habitService.selectedDate);
    final tasksForDay = _habitService.getTasksForDate(_habitService.selectedDate);
    final completedTasks = tasksForDay.where((t) => t.isCompleted).length;

    return ProgressHeader(
      completedHabits: summary.completedHabits,
      totalHabits: summary.totalHabits,
      completedTasks: completedTasks,
      totalTasks: tasksForDay.length,
      completionPercentage: summary.completionPercentage,
    );
  }

  Widget _buildTabsAndFilter() {
    final groups = [
      (id: 'all', name: 'All'),
      ..._habitService.groups
          .where((g) => g.id != 'all')
          .map((g) => (id: g.id, name: g.name)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          HabitTaskToggle(
            isHabitsSelected: _isHabitsTab,
            onChanged: (isHabits) {
              HapticFeedback.lightImpact();
              setState(() => _isHabitsTab = isHabits);
            },
          ),
          const Spacer(),
          CategoryFilter(
            selectedGroupId: _selectedGroupId,
            groups: groups,
            onChanged: (groupId) {
              setState(() => _selectedGroupId = groupId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList() {
    final habits = _habitService.getHabitsForDate(_habitService.selectedDate);
    final filteredHabits = _selectedGroupId == 'all'
        ? habits
        : habits.where((h) => h.groupId == _selectedGroupId).toList();

    if (filteredHabits.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    // Group by time of day
    final groupedHabits = <HabitTimeOfDay, List<Habit>>{};
    for (final timeOfDay in HabitTimeOfDay.values) {
      final habitsForTime = filteredHabits.where((h) => h.timeOfDay == timeOfDay).toList();
      if (habitsForTime.isNotEmpty) {
        groupedHabits[timeOfDay] = habitsForTime;
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          int currentIndex = 0;
          for (final entry in groupedHabits.entries) {
            // Section header
            if (currentIndex == index) {
              return _buildSectionHeader(entry.key);
            }
            currentIndex++;

            // Habits in section
            for (final habit in entry.value) {
              if (currentIndex == index) {
                final isCompleted = _habitService.isHabitCompletedForDate(
                  habit.id,
                  _habitService.selectedDate,
                );

                if (isCompleted) {
                  return CompletedHabitCard(
                    habit: habit,
                    subtitle: 'Finish',
                    onTap: () => _navigateToHabitDetail(habit),
                  );
                }

                return HabitCard(
                  habit: habit,
                  isCompleted: isCompleted,
                  onTap: () => _navigateToHabitDetail(habit),
                  onComplete: () => _toggleHabitCompletion(habit),
                );
              }
              currentIndex++;
            }
          }
          return null;
        },
        childCount: groupedHabits.entries.fold<int>(
          0,
          (sum, entry) => sum + 1 + entry.value.length,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(HabitTimeOfDay timeOfDay) {
    final label = switch (timeOfDay) {
      HabitTimeOfDay.anytime => 'ANYTIME',
      HabitTimeOfDay.morning => 'MORNING',
      HabitTimeOfDay.afternoon => 'AFTERNOON',
      HabitTimeOfDay.evening => 'EVENING',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: HabitTheme.caption.copyWith(
          color: HabitTheme.gray,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    final tasks = _habitService.getTasksForDate(_habitService.selectedDate);
    
    if (tasks.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState(isTask: true));
    }

    final incompleteTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < incompleteTasks.length) {
            return _buildTaskCard(incompleteTasks[index]);
          }
          
          if (index == incompleteTasks.length && completedTasks.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'COMPLETED',
                style: HabitTheme.caption.copyWith(
                  color: HabitTheme.gray,
                  letterSpacing: 1,
                ),
              ),
            );
          }

          final completedIndex = index - incompleteTasks.length - 1;
          if (completedIndex >= 0 && completedIndex < completedTasks.length) {
            return _buildTaskCard(completedTasks[completedIndex]);
          }

          return null;
        },
        childCount: incompleteTasks.length + 
            (completedTasks.isNotEmpty ? 1 : 0) + 
            completedTasks.length,
      ),
    );
  }

  Widget _buildTaskCard(HabitTask task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? task.color.withOpacity(0.15)
            : HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusL),
        border: Border.all(
          color: task.isCompleted
              ? task.color.withOpacity(0.3)
              : HabitTheme.grayLight,
        ),
        boxShadow: task.isCompleted ? null : HabitTheme.subtleShadow,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _habitService.toggleTaskComplete(task.id);
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.isCompleted ? task.color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.isCompleted ? task.color : HabitTheme.gray,
                  width: 2,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 14, color: HabitTheme.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.name,
              style: HabitTheme.b1.copyWith(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? HabitTheme.gray : HabitTheme.dark,
              ),
            ),
          ),
          if (task.dueTime != null)
            Text(
              task.dueTime!,
              style: HabitTheme.description,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({bool isTask = false}) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isTask ? Icons.task_alt : Icons.track_changes,
            size: 64,
            color: HabitTheme.grayLight,
          ),
          const SizedBox(height: 16),
          Text(
            isTask ? 'No tasks for today' : 'No habits scheduled',
            style: HabitTheme.b1.copyWith(color: HabitTheme.gray),
          ),
          const SizedBox(height: 8),
          Text(
            isTask
                ? 'Tap + to create a new task'
                : 'Start building good habits!',
            style: HabitTheme.description,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _navigateToCreateHabit,
      backgroundColor: HabitTheme.primary,
      elevation: 4,
      child: const Icon(Icons.add, color: HabitTheme.white),
    );
  }

  
  void _showStatsDialog() {
    final stats = _habitService.getOverallStats();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HabitTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.insights, color: HabitTheme.primary),
            const SizedBox(width: 8),
            Text('Your Progress', style: HabitTheme.h2),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Active Habits', '${stats.activeHabits}'),
            _buildStatRow('Completed Today', '${stats.completedToday}/${stats.scheduledToday}'),
            _buildStatRow('Weekly Rate', '${stats.weeklyPercentage}%'),
            _buildStatRow('Monthly Rate', '${stats.monthlyPercentage}%'),
            _buildStatRow('Current Streak', '${stats.currentOverallStreak} days'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitJournalScreen()));
            },
            child: Text('View Details', style: TextStyle(color: HabitTheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: HabitTheme.gray)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: HabitTheme.b2),
          Text(value, style: HabitTheme.label.copyWith(color: HabitTheme.primary)),
        ],
      ),
    );
  }
  
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HabitTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HabitTheme.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Habit Settings', style: HabitTheme.h2),
              const SizedBox(height: 20),
              _buildSettingsItem(Icons.category, 'Manage Groups', () {
                Navigator.pop(context);
                _showManageGroupsDialog();
              }),
              _buildSettingsItem(Icons.archive, 'Archived Habits', () {
                Navigator.pop(context);
                _showArchivedHabits();
              }),
              _buildSettingsItem(Icons.calendar_today, 'View Journal', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitJournalScreen()));
              }),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingsItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: HabitTheme.primary),
      title: Text(label, style: HabitTheme.b2),
      trailing: Icon(Icons.chevron_right, color: HabitTheme.gray),
      onTap: onTap,
    );
  }
  
  void _showManageGroupsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HabitTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Habit Groups', style: HabitTheme.h2),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _habitService.groups.length,
            itemBuilder: (context, index) {
              final group = _habitService.groups[index];
              return ListTile(
                leading: Icon(IconData(group.iconCodePoint, fontFamily: 'MaterialIcons'), 
                  color: Color(group.colorValue)),
                title: Text(group.name, style: HabitTheme.b2),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: HabitTheme.primary)),
          ),
        ],
      ),
    );
  }
  
  void _showArchivedHabits() {
    final archived = _habitService.archivedHabits;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HabitTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Archived Habits', style: HabitTheme.h2),
        content: archived.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No archived habits', style: HabitTheme.description),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: archived.length,
                  itemBuilder: (context, index) {
                    final habit = archived[index];
                    return ListTile(
                      leading: Icon(IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'), 
                        color: Color(habit.colorValue)),
                      title: Text(habit.name, style: HabitTheme.b2),
                      trailing: TextButton(
                        onPressed: () async {
                          final updated = habit.copyWith(isArchived: false);
                          await _habitService.updateHabit(updated);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text('Restore', style: TextStyle(color: HabitTheme.primary)),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: HabitTheme.primary)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _navigateToCreateHabit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateHabitScreen(),
      ),
    );
  }

  void _navigateToHabitDetail(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitDetailScreen(habit: habit),
      ),
    );
  }

  void _toggleHabitCompletion(Habit habit) {
    HapticFeedback.mediumImpact();
    _habitService.toggleHabitCompletion(
      habit.id,
      _habitService.selectedDate,
    );
  }
}
