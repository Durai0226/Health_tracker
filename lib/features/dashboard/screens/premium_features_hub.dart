import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../fitness/screens/enhanced_fitness_dashboard.dart';
import '../../fitness/screens/routes_screen.dart';
import '../../fitness/screens/social_challenges_screen.dart';
import '../../nutrition/screens/nutrition_dashboard_screen.dart';
import '../../sleep/screens/sleep_dashboard_screen.dart';
import '../../mindfulness/screens/mindfulness_screen.dart';

class PremiumFeaturesHub extends StatelessWidget {
  const PremiumFeaturesHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildWelcomeCard()),
          SliverToBoxAdapter(child: _buildQuickStats()),
          SliverToBoxAdapter(child: _buildFeaturesGrid(context)),
          SliverToBoxAdapter(child: _buildRecentActivity()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.person_outline, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Health & Fitness Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                Colors.teal.shade600,
                Colors.blue.shade700,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 70,
                child: Row(
                  children: [
                    Icon(Icons.fitness_center, size: 30, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 10),
                    Icon(Icons.favorite, size: 25, color: Colors.white.withOpacity(0.15)),
                    const SizedBox(width: 10),
                    Icon(Icons.self_improvement, size: 28, color: Colors.white.withOpacity(0.18)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back! 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'re on a 7-day streak! Keep going to unlock new achievements.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 32)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStat('🏃', '24.5', 'km this week'),
          _buildQuickStat('🔥', '1,850', 'kcal avg'),
          _buildQuickStat('😴', '7.2h', 'avg sleep'),
          _buildQuickStat('❤️', '62', 'resting HR'),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    final features = [
      {
        'title': 'Performance',
        'subtitle': 'Training & Analysis',
        'icon': Icons.fitness_center,
        'color': Colors.orange,
        'screen': const EnhancedFitnessDashboard(),
      },
      {
        'title': 'Nutrition',
        'subtitle': 'Diet & Meal Planning',
        'icon': Icons.restaurant,
        'color': Colors.green,
        'screen': const NutritionDashboardScreen(),
      },
      {
        'title': 'Sleep',
        'subtitle': 'Rest & Recovery',
        'icon': Icons.bedtime,
        'color': Colors.indigo,
        'screen': const SleepDashboardScreen(),
      },
      {
        'title': 'Mindfulness',
        'subtitle': 'Meditation & Stress',
        'icon': Icons.self_improvement,
        'color': Colors.purple,
        'screen': const MindfulnessScreen(),
      },
      {
        'title': 'Routes',
        'subtitle': 'Maps & Navigation',
        'icon': Icons.map,
        'color': Colors.blue,
        'screen': const RoutesScreen(),
      },
      {
        'title': 'Social',
        'subtitle': 'Challenges & Friends',
        'icon': Icons.people,
        'color': Colors.teal,
        'screen': const SocialChallengesScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return _buildFeatureCard(
                context,
                title: feature['title'] as String,
                subtitle: feature['subtitle'] as String,
                icon: feature['icon'] as IconData,
                color: feature['color'] as Color,
                screen: feature['screen'] as Widget,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activities = [
      {
        'title': 'Morning Run',
        'subtitle': '5.2 km • 28 min',
        'time': '2 hours ago',
        'icon': Icons.directions_run,
        'color': Colors.orange,
      },
      {
        'title': 'Logged Lunch',
        'subtitle': '580 kcal',
        'time': '4 hours ago',
        'icon': Icons.restaurant,
        'color': Colors.green,
      },
      {
        'title': 'Meditation',
        'subtitle': '10 min session',
        'time': 'Yesterday',
        'icon': Icons.self_improvement,
        'color': Colors.purple,
      },
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activities.map((activity) => _buildActivityItem(
            title: activity['title'] as String,
            subtitle: activity['subtitle'] as String,
            time: activity['time'] as String,
            icon: activity['icon'] as IconData,
            color: activity['color'] as Color,
          )),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
