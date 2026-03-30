/// Leaderboard Screen
/// Shows rankings of users based on test performance

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../models/leaderboard_model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LeaderboardPeriod _selectedPeriod = LeaderboardPeriod.weekly;
  List<LeaderboardEntry> _entries = [];
  LeaderboardStats? _stats;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _periods = [
    {'period': LeaderboardPeriod.daily, 'label': 'Today'},
    {'period': LeaderboardPeriod.weekly, 'label': 'This Week'},
    {'period': LeaderboardPeriod.monthly, 'label': 'This Month'},
    {'period': LeaderboardPeriod.allTime, 'label': 'All Time'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.index = 1; // Default to weekly
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedPeriod = _periods[_tabController.index]['period'] as LeaderboardPeriod;
        _loadData();
      });
    }
  }

  void _loadData() {
    setState(() => _isLoading = true);
    
    // Simulate loading
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _entries = SampleLeaderboard.getSampleEntries(_selectedPeriod);
          _stats = SampleLeaderboard.getSampleStats(_selectedPeriod);
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildPeriodTabs(context, isDark),
                if (_stats != null) _buildStatsCard(context, isDark),
                _buildTopThree(context, isDark),
              ],
            ),
          ),
          _buildRankingsList(context, isDark),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: ExamPrepTheme.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ExamPrepTheme.primary, ExamPrepTheme.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.leaderboard, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Leaderboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${_stats?.totalParticipants ?? 0}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodTabs(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [ExamPrepTheme.primary, ExamPrepTheme.primaryLight]),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: ExamPrepTheme.getTextSecondary(context),
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: _periods.map((p) => Tab(
          child: Text(p['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        )).toList(),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ExamPrepTheme.primary.withOpacity(0.1), ExamPrepTheme.primaryLight.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ExamPrepTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(context, 'Avg Score', '${_stats!.averageScore}', Icons.score),
          Container(height: 40, width: 1, color: ExamPrepTheme.primary.withOpacity(0.2)),
          _buildStatItem(context, 'Avg Accuracy', '${_stats!.averageAccuracy.toStringAsFixed(1)}%', Icons.percent),
          Container(height: 40, width: 1, color: ExamPrepTheme.primary.withOpacity(0.2)),
          _buildStatItem(context, 'Top Score', '${_stats!.topScore}', Icons.emoji_events),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: ExamPrepTheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: ExamPrepTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: ExamPrepTheme.getTextSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTopThree(BuildContext context, bool isDark) {
    if (_isLoading || _entries.length < 3) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    return Container(
      margin: const EdgeInsets.all(16),
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildPodiumItem(context, isDark, _entries[1], 2, 140)),
          Expanded(child: _buildPodiumItem(context, isDark, _entries[0], 1, 180)),
          Expanded(child: _buildPodiumItem(context, isDark, _entries[2], 3, 120)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(BuildContext context, bool isDark, LeaderboardEntry entry, int position, double height) {
    Color podiumColor;
    IconData crownIcon;
    
    switch (position) {
      case 1:
        podiumColor = const Color(0xFFFFD700); // Gold
        crownIcon = Icons.workspace_premium;
        break;
      case 2:
        podiumColor = const Color(0xFFC0C0C0); // Silver
        crownIcon = Icons.military_tech;
        break;
      default:
        podiumColor = const Color(0xFFCD7F32); // Bronze
        crownIcon = Icons.emoji_events;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            CircleAvatar(
              radius: position == 1 ? 35 : 28,
              backgroundColor: podiumColor.withOpacity(0.2),
              child: CircleAvatar(
                radius: position == 1 ? 32 : 25,
                backgroundColor: podiumColor.withOpacity(0.3),
                child: Text(
                  entry.userName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: podiumColor,
                    fontWeight: FontWeight.bold,
                    fontSize: position == 1 ? 24 : 18,
                  ),
                ),
              ),
            ),
            if (position == 1)
              Positioned(
                top: -8,
                child: Icon(crownIcon, color: podiumColor, size: 24),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry.userName.split(' ').first,
          style: TextStyle(
            color: ExamPrepTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${entry.score} pts',
          style: TextStyle(
            color: podiumColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height - 100,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [podiumColor, podiumColor.withOpacity(0.7)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '$position',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsList(BuildContext context, bool isDark) {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final remainingEntries = _entries.skip(3).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.format_list_numbered, color: ExamPrepTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Rankings',
                    style: TextStyle(
                      color: ExamPrepTheme.getTextPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          final entry = remainingEntries[index - 1];
          return _buildRankingItem(context, isDark, entry);
        },
        childCount: remainingEntries.length + 1,
      ),
    );
  }

  Widget _buildRankingItem(BuildContext context, bool isDark, LeaderboardEntry entry) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showUserProfile(context, entry),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ExamPrepTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.rank}',
                      style: TextStyle(
                        color: ExamPrepTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getAvatarColor(entry.rank),
                  child: Text(
                    entry.userName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.userName,
                        style: TextStyle(
                          color: ExamPrepTheme.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.streak} day streak',
                            style: TextStyle(
                              color: ExamPrepTheme.getTextSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.check_circle, size: 12, color: ExamPrepTheme.success),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.accuracy.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: ExamPrepTheme.getTextSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${entry.score}',
                      style: TextStyle(
                        color: ExamPrepTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'points',
                      style: TextStyle(
                        color: ExamPrepTheme.getTextSecondary(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(int rank) {
    final colors = [
      ExamPrepTheme.quantitative,
      ExamPrepTheme.reasoning,
      ExamPrepTheme.english,
      ExamPrepTheme.generalAwareness,
      ExamPrepTheme.computer,
      ExamPrepTheme.generalScience,
    ];
    return colors[(rank - 1) % colors.length];
  }

  void _showUserProfile(BuildContext context, LeaderboardEntry entry) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 40,
                backgroundColor: _getAvatarColor(entry.rank),
                child: Text(
                  entry.userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                entry.userName,
                style: TextStyle(
                  color: ExamPrepTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ExamPrepTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Rank #${entry.rank}',
                  style: TextStyle(color: ExamPrepTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileStat(context, 'Score', '${entry.score}', Icons.score),
                  _buildProfileStat(context, 'Tests', '${entry.testsCompleted}', Icons.quiz),
                  _buildProfileStat(context, 'Accuracy', '${entry.accuracy.toStringAsFixed(0)}%', Icons.percent),
                  _buildProfileStat(context, 'Streak', '${entry.streak}', Icons.local_fire_department),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ExamPrepTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ExamPrepTheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: ExamPrepTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: ExamPrepTheme.getTextSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
