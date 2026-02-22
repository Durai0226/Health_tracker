import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/vitavibe_service.dart';
import '../models/enhanced_water_log.dart';
import '../models/beverage_type.dart';
import '../services/water_service.dart';
import 'water_reminder_settings_screen.dart';
import 'water_tracking_screen.dart';
import 'water_statistics_screen.dart';
import 'water_calendar_screen.dart';
import 'water_history_edit_screen.dart';
import 'beverage_selection_screen.dart';
import 'hydration_profile_screen.dart';
import 'water_achievements_screen.dart';
import 'hydration_challenges_screen.dart';
import 'caffeine_insights_screen.dart';
import 'custom_cup_creator_screen.dart';

/// Water Dashboard - WaterMinder-style water tracking
/// Features: Animated water wave, quick add buttons, daily/weekly stats, history
class WaterDashboardScreen extends StatefulWidget {
  const WaterDashboardScreen({super.key});

  @override
  State<WaterDashboardScreen> createState() => _WaterDashboardScreenState();
}

class _WaterDashboardScreenState extends State<WaterDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final VitaVibeService _vitaVibeService = VitaVibeService();
  DailyWaterData? _todayData;
  int _dailyGoal = 2500;
  bool _isLoading = true;

  // Quick add amounts
  final List<Map<String, dynamic>> _quickAddOptions = [
    {'amount': 150, 'icon': Icons.local_cafe, 'label': 'Cup'},
    {'amount': 250, 'icon': Icons.water_drop, 'label': 'Glass'},
    {'amount': 500, 'icon': Icons.local_drink, 'label': 'Bottle'},
    {'amount': 750, 'icon': Icons.sports_bar, 'label': 'Large'},
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await WaterService.init();
      final todayData = WaterService.getTodayData();
      final goal = WaterService.getDailyGoal();
      
      if (mounted) {
        setState(() {
          _todayData = todayData;
          _dailyGoal = goal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading water data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWater(int amountMl) async {
    try {
      _vitaVibeService.waterAdd();
      
      // Default to water for quick add
      final water = WaterService.getBeverage('water') ?? BeverageType.defaultBeverages.first;
      
      final newData = await WaterService.addWaterLog(
        amountMl: amountMl,
        beverage: water,
      );
      
      if (mounted) {
        final progress = newData.progress;
        
        // Celebrate when goal is reached!
        if (progress >= 1 && (newData.effectiveHydrationMl - amountMl) < _dailyGoal) {
          _vitaVibeService.waterGoalReached();
        }
        
        // Force refresh local state to ensure UI sync
        setState(() {
          _todayData = newData;
          _dailyGoal = newData.dailyGoalMl;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '+${amountMl}ml added${progress >= 1 ? ' 🎉 Goal reached!' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: progress >= 1 ? AppColors.success : AppColors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding water: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final listenable = WaterService.listenToDailyData();
    if (listenable == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Water Tracker'),
          backgroundColor: AppColors.info,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Failed to initialize water tracking'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (context, box, _) {
       final todayData = WaterService.getTodayData();
       final currentMl = todayData.effectiveHydrationMl;
       final goal = todayData.dailyGoalMl;
       final progress = todayData.progress.clamp(0.0, 1.0);
       
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildWaterTank(currentMl, goal, progress), // Pass goal explicitly
                    const SizedBox(height: 24),
                    _buildQuickAddButtons(),
                    const SizedBox(height: 24),
                    _buildTodayStats(todayData),
                    const SizedBox(height: 24),
                    _buildWeeklyProgress(todayData), // Pass todayData
                    const SizedBox(height: 24),
                    _buildDrinkHistory(todayData),
                    const SizedBox(height: 24),
                    _buildQuickAccessMenu(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'beverage',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BeverageSelectionScreen()),
                ),
                backgroundColor: Colors.white,
                child: const Icon(Icons.local_cafe, color: AppColors.info),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'custom',
                onPressed: () => _showCustomAmountDialog(),
                backgroundColor: AppColors.info,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Quick Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.info,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WaterReminderSettingsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: _showGoalDialog,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Water Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.info, AppColors.info.withOpacity(0.7)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterTank(int currentMl, int goal, double progress) {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tank background
          Container(
            width: 200,
            height: 260,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey[300]!, width: 3),
            ),
          ),
          // Animated water fill
          ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: SizedBox(
              width: 194,
              height: 254,
              child: Stack(
                children: [
                  // Water fill
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 254 * progress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.info.withOpacity(0.7),
                            AppColors.info,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Wave animation
                  if (progress > 0)
                    Positioned(
                      bottom: 254 * progress - 10,
                      left: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(194, 20),
                            painter: _WavePainter(
                              animationValue: _waveController.value,
                              color: AppColors.info.withOpacity(0.5),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Center text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${currentMl}ml',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: progress > 0.5 ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                'of ${goal}ml',
                style: TextStyle(
                  fontSize: 14,
                  color: progress > 0.5 ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: progress > 0.5 ? Colors.white : AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Add',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _quickAddOptions.map((option) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => _addWater(option['amount'] as int),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: option != _quickAddOptions.last ? 10 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.info.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          option['icon'] as IconData,
                          color: AppColors.info,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${option['amount']}ml',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          option['label'] as String,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  // ... _buildTodayStats modified to use passed data implicitly (it already accepted it)
  Widget _buildTodayStats(DailyWaterData todayData) {
    final currentMl = todayData.effectiveHydrationMl;
    final goal = todayData.dailyGoalMl;
    final remaining = (goal - currentMl).clamp(0, goal);
    final logs = todayData.logs;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                icon: Icons.water_drop,
                value: '${currentMl}ml',
                label: 'Consumed',
                color: AppColors.info,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                icon: Icons.flag_outlined,
                value: '${remaining}ml',
                label: 'Remaining',
                color: AppColors.warning,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                icon: Icons.local_drink,
                value: '${logs.length}',
                label: 'Drinks',
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildWeeklyProgress(DailyWaterData todayData) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isToday = index + 1 == today;
              final isPast = index + 1 < today;
              
              // Use passed todayData for today, static placeholder for others
              final progress = isToday 
                  ? todayData.progress 
                  : (isPast ? 0.7 : 0.0); 

              return Column(
                children: [
                   SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 3,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            progress >= 1 ? AppColors.success : AppColors.info,
                          ),
                        ),
                        if (progress >= 1)
                          const Icon(Icons.check, color: AppColors.success, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? AppColors.info : AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkHistory(DailyWaterData todayData) {
    final logs = todayData.logs;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withOpacity(0.05),
             blurRadius: 10,
             offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Drinks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.water_drop_outlined, 
                        size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    const Text(
                      'No drinks logged yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...logs.reversed.take(5).map((log) => _buildLogItem(log)),
        ],
      ),
    );
  }

  Widget _buildQuickAccessMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More Features',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              _buildFeatureCard(
                icon: Icons.analytics_outlined,
                label: 'Statistics',
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WaterStatisticsScreen()),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.calendar_today,
                label: 'Calendar',
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WaterCalendarScreen()),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.edit_calendar,
                label: 'Edit History',
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WaterHistoryEditScreen(date: DateTime.now())),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.person_outline,
                label: 'Profile',
                color: Colors.indigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HydrationProfileScreen()),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.emoji_events,
                label: 'Achievements',
                color: Colors.amber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WaterAchievementsScreen()),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.flag_outlined,
                label: 'Challenges',
                color: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HydrationChallengesScreen()),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.coffee,
                label: 'Caffeine',
                color: Colors.brown,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CaffeineInsightsScreen()),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.create_outlined,
                label: 'Custom Cup',
                color: Colors.pink,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomCupCreatorScreen()),
                ),
              ),
              _buildFeatureCard(
                icon: Icons.track_changes,
                label: 'Tracking',
                color: Colors.cyan,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WaterTrackingScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(EnhancedWaterLog log) {
    final time = TimeOfDay.fromDateTime(log.time).format(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.water_drop, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.amountMl}ml',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$time • ${log.beverageName}',
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
    );
  }

  void _showCustomAmountDialog() {
    int customAmount = 250;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Custom Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setModalState(() {
                      customAmount = (customAmount - 50).clamp(50, 2000);
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                    key: const Key('remove_custom_amount'),
                    iconSize: 32,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${customAmount}ml',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => setModalState(() {
                      customAmount = (customAmount + 50).clamp(50, 2000);
                    }),
                    icon: const Icon(Icons.add_circle_outline),
                    key: const Key('add_custom_amount'),
                    iconSize: 32,
                    color: AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _addWater(customAmount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  key: const Key('confirm_add_water'),
                  child: const Text(
                    'Add Water',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalDialog() {
    int newGoal = _dailyGoal;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set Daily Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setModalState(() {
                      newGoal = (newGoal - 250).clamp(500, 5000);
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 32,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${newGoal}ml',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => setModalState(() {
                      newGoal = (newGoal + 250).clamp(500, 5000);
                    }),
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 32,
                    color: AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Update header in HydrationProfile via WaterService
                    final profile = WaterService.getProfile();
                    final updatedProfile = profile.copyWith(
                      customGoalMl: newGoal,
                      useCustomGoal: true,
                    );
                    await WaterService.saveProfile(updatedProfile);
                    
                    // Trigger UI update by updating today's data with new goal
                    final todayData = WaterService.getTodayData();
                    final updatedData = todayData.copyWith(dailyGoalMl: newGoal);
                    await WaterService.saveDailyData(updatedData);
                    
                    // Close the bottom sheet (only one pop needed)
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height / 2 +
            math.sin((i / size.width * 2 * math.pi) +
                    (animationValue * 2 * math.pi)) *
                6,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
