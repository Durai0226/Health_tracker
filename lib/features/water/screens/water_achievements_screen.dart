import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import '../models/water_achievement.dart';
import '../services/water_service.dart';

/// Achievements Screen - Gamification with badges and streaks
class WaterAchievementsScreen extends StatefulWidget {
  const WaterAchievementsScreen({super.key});

  @override
  State<WaterAchievementsScreen> createState() => _WaterAchievementsScreenState();
}

class _WaterAchievementsScreenState extends State<WaterAchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserAchievements _userAchievements;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userAchievements = WaterService.getAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Scaffold(
      backgroundColor: ext.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildStatsHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyTabBarDelegate(
              tabBar: CommonTabBar(
                tabs: const ['All', 'Unlocked', 'Locked'],
                controller: _tabController,
              ),
            ),
          ),
          SliverFillRemaining(
            child: CommonTabView(
              controller: _tabController,
              children: [
                _buildAllAchievements(),
                _buildUnlockedAchievements(),
                _buildLockedAchievements(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final ext = AppColorsExt.of(context);
    // Saturated teal that keeps white text readable in both themes.
    final headerTeal = ext.isDark ? ext.water.container : ext.water.strong;
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: headerTeal,
      leading: IconButton(
        icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Achievements',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                headerTeal,
                headerTeal.withOpacity(0.75),
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Symbols.emoji_events_rounded, color: Colors.amber, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    '${_userAchievements.unlockedAchievements.length}/${_userAchievements.achievements.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400,
            Colors.orange.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Symbols.stars_rounded,
                value: '${_userAchievements.totalPoints}',
                label: 'Total Points',
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildStatItem(
                icon: Symbols.trending_up_rounded,
                value: 'Level ${_userAchievements.level}',
                label: '${_userAchievements.pointsToNextLevel} to next',
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildStatItem(
                icon: Symbols.local_fire_department_rounded,
                value: '${_userAchievements.currentStreak}',
                label: 'Day Streak',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_userAchievements.totalPoints % 100) / 100,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildAllAchievements() {
    return _buildAchievementList(_userAchievements.achievements);
  }

  Widget _buildUnlockedAchievements() {
    return _buildAchievementList(_userAchievements.unlockedAchievements);
  }

  Widget _buildLockedAchievements() {
    return _buildAchievementList(_userAchievements.lockedAchievements);
  }

  Widget _buildAchievementList(List<WaterAchievement> achievements) {
    final ext = AppColorsExt.of(context);
    if (achievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.emoji_events_rounded,
              size: 64,
              color: ext.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No achievements yet',
              style: TextStyle(
                color: ext.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Group by type
    final groupedAchievements = <AchievementType, List<WaterAchievement>>{};
    for (final a in achievements) {
      groupedAchievements.putIfAbsent(a.type, () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedAchievements.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
              child: Text(
                _getTypeLabel(entry.key),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ext.textPrimary,
                ),
              ),
            ),
            ...entry.value.map((a) => _buildAchievementCard(a)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  String _getTypeLabel(AchievementType type) {
    switch (type) {
      case AchievementType.streak:
        return '🔥 Streaks';
      case AchievementType.totalVolume:
        return '💧 Total Volume';
      case AchievementType.variety:
        return '🎨 Variety';
      case AchievementType.earlyBird:
        return '🌅 Early Bird';
      case AchievementType.perfectWeek:
        return '⭐ Perfect Week';
      case AchievementType.perfectMonth:
        return '⭐ Perfect Month';
      case AchievementType.overachiever:
        return '🚀 Overachiever';
      case AchievementType.caffeineControl:
        return '☯️ Caffeine Control';
      case AchievementType.socialDrinker:
        return '🧘 Alcohol-Free';
      default:
        return '🏆 Achievements';
    }
  }

  Widget _buildAchievementCard(WaterAchievement achievement) {
    final ext = AppColorsExt.of(context);
    final isUnlocked = achievement.isUnlocked;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showAchievementDetails(achievement);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnlocked ? ext.surface : ext.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: isUnlocked
              ? Border.all(color: Colors.amber.shade300, width: 2)
              : null,
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? Colors.amber.shade100
                    : ext.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  isUnlocked ? achievement.emoji : '🔒',
                  style: TextStyle(
                    fontSize: 28,
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isUnlocked
                                ? ext.textPrimary
                                : ext.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        achievement.tierEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: ext.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: achievement.progress,
                            backgroundColor: ext.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation(
                              isUnlocked ? Colors.amber : ext.water.base,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${achievement.currentValue}/${achievement.targetValue}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isUnlocked ? Colors.amber.shade700 : ext.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? Colors.amber.shade100
                    : ext.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${achievement.points}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.amber.shade700 : ext.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetails(WaterAchievement achievement) {
    final ext = AppColorsExt.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ext.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: achievement.isUnlocked
                    ? Colors.amber.shade100
                    : ext.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  achievement.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  achievement.tierEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  achievement.tierName,
                  style: TextStyle(
                    fontSize: 14,
                    color: ext.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ext.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              style: TextStyle(
                color: ext.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ext.water.base.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${achievement.currentValue}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ext.mark(ext.water),
                        ),
                      ),
                      Text(
                        'Current',
                        style: TextStyle(
                          color: ext.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: ext.mark(ext.water).withOpacity(0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        '${achievement.targetValue}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ext.mark(ext.water),
                        ),
                      ),
                      Text(
                        'Target',
                        style: TextStyle(
                          color: ext.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: ext.mark(ext.water).withOpacity(0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        '+${achievement.points}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      Text(
                        'Points',
                        style: TextStyle(
                          color: ext.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (achievement.isUnlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: 16),
              Text(
                'Unlocked on ${_formatDate(achievement.unlockedAt!)}',
                style: TextStyle(
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
