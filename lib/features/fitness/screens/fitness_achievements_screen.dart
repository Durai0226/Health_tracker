import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../services/fitness_storage_service.dart';

class FitnessAchievementsScreen extends StatefulWidget {
  const FitnessAchievementsScreen({super.key});

  @override
  State<FitnessAchievementsScreen> createState() => _FitnessAchievementsScreenState();
}

class _FitnessAchievementsScreenState extends State<FitnessAchievementsScreen> {
  final FitnessStorageService _storage = FitnessStorageService();
  
  List<FitnessAchievement> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _storage.getUnlockedAchievements(); // Load for future use
    final stats = await _storage.getLifetimeStats();
    
    // Generate achievements based on stats
    final achievements = _generateAchievements(stats);
    
    if (mounted) {
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  List<FitnessAchievement> _generateAchievements(Map<String, dynamic> stats) {
    final totalWorkouts = stats['totalWorkouts'] ?? 0;
    final totalCalories = stats['totalCalories'] ?? 0;
    final totalMinutes = stats['totalMinutes'] ?? 0;
    final longestStreak = stats['longestStreak'] ?? 0;

    return [
      // Workout Count Achievements
      FitnessAchievement(
        id: 'first_workout',
        name: 'First Steps',
        description: 'Complete your first workout',
        icon: Icons.directions_walk,
        color: FitnessTheme.success,
        category: AchievementCategory.milestone,
        requirement: 1,
        currentProgress: totalWorkouts,
      ),
      FitnessAchievement(
        id: 'workouts_10',
        name: 'Getting Started',
        description: 'Complete 10 workouts',
        icon: Icons.fitness_center,
        color: FitnessTheme.info,
        category: AchievementCategory.milestone,
        requirement: 10,
        currentProgress: totalWorkouts,
      ),
      FitnessAchievement(
        id: 'workouts_50',
        name: 'Committed',
        description: 'Complete 50 workouts',
        icon: Icons.star,
        color: FitnessTheme.warning,
        category: AchievementCategory.milestone,
        requirement: 50,
        currentProgress: totalWorkouts,
      ),
      FitnessAchievement(
        id: 'workouts_100',
        name: 'Century Club',
        description: 'Complete 100 workouts',
        icon: Icons.emoji_events,
        color: FitnessTheme.primary,
        category: AchievementCategory.milestone,
        requirement: 100,
        currentProgress: totalWorkouts,
      ),

      // Calorie Achievements
      FitnessAchievement(
        id: 'calories_1000',
        name: 'Calorie Crusher',
        description: 'Burn 1,000 calories total',
        icon: Icons.local_fire_department,
        color: FitnessTheme.warning,
        category: AchievementCategory.calories,
        requirement: 1000,
        currentProgress: totalCalories,
      ),
      FitnessAchievement(
        id: 'calories_5000',
        name: 'Fire Starter',
        description: 'Burn 5,000 calories total',
        icon: Icons.whatshot,
        color: FitnessTheme.error,
        category: AchievementCategory.calories,
        requirement: 5000,
        currentProgress: totalCalories,
      ),
      FitnessAchievement(
        id: 'calories_10000',
        name: 'Inferno',
        description: 'Burn 10,000 calories total',
        icon: Icons.flash_on,
        color: FitnessTheme.warning,
        category: AchievementCategory.calories,
        requirement: 10000,
        currentProgress: totalCalories,
      ),

      // Time Achievements
      FitnessAchievement(
        id: 'minutes_60',
        name: 'Hour Power',
        description: 'Work out for 60 minutes total',
        icon: Icons.timer,
        color: FitnessTheme.info,
        category: AchievementCategory.time,
        requirement: 60,
        currentProgress: totalMinutes,
      ),
      FitnessAchievement(
        id: 'minutes_300',
        name: 'Time Warrior',
        description: 'Work out for 5 hours total',
        icon: Icons.schedule,
        color: FitnessTheme.success,
        category: AchievementCategory.time,
        requirement: 300,
        currentProgress: totalMinutes,
      ),
      FitnessAchievement(
        id: 'minutes_1000',
        name: 'Marathon Mind',
        description: 'Work out for 1,000 minutes total',
        icon: Icons.hourglass_full,
        color: FitnessTheme.primary,
        category: AchievementCategory.time,
        requirement: 1000,
        currentProgress: totalMinutes,
      ),

      // Streak Achievements
      FitnessAchievement(
        id: 'streak_3',
        name: 'Three-peat',
        description: 'Maintain a 3-day workout streak',
        icon: Icons.bolt,
        color: FitnessTheme.warning,
        category: AchievementCategory.streak,
        requirement: 3,
        currentProgress: longestStreak,
      ),
      FitnessAchievement(
        id: 'streak_7',
        name: 'Week Warrior',
        description: 'Maintain a 7-day workout streak',
        icon: Icons.celebration,
        color: FitnessTheme.success,
        category: AchievementCategory.streak,
        requirement: 7,
        currentProgress: longestStreak,
      ),
      FitnessAchievement(
        id: 'streak_14',
        name: 'Fortnight Fighter',
        description: 'Maintain a 14-day workout streak',
        icon: Icons.military_tech,
        color: FitnessTheme.info,
        category: AchievementCategory.streak,
        requirement: 14,
        currentProgress: longestStreak,
      ),
      FitnessAchievement(
        id: 'streak_30',
        name: 'Monthly Master',
        description: 'Maintain a 30-day workout streak',
        icon: Icons.workspace_premium,
        color: FitnessTheme.primary,
        category: AchievementCategory.streak,
        requirement: 30,
        currentProgress: longestStreak,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: const Text('Achievements', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareAchievements,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FitnessTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressSummary(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildAchievementSection('Milestones', AchievementCategory.milestone),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildAchievementSection('Calories', AchievementCategory.calories),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildAchievementSection('Time', AchievementCategory.time),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildAchievementSection('Streaks', AchievementCategory.streak),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProgressSummary() {
    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    final total = _achievements.length;
    final progress = total > 0 ? unlocked / total : 0.0;

    return FitnessCard(
      backgroundColor: FitnessTheme.primary.withValues(alpha: 0.1),
      borderColor: FitnessTheme.primary.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: FitnessTheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$unlocked',
                    style: FitnessTheme.headingMd.copyWith(color: FitnessTheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unlocked of $total Achievements',
                      style: FitnessTheme.titleLg,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toInt()}% Complete',
                      style: FitnessTheme.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          ClipRRect(
            borderRadius: FitnessTheme.borderRadiusSm,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: FitnessTheme.surface,
              valueColor: const AlwaysStoppedAnimation(FitnessTheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementSection(String title, AchievementCategory category) {
    final categoryAchievements = _achievements.where((a) => a.category == category).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: FitnessTheme.titleLg),
        const SizedBox(height: FitnessTheme.spacingMd),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: FitnessTheme.spacingMd,
            crossAxisSpacing: FitnessTheme.spacingMd,
            childAspectRatio: 0.8,
          ),
          itemCount: categoryAchievements.length,
          itemBuilder: (context, index) {
            return _buildAchievementBadge(categoryAchievements[index]);
          },
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(FitnessAchievement achievement) {
    final isUnlocked = achievement.isUnlocked;

    return GestureDetector(
      onTap: () => _showAchievementDetail(achievement),
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked 
              ? achievement.color.withValues(alpha: 0.1)
              : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: isUnlocked 
                ? achievement.color.withValues(alpha: 0.5)
                : FitnessTheme.surface,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isUnlocked 
                    ? achievement.color.withValues(alpha: 0.2)
                    : FitnessTheme.textMuted.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                achievement.icon,
                color: isUnlocked ? achievement.color : FitnessTheme.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                achievement.name,
                style: FitnessTheme.caption.copyWith(
                  color: isUnlocked ? FitnessTheme.textPrimary : FitnessTheme.textMuted,
                  fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 4),
              Text(
                '${achievement.progressPercent.toInt()}%',
                style: FitnessTheme.caption.copyWith(
                  color: FitnessTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAchievementDetail(FitnessAchievement achievement) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: FitnessTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FitnessTheme.radiusLg)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(FitnessTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: achievement.isUnlocked
                    ? achievement.color.withValues(alpha: 0.2)
                    : FitnessTheme.textMuted.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                achievement.icon,
                color: achievement.isUnlocked ? achievement.color : FitnessTheme.textMuted,
                size: 40,
              ),
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text(
              achievement.name,
              style: FitnessTheme.headingSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              achievement.description,
              style: FitnessTheme.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FitnessTheme.spacingLg),
            // Progress
            if (!achievement.isUnlocked) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${achievement.currentProgress}',
                    style: FitnessTheme.titleLg.copyWith(color: achievement.color),
                  ),
                  Text(' / ${achievement.requirement}', style: FitnessTheme.titleLg),
                ],
              ),
              const SizedBox(height: FitnessTheme.spacingSm),
              ClipRRect(
                borderRadius: FitnessTheme.borderRadiusSm,
                child: LinearProgressIndicator(
                  value: achievement.progressPercent / 100,
                  backgroundColor: FitnessTheme.background,
                  valueColor: AlwaysStoppedAnimation(achievement.color),
                  minHeight: 8,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitnessTheme.spacingMd,
                  vertical: FitnessTheme.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: FitnessTheme.success.withValues(alpha: 0.2),
                  borderRadius: FitnessTheme.borderRadiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: FitnessTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Unlocked!',
                      style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.success),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: FitnessTheme.spacingLg),
            if (achievement.isUnlocked)
              TextButton.icon(
                onPressed: () => _shareAchievement(achievement),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share Achievement'),
                style: TextButton.styleFrom(foregroundColor: FitnessTheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  void _shareAchievement(FitnessAchievement achievement) {
    Share.share(
      '🏆 I just unlocked "${achievement.name}" in my fitness journey!\n\n'
      '${achievement.description}\n\n'
      '#FitnessGoals #Achievement #Dlyminder',
    );
  }

  void _shareAchievements() {
    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    final total = _achievements.length;

    Share.share(
      '💪 My Fitness Journey Progress\n\n'
      '🏆 $unlocked/$total Achievements Unlocked!\n\n'
      'Join me in staying fit with Dlyminder!\n'
      '#FitnessGoals #WorkoutMotivation',
    );
  }
}

// Achievement Model
class FitnessAchievement {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final AchievementCategory category;
  final int requirement;
  final int currentProgress;

  const FitnessAchievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.requirement,
    required this.currentProgress,
  });

  bool get isUnlocked => currentProgress >= requirement;
  
  double get progressPercent => requirement > 0 
      ? (currentProgress / requirement * 100).clamp(0, 100)
      : 0;
}

enum AchievementCategory {
  milestone,
  calories,
  time,
  streak,
}
