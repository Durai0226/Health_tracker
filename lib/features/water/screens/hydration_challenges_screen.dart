import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/hydration_challenge.dart';

/// Hydration Challenges Screen - Gamification with challenges and rewards
class HydrationChallengesScreen extends StatefulWidget {
  const HydrationChallengesScreen({super.key});

  @override
  State<HydrationChallengesScreen> createState() => _HydrationChallengesScreenState();
}

class _HydrationChallengesScreenState extends State<HydrationChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Mock data - in production, load from service
  final List<HydrationChallenge> _activeChallenges = [];
  final List<HydrationChallenge> _availableChallenges = HydrationChallenge.availableChallenges;
  final List<HydrationChallenge> _completedChallenges = [];
  final int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startChallenge(HydrationChallenge challenge) {
    HapticFeedback.mediumImpact();
    
    final now = DateTime.now();
    final activeChallenge = challenge.copyWith(
      isActive: true,
      startDate: now,
      endDate: now.add(Duration(days: challenge.durationDays)),
      currentProgress: 0,
    );

    setState(() {
      _activeChallenges.add(activeChallenge);
      _availableChallenges.removeWhere((c) => c.id == challenge.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(challenge.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text('Challenge started: ${challenge.title}'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abandonChallenge(HydrationChallenge challenge) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Challenge?'),
        content: Text('Are you sure you want to abandon "${challenge.title}"? Your progress will be lost.'),
        actions: [
          CommonButton(
            text: 'Cancel',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          CommonButton(
            text: 'Abandon',
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _activeChallenges.removeWhere((c) => c.id == challenge.id);
        // Add back to available
        final original = HydrationChallenge.availableChallenges
            .firstWhere((c) => c.id == challenge.id, orElse: () => challenge);
        _availableChallenges.add(original);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildStatsHeader()),
          SliverToBoxAdapter(child: _buildTabBar()),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTab(),
                _buildAvailableTab(),
                _buildCompletedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.purple.shade600,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Challenges',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade600, Colors.purple.shade400],
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
          colors: [Colors.purple.shade400, Colors.pink.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.flash_on,
            value: '${_activeChallenges.length}',
            label: 'Active',
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          _buildStatItem(
            icon: Icons.check_circle,
            value: '${_completedChallenges.length}',
            label: 'Completed',
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          _buildStatItem(
            icon: Icons.stars,
            value: '$_totalPoints',
            label: 'Points',
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CommonTabBar(
        tabs: const ['Active', 'Available', 'Completed'],
        controller: _tabController,
        indicatorColor: Colors.purple,
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_activeChallenges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.flash_on_outlined,
        title: 'No Active Challenges',
        subtitle: 'Start a challenge from the Available tab',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeChallenges.length,
      itemBuilder: (context, index) {
        return _buildActiveChallengeCard(_activeChallenges[index]);
      },
    );
  }

  Widget _buildAvailableTab() {
    if (_availableChallenges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'All Challenges Started',
        subtitle: 'Complete your active challenges to unlock more',
      );
    }

    // Group by difficulty
    final grouped = <ChallengeDifficulty, List<HydrationChallenge>>{};
    for (final c in _availableChallenges) {
      grouped.putIfAbsent(c.difficulty, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Row(
                children: [
                  _getDifficultyBadge(entry.key),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.key.name.toUpperCase()} CHALLENGES',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map((c) => _buildAvailableChallengeCard(c)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCompletedTab() {
    if (_completedChallenges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Completed Challenges',
        subtitle: 'Complete challenges to earn points and badges',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedChallenges.length,
      itemBuilder: (context, index) {
        return _buildCompletedChallengeCard(_completedChallenges[index]);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChallengeCard(HydrationChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(challenge.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _getDifficultyBadge(challenge.difficulty),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${challenge.currentProgress}/${challenge.targetValue} ${challenge.targetUnit}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: challenge.progressPercent,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(Colors.purple),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.daysRemaining} days left',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  CommonButton(
                    text: 'Abandon',
                    variant: ButtonVariant.danger,
                    onPressed: () => _abandonChallenge(challenge),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '+${challenge.rewardPoints}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableChallengeCard(HydrationChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(challenge.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      challenge.durationLabel,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '+${challenge.rewardPoints}',
                      style: TextStyle(fontSize: 10, color: Colors.amber.shade800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CommonButton(
            text: 'Start',
            variant: ButtonVariant.primary,
            backgroundColor: Colors.purple,
            onPressed: () => _startChallenge(challenge),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedChallengeCard(HydrationChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(challenge.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        challenge.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                if (challenge.completedAt != null)
                  Text(
                    'Completed ${_formatDate(challenge.completedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '+${challenge.rewardPoints}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getDifficultyBadge(ChallengeDifficulty difficulty) {
    Color color;
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        color = Colors.green;
        break;
      case ChallengeDifficulty.medium:
        color = Colors.orange;
        break;
      case ChallengeDifficulty.hard:
        color = Colors.red;
        break;
      case ChallengeDifficulty.extreme:
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        difficulty.name.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    if (diff < 7) return '$diff days ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}
