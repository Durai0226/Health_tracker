import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/habit_service.dart';
import '../theme/habit_theme.dart';
import 'create_habit_screen.dart';

/// Habit Detail Screen
/// Shows habit statistics, calendar, and tools
class HabitDetailScreen extends StatefulWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final HabitService _habitService = HabitService();
  
  late Habit _habit;
  bool _isWeekView = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      body: ListenableBuilder(
        listenable: _habitService,
        builder: (context, _) {
          // Refresh habit data
          final updatedHabit = _habitService.getHabit(_habit.id);
          if (updatedHabit != null) _habit = updatedHabit;
          
          return CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildCalendarSection()),
              SliverToBoxAdapter(child: _buildStatisticsSection()),
              SliverToBoxAdapter(child: _buildToolsSection()),
              SliverToBoxAdapter(child: _buildActionsSection()),
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    final streak = _habitService.getStreak(_habit.id);
    
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _habit.color,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: HabitTheme.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.note_outlined, color: HabitTheme.white),
          onPressed: _showAddNoteDialog,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: HabitTheme.white),
          onPressed: _navigateToEdit,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: HabitTheme.white),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _habit.isPaused ? 'continue' : 'pause',
              child: Row(
                children: [
                  Icon(
                    _habit.isPaused ? Icons.play_arrow : Icons.pause,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(_habit.isPaused ? 'Continue' : 'Pause'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Archive'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 12),
                  Text('Reset'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_habit.color, _habit.color.withOpacity(0.8)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: HabitTheme.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _habit.icon,
                      color: HabitTheme.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _habit.name,
                          style: HabitTheme.h1.copyWith(color: HabitTheme.white),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: HabitTheme.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${streak.currentStreak} day streak',
                              style: HabitTheme.b3.copyWith(
                                color: HabitTheme.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                _formatMonth(_selectedMonth),
                style: HabitTheme.h2,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Calendar grid
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: HabitTheme.dayLabelsShort.map((day) {
            return SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  day,
                  style: HabitTheme.caption.copyWith(
                    color: HabitTheme.gray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Days grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 42, // 6 weeks
          itemBuilder: (context, index) {
            final dayOffset = index - (startWeekday - 1);
            if (dayOffset < 1 || dayOffset > daysInMonth) {
              return const SizedBox();
            }

            final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayOffset);
            final isCompleted = _habitService.isHabitCompletedForDate(_habit.id, date);
            final isToday = _isSameDay(date, DateTime.now());
            final isFuture = date.isAfter(DateTime.now());

            return Container(
              decoration: BoxDecoration(
                color: isCompleted
                    ? _habit.color
                    : isToday
                        ? _habit.color.withOpacity(0.15)
                        : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$dayOffset',
                  style: HabitTheme.b3.copyWith(
                    color: isCompleted
                        ? HabitTheme.white
                        : isFuture
                            ? HabitTheme.gray
                            : HabitTheme.dark,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    final streak = _habitService.getStreak(_habit.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  _buildViewToggle('Week', _isWeekView, () {
                    setState(() => _isWeekView = true);
                  }),
                  const SizedBox(width: 8),
                  _buildViewToggle('Month', !_isWeekView, () {
                    setState(() => _isWeekView = false);
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              _buildStatCard(
                '${streak.currentStreak}',
                'Current\nStreak',
                Icons.local_fire_department,
                HabitTheme.warning,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                '${streak.bestStreak}',
                'Best\nStreak',
                Icons.emoji_events,
                HabitTheme.categoryExercise,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                '${streak.completionPercentage}%',
                'Completion\nRate',
                Icons.pie_chart,
                HabitTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Weekly chart placeholder
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: HabitTheme.grayLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(HabitTheme.radiusM),
            ),
            child: Center(
              child: Text(
                'Completion chart',
                style: HabitTheme.b3.copyWith(color: HabitTheme.gray),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(String label, bool isSelected, VoidCallback onTap) {
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

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(HabitTheme.radiusM),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: HabitTheme.h2.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: HabitTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tools', style: HabitTheme.h2),
          const SizedBox(height: 16),
          _buildToolItem(
            Icons.photo_camera_outlined,
            'Photo',
            'Add photos to make your journey more visually motivated',
            HabitTheme.categoryCreative,
          ),
          _buildToolItem(
            Icons.directions_walk,
            'Step Counter',
            'Sync to Google Fit to track your activities',
            HabitTheme.categoryExercise,
          ),
          _buildToolItem(
            Icons.local_fire_department,
            'Calories burn',
            'Sync to Google Fit to track your activities',
            HabitTheme.error,
          ),
          _buildToolItem(
            Icons.mood,
            'Mood tracker',
            'Record your moods to balance your mental health & self care',
            HabitTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HabitTheme.b1.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  style: HabitTheme.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: HabitTheme.primary),
            onPressed: () {
              // Add tool
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_habit.isPaused)
            _buildActionButton(
              'Continue Habit',
              Icons.play_arrow,
              HabitTheme.success,
              () => _handleMenuAction('continue'),
            ),
          _buildActionButton(
            'Take a day off',
            Icons.event_busy,
            HabitTheme.gray,
            _showTakeDayOffDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HabitTheme.white,
          borderRadius: BorderRadius.circular(HabitTheme.radiusL),
          boxShadow: HabitTheme.subtleShadow,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(label, style: HabitTheme.b1),
            const Spacer(),
            const Icon(Icons.chevron_right, color: HabitTheme.gray),
          ],
        ),
      ),
    );
  }

  String _formatMonth(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _navigateToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateHabitScreen(existingHabit: _habit),
      ),
    );
  }

  void _showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Save note
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTakeDayOffDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take a day off'),
        content: const Text('Skip this habit for today without breaking your streak?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _habitService.logHabitCompletion(
                habitId: _habit.id,
                date: DateTime.now(),
                status: HabitLogStatus.skipped,
              );
              Navigator.pop(context);
            },
            child: const Text('Skip Today'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'pause':
      case 'continue':
        _habitService.togglePauseHabit(_habit.id);
        break;
      case 'archive':
        _habitService.toggleArchiveHabit(_habit.id);
        Navigator.pop(context);
        break;
      case 'reset':
        _showResetConfirmation();
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Habit'),
        content: const Text('This will clear all your progress and statistics. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HabitTheme.error),
            onPressed: () {
              // Reset habit stats
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: const Text('This action cannot be undone. Are you sure you want to delete this habit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HabitTheme.error),
            onPressed: () {
              _habitService.deleteHabit(_habit.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to dashboard
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
