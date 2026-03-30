import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_entry.dart';
import '../models/mood_insight.dart';
import '../services/mood_firestore_service.dart';
import '../widgets/mood_calendar_day.dart';
import 'bloom_mood_entry_screen.dart';

/// Calendar screen for viewing mood history
class BloomMoodCalendarScreen extends StatefulWidget {
  const BloomMoodCalendarScreen({super.key});

  @override
  State<BloomMoodCalendarScreen> createState() =>
      _BloomMoodCalendarScreenState();
}

class _BloomMoodCalendarScreenState extends State<BloomMoodCalendarScreen> {
  final MoodFirestoreService _firestoreService = MoodFirestoreService();

  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  Map<String, DailyMoodSummary> _summaries = {};
  List<MoodEntry> _selectedDayEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);

    try {
      final summaries = await _firestoreService.getDailySummaries(
        _currentMonth.year,
        _currentMonth.month,
      );

      setState(() {
        _summaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading calendar data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDayEntries(DateTime date) async {
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final entries = await _firestoreService.getEntriesInRange(start, end);

      setState(() {
        _selectedDate = date;
        _selectedDayEntries = entries;
      });

      if (entries.isNotEmpty) {
        _showDayDetailSheet();
      }
    } catch (e) {
      debugPrint('Error loading day entries: $e');
    }
  }

  void _previousMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
      );
    });
    _loadMonthData();
  }

  void _nextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
      );
    });
    _loadMonthData();
  }

  void _showDayDetailSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayDetailSheet(
        date: _selectedDate!,
        entries: _selectedDayEntries,
        onAddEntry: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BloomMoodEntryScreen(),
            ),
          ).then((_) => _loadMonthData());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: MoodTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            'Mood Calendar',
            style: MoodTheme.headingSm,
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Calendar header
            MoodCalendarHeader(
              currentMonth: _currentMonth,
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
            ),

            // Weekday labels
            const MoodCalendarWeekdays(),

            // Calendar grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: MoodTheme.primary,
                      ),
                    )
                  : _buildCalendarGrid(),
            ),

            // Legend
            const Padding(
              padding: EdgeInsets.all(MoodTheme.spacingMd),
              child: MoodCalendarLegend(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;
    
    // Calculate total cells needed (including padding days)
    final leadingDays = firstWeekday - 1;
    final totalDays = leadingDays + daysInMonth;
    final rows = (totalDays / 7).ceil();

    final now = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingMd),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNumber = index - leadingDays + 1;
        
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final summary = _summaries[dateKey];
        final isToday = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
        final isSelected = _selectedDate != null &&
            date.year == _selectedDate!.year &&
            date.month == _selectedDate!.month &&
            date.day == _selectedDate!.day;

        return MoodCalendarDay(
          date: date,
          summary: summary,
          isToday: isToday,
          isSelected: isSelected,
          isCurrentMonth: true,
          onTap: () => _loadDayEntries(date),
        );
      },
    );
  }
}

/// Bottom sheet showing day details
class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<MoodEntry> entries;
  final VoidCallback onAddEntry;

  const _DayDetailSheet({
    required this.date,
    required this.entries,
    required this.onAddEntry,
  });

  String get _formattedDate {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: MoodTheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MoodTheme.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: MoodTheme.spacingMd),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MoodTheme.textMuted.withOpacity(0.3),
              borderRadius: MoodTheme.borderRadiusRound,
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(MoodTheme.spacingLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formattedDate,
                      style: MoodTheme.headingSm,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                      style: MoodTheme.bodyMd.copyWith(
                        color: MoodTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: onAddEntry,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MoodTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Entries list
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(MoodTheme.spacingXl),
              child: Column(
                children: [
                  const Text('😶', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: MoodTheme.spacingMd),
                  Text(
                    'No mood entries for this day',
                    style: MoodTheme.bodyMd.copyWith(
                      color: MoodTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(MoodTheme.spacingMd),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return _EntryListItem(entry: entries[index]);
                },
              ),
            ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _EntryListItem extends StatelessWidget {
  final MoodEntry entry;

  const _EntryListItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodTheme.getMoodColor(entry.mood.value);

    return Container(
      margin: const EdgeInsets.only(bottom: MoodTheme.spacingSm),
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: moodColor.withOpacity(0.08),
        borderRadius: MoodTheme.borderRadiusMd,
        border: Border.all(
          color: moodColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Emoji
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: moodColor.withOpacity(0.15),
                  borderRadius: MoodTheme.borderRadiusSm,
                ),
                child: Center(
                  child: Text(
                    entry.mood.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: MoodTheme.spacingMd),

              // Mood and time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.mood.label,
                      style: MoodTheme.titleMd.copyWith(
                        color: moodColor,
                      ),
                    ),
                    Text(
                      entry.formattedTime,
                      style: MoodTheme.caption.copyWith(
                        color: MoodTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Intensity
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: moodColor.withOpacity(0.15),
                  borderRadius: MoodTheme.borderRadiusRound,
                ),
                child: Text(
                  '${entry.intensity}/5',
                  style: MoodTheme.titleSm.copyWith(
                    color: moodColor,
                  ),
                ),
              ),
            ],
          ),

          // Note
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: MoodTheme.spacingSm),
            Text(
              entry.note!,
              style: MoodTheme.bodyMd.copyWith(
                color: MoodTheme.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Activities
          if (entry.activities.isNotEmpty) ...[
            const SizedBox(height: MoodTheme.spacingSm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.activities.take(4).map((activity) {
                final activityColor =
                    MoodTheme.activityColors[activity.value] ?? moodColor;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activityColor.withOpacity(0.1),
                    borderRadius: MoodTheme.borderRadiusSm,
                  ),
                  child: Text(
                    activity.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: activityColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
