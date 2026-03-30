import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_entry.dart';
import '../models/mood_streak.dart';
import '../models/quick_mood_level.dart';
import '../services/mood_firestore_service.dart';
import '../widgets/bloom_glass_container.dart';
import '../widgets/mood_level_selector.dart';
import '../widgets/days_together_card.dart';
import '../breathing/widgets/breathing_exercise_card.dart';
import '../breathing/screens/bloom_breath_list_screen.dart';
import 'bloom_mood_entry_screen.dart';

/// Home screen for Mood Tracker matching Behance design
/// Shows: greeting, calendar strip, mood selector, days together, daily breath, quote
class BloomMoodHomeScreen extends StatefulWidget {
  final String? userName;

  const BloomMoodHomeScreen({
    super.key,
    this.userName,
  });

  @override
  State<BloomMoodHomeScreen> createState() => _BloomMoodHomeScreenState();
}

class _BloomMoodHomeScreenState extends State<BloomMoodHomeScreen>
    with TickerProviderStateMixin {
  final MoodFirestoreService _firestoreService = MoodFirestoreService();

  // Data
  MoodStreak _streak = MoodStreak();
  List<MoodEntry> _todayEntries = [];
  List<MoodEntry> _weekEntries = [];
  bool _isLoading = true;
  QuickMoodLevel? _selectedMood;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final streak = await _firestoreService.getStreak();
      final todayEntries = await _firestoreService.getTodayEntries();
      final weekEntries = await _firestoreService.getWeekEntries();

      setState(() {
        _streak = streak;
        _todayEntries = todayEntries;
        _weekEntries = weekEntries;
        _isLoading = false;
        
        // Set selected mood if there's a today entry
        if (_todayEntries.isNotEmpty) {
          _selectedMood = QuickMoodLevel.fromMoodType(_todayEntries.first.mood);
        }
      });

      _fadeController.forward();
    } catch (e) {
      debugPrint('Error loading mood data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onMoodSelected(QuickMoodLevel level) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedMood = level);
    
    // Navigate to entry screen with selected mood
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloomMoodEntryScreen(
          initialMood: level.toMoodType,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToBreathing() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BloomBreathListScreen(),
      ),
    );
  }

  String get _displayName {
    return widget.userName ?? 'Emma';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: MoodTheme.background,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: MoodTheme.primary,
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: MoodTheme.primary,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // Header with greeting
                        SliverToBoxAdapter(child: _buildHeader()),

                        // Weekly calendar strip
                        SliverToBoxAdapter(child: _buildWeeklyCalendar()),

                        // Quote card
                        SliverToBoxAdapter(child: _buildQuoteCard()),

                        // Mood check-in section
                        SliverToBoxAdapter(child: _buildMoodCheckIn()),

                        // Stats row: Days Together + Daily Breath
                        SliverToBoxAdapter(child: _buildStatsRow()),

                        // Bottom padding
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MoodTheme.spacingLg,
        MoodTheme.spacingLg,
        MoodTheme.spacingLg,
        MoodTheme.spacingMd,
      ),
      child: Text(
        'Hello $_displayName',
        style: MoodTheme.headingLg.copyWith(
          color: MoodTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildWeeklyCalendar() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = startOfWeek.add(Duration(days: index));
          final isToday = date.day == now.day && 
              date.month == now.month && 
              date.year == now.year;
          final entry = _weekEntries.where((e) =>
              e.timestamp.year == date.year &&
              e.timestamp.month == date.month &&
              e.timestamp.day == date.day).firstOrNull;

          return _WeekDayCell(
            dayName: dayNames[index],
            date: date.day,
            isToday: isToday,
            mood: entry != null ? QuickMoodLevel.fromMoodType(entry.mood) : null,
          );
        }),
      ),
    );
  }

  Widget _buildQuoteCard() {
    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Container(
        padding: const EdgeInsets.all(MoodTheme.spacingLg),
        decoration: BoxDecoration(
          color: MoodTheme.purple50,
          borderRadius: MoodTheme.borderRadiusLg,
        ),
        child: Column(
          children: [
            Text(
              '❝',
              style: TextStyle(
                fontSize: 32,
                color: MoodTheme.purple300,
                height: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The only way to do great work is to love what you do.',
              style: MoodTheme.bodyLg.copyWith(
                color: MoodTheme.textPrimary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Steve Jobs',
              style: MoodTheme.titleSm.copyWith(
                color: MoodTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodCheckIn() {
    final hasTodayEntry = _todayEntries.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      child: BloomGlassContainer(
        padding: const EdgeInsets.all(MoodTheme.spacingLg),
        child: Column(
          children: [
            // Animated emoji
            if (hasTodayEntry && _selectedMood != null)
              MoodLevelDisplay(
                level: _selectedMood!,
                size: 64,
                animate: true,
              )
            else
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: const Text('😊', style: TextStyle(fontSize: 64)),
                  );
                },
              ),
            const SizedBox(height: 16),
            
            // Question
            Text(
              'How are you feeling today?',
              style: MoodTheme.titleLg.copyWith(
                color: MoodTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // 5-level mood selector
            MoodLevelSelector(
              selectedLevel: _selectedMood,
              onLevelSelected: _onMoodSelected,
              emojiSize: 48,
              showLabels: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use column layout on narrow screens
          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                DaysTogetherCompact(
                  dayCount: _streak.currentStreak > 0 ? _streak.currentStreak : 162,
                ),
                const SizedBox(height: MoodTheme.spacingMd),
                DailyBreathCardCompact(
                  onTap: _navigateToBreathing,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Days Together
              Expanded(
                flex: 1,
                child: DaysTogetherCompact(
                  dayCount: _streak.currentStreak > 0 ? _streak.currentStreak : 162,
                ),
              ),
              const SizedBox(width: MoodTheme.spacingSm),
              
              // Daily Breath
              Expanded(
                flex: 2,
                child: DailyBreathCardCompact(
                  onTap: _navigateToBreathing,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Weekly calendar day cell
class _WeekDayCell extends StatelessWidget {
  final String dayName;
  final int date;
  final bool isToday;
  final QuickMoodLevel? mood;

  const _WeekDayCell({
    required this.dayName,
    required this.date,
    required this.isToday,
    this.mood,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          dayName,
          style: MoodTheme.caption.copyWith(
            color: MoodTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isToday 
                ? MoodTheme.purple100 
                : (mood != null ? MoodTheme.purple50 : Colors.transparent),
            borderRadius: MoodTheme.borderRadiusSm,
            border: isToday 
                ? Border.all(color: MoodTheme.purple400, width: 2) 
                : null,
          ),
          child: Center(
            child: mood != null
                ? Text(mood!.emoji, style: const TextStyle(fontSize: 20))
                : Text(
                    '$date',
                    style: MoodTheme.titleSm.copyWith(
                      color: isToday ? MoodTheme.purple600 : MoodTheme.textSecondary,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
