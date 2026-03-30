import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/habit_theme.dart';
import '../../services/habit_service.dart';

/// Habit Achievements Screen
/// Display user's earned badges and milestones
class HabitAchievementsScreen extends StatefulWidget {
  const HabitAchievementsScreen({super.key});

  @override
  State<HabitAchievementsScreen> createState() => _HabitAchievementsScreenState();
}

class _HabitAchievementsScreenState extends State<HabitAchievementsScreen> {
  final HabitService _habitService = HabitService();
  List<HabitAchievementData> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final achievements = await _habitService.getAchievements();
    if (mounted) {
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: HabitTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Achievements',
          style: HabitTheme.h2.copyWith(color: HabitTheme.dark),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: HabitTheme.primary))
          : _achievements.isEmpty
              ? _buildEmptyState()
              : _buildAchievementsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HabitTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: HabitTheme.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: HabitTheme.primary,
              ),
            ),
            const SizedBox(height: HabitTheme.spacingL),
            Text(
              'No Achievements Yet',
              style: HabitTheme.h2.copyWith(color: HabitTheme.dark),
            ),
            const SizedBox(height: HabitTheme.spacingS),
            Text(
              'Keep building your habits to unlock badges and milestones!',
              style: HabitTheme.b2.copyWith(color: HabitTheme.gray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsList() {
    final earned = _achievements.where((a) => a.isEarned).toList();
    final locked = _achievements.where((a) => !a.isEarned).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HabitTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats summary
          _buildStatsSummary(earned.length, _achievements.length),
          const SizedBox(height: HabitTheme.spacingL),

          // Earned achievements
          if (earned.isNotEmpty) ...[
            _buildSectionTitle('Earned', earned.length),
            const SizedBox(height: HabitTheme.spacingS),
            ...earned.map((a) => _buildAchievementCard(a)),
            const SizedBox(height: HabitTheme.spacingL),
          ],

          // Locked achievements
          if (locked.isNotEmpty) ...[
            _buildSectionTitle('Locked', locked.length),
            const SizedBox(height: HabitTheme.spacingS),
            ...locked.map((a) => _buildAchievementCard(a)),
          ],
          const SizedBox(height: HabitTheme.spacingL),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(int earned, int total) {
    final progress = total > 0 ? earned / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(HabitTheme.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HabitTheme.primary, HabitTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: HabitTheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: HabitTheme.cream, size: 32),
              const SizedBox(width: 12),
              Text(
                '$earned / $total',
                style: HabitTheme.h1.copyWith(
                  color: HabitTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Achievements Unlocked',
            style: HabitTheme.b2.copyWith(color: HabitTheme.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: HabitTheme.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: HabitTheme.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(HabitTheme.cream),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: HabitTheme.label.copyWith(
              color: HabitTheme.dark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: HabitTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: HabitTheme.b3.copyWith(
                color: HabitTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(HabitAchievementData achievement) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showAchievementDetails(achievement);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: HabitTheme.spacingS),
        padding: const EdgeInsets.all(HabitTheme.spacingM),
        decoration: BoxDecoration(
          color: HabitTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: achievement.isEarned
              ? Border.all(color: HabitTheme.primary.withValues(alpha: 0.3), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: HabitTheme.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: achievement.isEarned 
                    ? HabitTheme.primarySoft 
                    : HabitTheme.grayLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  achievement.emoji,
                  style: TextStyle(
                    fontSize: 28,
                    color: achievement.isEarned ? null : HabitTheme.gray,
                  ),
                ),
              ),
            ),
            const SizedBox(width: HabitTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: HabitTheme.label.copyWith(
                      color: achievement.isEarned ? HabitTheme.dark : HabitTheme.gray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: HabitTheme.b3.copyWith(
                      color: achievement.isEarned 
                          ? HabitTheme.gray 
                          : HabitTheme.gray.withValues(alpha: 0.6),
                    ),
                  ),
                  if (achievement.isEarned && achievement.earnedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Earned ${_formatDate(achievement.earnedAt!)}',
                      style: HabitTheme.caption.copyWith(color: HabitTheme.primary),
                    ),
                  ],
                ],
              ),
            ),
            if (achievement.isEarned)
              const Icon(Icons.check_circle, color: HabitTheme.success, size: 24)
            else
              Icon(Icons.lock_outline, color: HabitTheme.gray.withValues(alpha: 0.5), size: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showAchievementDetails(HabitAchievementData achievement) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(HabitTheme.spacingL),
        decoration: const BoxDecoration(
          color: HabitTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: HabitTheme.spacingL),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: achievement.isEarned 
                    ? HabitTheme.primarySoft 
                    : HabitTheme.grayLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  achievement.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: HabitTheme.spacingM),
            Text(
              achievement.title,
              style: HabitTheme.h2.copyWith(color: HabitTheme.dark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              style: HabitTheme.b2.copyWith(color: HabitTheme.gray),
              textAlign: TextAlign.center,
            ),
            if (achievement.isEarned && achievement.earnedAt != null) ...[
              const SizedBox(height: HabitTheme.spacingM),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: HabitTheme.successLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: HabitTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Earned ${_formatDate(achievement.earnedAt!)}',
                      style: HabitTheme.b3.copyWith(
                        color: HabitTheme.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: HabitTheme.spacingL),
          ],
        ),
      ),
    );
  }
}
