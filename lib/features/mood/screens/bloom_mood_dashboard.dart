import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_type.dart';
import '../models/mood_entry.dart';
import '../models/mood_streak.dart';
import '../models/mood_insight.dart';
import '../services/mood_firestore_service.dart';
import '../widgets/bloom_glass_container.dart';
import '../widgets/mood_emoji_widget.dart';
import '../widgets/mood_stats_card.dart';
import '../widgets/daily_quote_card.dart';
import 'bloom_mood_entry_screen.dart';
import 'bloom_mood_calendar_screen.dart';
import 'bloom_mood_insights_screen.dart';
import 'bloom_mood_settings_screen.dart';

/// Main dashboard for the Mood Tracker feature
/// Follows BloomFit/Behance iOS Wellness design
class BloomMoodDashboard extends StatefulWidget {
  const BloomMoodDashboard({super.key});

  @override
  State<BloomMoodDashboard> createState() => _BloomMoodDashboardState();
}

class _BloomMoodDashboardState extends State<BloomMoodDashboard>
    with TickerProviderStateMixin {
  final MoodFirestoreService _firestoreService = MoodFirestoreService();

  // Data
  MoodStreak _streak = MoodStreak();
  List<MoodEntry> _todayEntries = [];
  List<MoodEntry> _weekEntries = [];
  MoodInsight? _weeklyInsight;
  bool _isLoading = true;

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
      final weeklyInsight = await _firestoreService.getWeeklyInsight();

      setState(() {
        _streak = streak;
        _todayEntries = todayEntries;
        _weekEntries = weekEntries;
        _weeklyInsight = weeklyInsight;
        _isLoading = false;
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

  void _navigateToEntry() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BloomMoodEntryScreen(),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BloomMoodCalendarScreen(),
      ),
    );
  }

  void _navigateToInsights() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BloomMoodInsightsScreen(),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BloomMoodSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: MoodTheme.background,
        body: Stack(
          children: [
            // Background gradient
            _buildBackground(),

            // Content
            SafeArea(
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
                            // Header
                            SliverToBoxAdapter(child: _buildHeader()),

                            // Today's mood section
                            SliverToBoxAdapter(child: _buildTodayMoodSection()),

                            // Quick actions
                            SliverToBoxAdapter(child: _buildQuickActions()),

                            // Streak card
                            SliverToBoxAdapter(child: _buildStreakSection()),

                            // Weekly mini calendar
                            SliverToBoxAdapter(child: _buildWeeklyCalendar()),

                            // Stats grid
                            SliverToBoxAdapter(child: _buildStatsGrid()),

                            // Daily quote
                            SliverToBoxAdapter(child: _buildDailyQuote()),

                            // Recent entries
                            SliverToBoxAdapter(child: _buildRecentEntries()),

                            // Bottom padding
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 100),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MoodTheme.primarySoft.withOpacity(0.3),
              MoodTheme.background,
              MoodTheme.background,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MoodTheme.spacingLg,
        MoodTheme.spacingMd,
        MoodTheme.spacingLg,
        MoodTheme.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: MoodTheme.bodyMd.copyWith(
                  color: MoodTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mood Tracker',
                style: MoodTheme.headingLg.copyWith(
                  color: MoodTheme.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildIconButton(
                icon: Icons.calendar_month_rounded,
                onTap: _navigateToCalendar,
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.settings_rounded,
                onTap: _navigateToSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: MoodTheme.borderRadiusMd,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Icon(
          icon,
          color: MoodTheme.textPrimary,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTodayMoodSection() {
    final hasTodayEntry = _todayEntries.isNotEmpty;
    final latestMood = hasTodayEntry ? _todayEntries.first.mood : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      child: BloomGlassContainer(
        padding: const EdgeInsets.all(MoodTheme.spacingLg),
        child: Column(
          children: [
            // Question
            Text(
              hasTodayEntry
                  ? "You're feeling ${latestMood!.label.toLowerCase()} today"
                  : 'How are you feeling today?',
              style: MoodTheme.headingSm.copyWith(
                color: MoodTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MoodTheme.spacingLg),

            // Mood selector or current mood display
            if (hasTodayEntry)
              _buildCurrentMoodDisplay(latestMood!)
            else
              _buildMoodQuickSelect(),

            const SizedBox(height: MoodTheme.spacingMd),

            // Add entry button
            if (hasTodayEntry)
              TextButton.icon(
                onPressed: _navigateToEntry,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add another entry'),
                style: TextButton.styleFrom(
                  foregroundColor: MoodTheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMoodDisplay(MoodType mood) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: MoodEmojiWidget(
            mood: mood,
            size: 80,
            isSelected: true,
            showLabel: false,
          ),
        );
      },
    );
  }

  Widget _buildMoodQuickSelect() {
    return MoodSelector(
      selectedMood: null,
      onMoodSelected: (mood) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BloomMoodEntryScreen(initialMood: mood),
          ),
        ).then((_) => _loadData());
      },
      emojiSize: 56,
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: Icons.bar_chart_rounded,
              label: 'Insights',
              color: MoodTheme.accentGold,
              onTap: _navigateToInsights,
            ),
          ),
          const SizedBox(width: MoodTheme.spacingMd),
          Expanded(
            child: _QuickActionCard(
              icon: Icons.calendar_today_rounded,
              label: 'Calendar',
              color: MoodTheme.primary,
              onTap: _navigateToCalendar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      child: StreakCard(
        currentStreak: _streak.currentStreak,
        longestStreak: _streak.longestStreak,
        motivationalMessage: _streak.motivationalMessage,
        onTap: _navigateToInsights,
      ),
    );
  }

  Widget _buildWeeklyCalendar() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week',
                style: MoodTheme.titleLg,
              ),
              GestureDetector(
                onTap: _navigateToCalendar,
                child: Text(
                  'View All',
                  style: MoodTheme.titleSm.copyWith(
                    color: MoodTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MoodTheme.spacingMd),
          Row(
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final entry = _weekEntries.where((e) =>
                  e.timestamp.year == date.year &&
                  e.timestamp.month == date.month &&
                  e.timestamp.day == date.day).firstOrNull;

              return Expanded(
                child: _WeekDayItem(
                  date: date,
                  mood: entry?.mood,
                  isToday: date.day == now.day &&
                      date.month == now.month &&
                      date.year == now.year,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final insight = _weeklyInsight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Stats',
            style: MoodTheme.titleLg,
          ),
          const SizedBox(height: MoodTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: MoodStatsCard(
                  title: 'Entries',
                  value: '${insight?.totalEntries ?? 0}',
                  subtitle: 'this week',
                  icon: Icons.edit_note_rounded,
                  accentColor: MoodTheme.primary,
                ),
              ),
              const SizedBox(width: MoodTheme.spacingMd),
              Expanded(
                child: MoodStatsCard(
                  title: 'Avg. Mood',
                  value: insight?.positivityLevel ?? 'N/A',
                  subtitle: 'positivity',
                  icon: Icons.mood_rounded,
                  accentColor: MoodTheme.accentGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuote() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MoodTheme.spacingLg,
        vertical: MoodTheme.spacingMd,
      ),
      child: DailyQuoteCard(
        onShare: () {
          HapticFeedback.lightImpact();
          // Share functionality
        },
      ),
    );
  }

  Widget _buildRecentEntries() {
    if (_todayEntries.isEmpty && _weekEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final recentEntries = [..._todayEntries, ..._weekEntries].take(3).toList();

    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Entries',
            style: MoodTheme.titleLg,
          ),
          const SizedBox(height: MoodTheme.spacingMd),
          ...recentEntries.map((entry) => _RecentEntryCard(entry: entry)),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _navigateToEntry,
      backgroundColor: MoodTheme.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Log Mood'),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BloomAnimatedGlassCard(
      onTap: onTap,
      accentColor: color,
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: MoodTheme.borderRadiusSm,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: MoodTheme.spacingSm),
          Flexible(
            child: Text(
              label,
              style: MoodTheme.titleMd.copyWith(
                color: MoodTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDayItem extends StatelessWidget {
  final DateTime date;
  final MoodType? mood;
  final bool isToday;

  const _WeekDayItem({
    required this.date,
    this.mood,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final moodColor = mood != null
        ? MoodTheme.getMoodColor(mood!.value)
        : MoodTheme.backgroundSecondary;

    return Column(
      children: [
        Text(
          dayNames[date.weekday - 1],
          style: MoodTheme.caption.copyWith(
            color: isToday ? MoodTheme.primary : MoodTheme.textMuted,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: mood != null
                ? moodColor.withOpacity(0.2)
                : (isToday
                    ? MoodTheme.primary.withOpacity(0.1)
                    : MoodTheme.backgroundSecondary),
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: MoodTheme.primary, width: 2)
                : null,
          ),
          child: Center(
            child: mood != null
                ? Text(mood!.emoji, style: const TextStyle(fontSize: 18))
                : Text(
                    '${date.day}',
                    style: MoodTheme.bodySm.copyWith(
                      color: isToday
                          ? MoodTheme.primary
                          : MoodTheme.textSecondary,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RecentEntryCard extends StatelessWidget {
  final MoodEntry entry;

  const _RecentEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodTheme.getMoodColor(entry.mood.value);

    return Container(
      margin: const EdgeInsets.only(bottom: MoodTheme.spacingSm),
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MoodTheme.borderRadiusMd,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.mood.label,
                  style: MoodTheme.titleSm.copyWith(
                    color: moodColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.isToday
                      ? 'Today at ${entry.formattedTime}'
                      : entry.formattedDate,
                  style: MoodTheme.caption.copyWith(
                    color: MoodTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: moodColor.withOpacity(0.1),
              borderRadius: MoodTheme.borderRadiusRound,
            ),
            child: Text(
              '${entry.intensity}/5',
              style: MoodTheme.caption.copyWith(
                color: moodColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
