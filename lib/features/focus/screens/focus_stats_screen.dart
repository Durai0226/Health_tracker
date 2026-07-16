import 'package:flutter/material.dart';
import '../../../core/design/app_colors_ext.dart';
import '../models/focus_session.dart';
import '../models/focus_achievement.dart';
import '../services/focus_service.dart';

class FocusStatsScreen extends StatelessWidget {
  const FocusStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusService = FocusService();
    final ext = AppColorsExt.of(context);

    return Scaffold(
      backgroundColor: ext.background,
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
                      _buildOverviewCard(context, focusService),
                      const SizedBox(height: 24),
                      _buildStreakCard(context, focusService),
                      const SizedBox(height: 24),
                      _buildActivityBreakdown(context, focusService),
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
    final ext = AppColorsExt.of(context);
    return SliverAppBar(
      pinned: true,
      backgroundColor: ext.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ext.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: ext.textPrimary),
        ),
      ),
      title: Text(
        'Focus Statistics',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: ext.textPrimary,
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, FocusService service) {
    final stats = service.stats;
    final ext = AppColorsExt.of(context);
    final focusHero = ext.isDark ? ext.focus.container : ext.focus.base;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            focusHero,
            focusHero.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ext.focus.base.withOpacity(0.4),
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

  Widget _buildStreakCard(BuildContext context, FocusService service) {
    final stats = service.stats;
    final ext = AppColorsExt.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.04),
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
                  ext.warning.base,
                  ext.warning.base.withOpacity(0.8),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ext.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Longest: ${stats.longestStreak} days',
                  style: TextStyle(
                    fontSize: 14,
                    color: ext.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBreakdown(BuildContext context, FocusService service) {
    final activityMinutes = service.stats.minutesByActivity;
    if (activityMinutes.isEmpty) {
      return const SizedBox();
    }

    final sortedActivities = activityMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = activityMinutes.values.fold(0, (a, b) => a + b);
    final ext = AppColorsExt.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedActivities.map((entry) {
            final percentage = total > 0 ? entry.value / total : 0.0;
            return _buildActivityRow(context, entry.key, entry.value, percentage);
          }),
        ],
      ),
    );
  }

  Widget _buildActivityRow(BuildContext context, FocusActivityType activity, int minutes, double percentage) {
    final ext = AppColorsExt.of(context);
    final colors = [
      ext.focus.base,
      ext.info.base,
      ext.success.base,
      ext.warning.base,
      ext.reminders.base,
      ext.error.base,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ext.textPrimary,
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
              backgroundColor: ext.surfaceVariant,
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
    final ext = AppColorsExt.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achievements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ext.textPrimary,
              ),
            ),
            Text(
              '${unlocked.length}/${achievements.length}',
              style: TextStyle(
                fontSize: 14,
                color: ext.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Unlocked achievements
        if (unlocked.isNotEmpty) ...[
          Text(
            'Unlocked',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ext.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: unlocked.map((a) => _buildAchievementCard(context, a, true)).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Locked achievements
        if (locked.isNotEmpty) ...[
          Text(
            'In Progress',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ext.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: locked.take(6).map((a) => _buildAchievementCard(context, a, false)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAchievementCard(BuildContext context, FocusAchievement achievement, bool isUnlocked) {
    final ext = AppColorsExt.of(context);
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? achievement.type.color.withOpacity(0.15)
            : ext.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? achievement.type.color.withOpacity(0.3)
              : ext.outline,
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
              color: isUnlocked ? achievement.type.color : ext.textSecondary,
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
                backgroundColor: ext.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(ext.outlineStrong),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
