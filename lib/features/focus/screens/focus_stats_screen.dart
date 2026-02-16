import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/focus_session.dart';
import '../models/focus_achievement.dart';
import '../services/focus_service.dart';

class FocusStatsScreen extends StatelessWidget {
  const FocusStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusService = FocusService();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: focusService,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildOverviewCard(focusService),
                      const SizedBox(height: 24),
                      _buildStreakCard(focusService),
                      const SizedBox(height: 24),
                      _buildActivityBreakdown(focusService),
                      const SizedBox(height: 24),
                      _buildAchievementsSection(context, focusService),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
      ),
      title: const Text(
        'Focus Statistics',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOverviewCard(FocusService service) {
    final stats = service.stats;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOverviewStat(
                value: '${stats.totalHours}',
                label: 'Hours',
                icon: Icons.timer_rounded,
              ),
              _buildOverviewStat(
                value: '${stats.totalSessions}',
                label: 'Sessions',
                icon: Icons.flag_rounded,
              ),
              _buildOverviewStat(
                value: '${stats.alivePlants}',
                label: 'Plants',
                icon: Icons.local_florist_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Completion Rate: ${(stats.completionRate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(FocusService service) {
    final stats = service.stats;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning,
                  AppColors.warning.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.currentStreak} Day Streak',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Longest: ${stats.longestStreak} days',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBreakdown(FocusService service) {
    final activityMinutes = service.stats.minutesByActivity;
    if (activityMinutes.isEmpty) {
      return const SizedBox();
    }
    
    final sortedActivities = activityMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final total = activityMinutes.values.fold(0, (a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedActivities.map((entry) {
            final percentage = total > 0 ? entry.value / total : 0.0;
            return _buildActivityRow(entry.key, entry.value, percentage);
          }),
        ],
      ),
    );
  }

  Widget _buildActivityRow(FocusActivityType activity, int minutes, double percentage) {
    final colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.periodPrimary,
      AppColors.error,
    ];
    final color = colors[activity.index % colors.length];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(activity.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  activity.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$minutes min',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context, FocusService service) {
    final achievements = service.achievements.values.toList();
    final unlocked = achievements.where((a) => a.isUnlocked).toList();
    final locked = achievements.where((a) => !a.isUnlocked).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Achievements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${unlocked.length}/${achievements.length}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Unlocked achievements
        if (unlocked.isNotEmpty) ...[
          const Text(
            'Unlocked',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: unlocked.map((a) => _buildAchievementCard(a, true)).toList(),
          ),
          const SizedBox(height: 24),
        ],
        
        // Locked achievements
        if (locked.isNotEmpty) ...[
          const Text(
            'In Progress',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: locked.take(6).map((a) => _buildAchievementCard(a, false)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAchievementCard(FocusAchievement achievement, bool isUnlocked) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? achievement.type.color.withOpacity(0.15)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? achievement.type.color.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            isUnlocked ? achievement.type.emoji : '🔒',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.type.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? achievement.type.color : Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isUnlocked) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: achievement.progressPercent,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(Colors.grey.shade400),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
