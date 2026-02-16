import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/training_models.dart';

class TrainingPlansScreen extends StatefulWidget {
  const TrainingPlansScreen({super.key});

  @override
  State<TrainingPlansScreen> createState() => _TrainingPlansScreenState();
}

class _TrainingPlansScreenState extends State<TrainingPlansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedGoal = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildGoalFilter()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Browse Plans'),
                  Tab(text: 'My Plans'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBrowsePlans(),
            _buildMyPlans(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Training Plans',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: 60,
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 50,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalFilter() {
    final goals = ['all', '5K', '10K', 'Half Marathon', 'Marathon', 'Fitness'];
    
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: goals.length,
        itemBuilder: (context, index) {
          final goal = goals[index];
          final isSelected = _selectedGoal == goal;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedGoal = goal),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ] : null,
              ),
              child: Center(
                child: Text(
                  goal == 'all' ? 'All Plans' : goal,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrowsePlans() {
    return ValueListenableBuilder(
      valueListenable: StorageService.trainingPlansListenable,
      builder: (context, box, _) {
          final plans = box.values.toList();
          if (plans.isEmpty) {
             // If empty, we might want to seed some default plans or show empty state
             // For now, let's assume we might need a way to mock/seed data if none exists
             // But following the prompt, we just make it dynamic.
             // If user has no plans, we show empty.
             // However, "Browse Plans" usually implies a catalog. 
             // Since we don't have a backend catalog, we can create some static "template" plans 
             // and allow user to "copy" them into their "My Plans" (which would be stored in Hive).
             // But here, let's assume Hive stores ALL plans including templates?
             // Or maybe we just hardcode templates for "Browse" and use Hive for "My Plans"?
             // The prompt says "populate with data from StorageService".
             // So I should probably put the default plans INTO StorageService if empty.
             
             if (plans.isEmpty) {
                 // Seed default plans if none exist (safe to do in builder? No, side effect.)
                 // Better to show empty or a button to "Load Default Plans"
                 return Center(
                     child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                             const Text('No plans available.'),
                             ElevatedButton(
                                 onPressed: _seedDefaultPlans,
                                 child: const Text('Load Default Plans'),
                             )
                         ],
                     ),
                 );
             }
          }

          final filteredPlans = _selectedGoal == 'all'
            ? plans
            : plans.where((p) => p.goal == _selectedGoal).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPlans.length,
            itemBuilder: (context, index) {
                final plan = filteredPlans[index];
                return _buildPlanCard(plan);
            },
          );
      }
    );
  }
  
  void _seedDefaultPlans() {
      // Helper to add default plans
      final defaultPlans = [
        TrainingPlan(
          id: '1',
          name: 'Couch to 5K',
          description: 'Start running from scratch and build up to 5K in 8 weeks',
          goal: '5K',
          durationWeeks: 8,
          difficulty: 'beginner',
          activityType: 'run',
          weeks: [], // Empty weeks for now as we don't have full structure in memory
          isActive: false,
        ),
        TrainingPlan(
          id: '2',
          name: '10K Training Plan',
          description: 'Improve your endurance and complete a 10K race',
          goal: '10K',
          durationWeeks: 10,
          difficulty: 'intermediate',
          activityType: 'run',
          weeks: [],
          isActive: false,
        ),
        // Add more defaults if needed
      ];
      
      for (var plan in defaultPlans) {
          StorageService.addTrainingPlan(plan);
      }
  }

  Widget _buildPlanCard(TrainingPlan plan) {
    Color difficultyColor;
    switch (plan.difficulty) {
      case 'beginner':
        difficultyColor = Colors.green;
        break;
      case 'intermediate':
        difficultyColor = Colors.orange;
        break;
      case 'advanced':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.blue;
    }

    IconData activityIcon;
    switch (plan.activityType) {
      case 'run':
        activityIcon = Icons.directions_run;
        break;
      case 'cycling':
        activityIcon = Icons.pedal_bike;
        break;
      default:
        activityIcon = Icons.fitness_center;
    }

    return GestureDetector(
      onTap: () => _showPlanDetails(plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.8),
                    AppColors.primary,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Icon(activityIcon, size: 80, color: Colors.white.withOpacity(0.2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: difficultyColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            plan.difficulty.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          plan.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildPlanStat(Icons.calendar_today, '${plan.durationWeeks} weeks'),
                      const SizedBox(width: 20),
                      _buildPlanStat(Icons.repeat, '${plan.weeks.isNotEmpty ? (plan.weeks.map((w) => w.workouts.length).fold(0, (a, b) => a + b) / plan.weeks.length).round() : 0}x/week'),
                      const Spacer(),
                      if (plan.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          )
                      else
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                            'View Plan',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                            ),
                            ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildMyPlans() {
    return ValueListenableBuilder(
      valueListenable: StorageService.trainingPlansListenable,
      builder: (context, box, _) {
          final myPlans = box.values.where((p) => p.isActive).toList();
          
          if (myPlans.isEmpty) {
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(
                        Icons.calendar_month_outlined,
                        size: 80,
                        color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                        'No active training plans',
                        style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'Start a plan to track your progress',
                        style: TextStyle(
                        color: AppColors.textSecondary,
                        ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                        onPressed: () => _tabController.animateTo(0),
                        style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                        ),
                        ),
                        child: const Text('Browse Plans', style: TextStyle(color: Colors.white)),
                    ),
                    ],
                ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myPlans.length,
            itemBuilder: (context, index) {
                return _buildPlanCard(myPlans[index]);
            },
          );
      }
    );
  }

  void _showPlanDetails(TrainingPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanDetailsSheet(plan: plan),
    );
  }
}

class _PlanDetailsSheet extends StatelessWidget {
  final TrainingPlan plan;

  const _PlanDetailsSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildOverviewSection(),
                  const SizedBox(height: 24),
                  _buildWeekPreview(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                         // Activate plan
                         final updatedPlan = TrainingPlan(
                             id: plan.id,
                             name: plan.name,
                             description: plan.description,
                             goal: plan.goal,
                             durationWeeks: plan.durationWeeks,
                             difficulty: plan.difficulty,
                             activityType: plan.activityType,
                             weeks: plan.weeks,
                             isActive: !plan.isActive, // Toggle
                             startDate: !plan.isActive ? DateTime.now() : null,
                         );
                         StorageService.addTrainingPlan(updatedPlan);
                         
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(updatedPlan.isActive ? 'Started ${plan.name}!' : 'Stopped ${plan.name}'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: plan.isActive ? Colors.red : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        plan.isActive ? 'Stop Plan' : 'Start This Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildOverviewItem(Icons.calendar_today, '${plan.durationWeeks}', 'Weeks'),
          _buildOverviewItem(Icons.repeat, '${plan.weeks.isNotEmpty ? (plan.weeks.map((w) => w.workouts.length).fold(0, (a, b) => a + b) / plan.weeks.length).round() : 0}', 'Per Week'),
          _buildOverviewItem(Icons.flag, plan.goal, 'Goal'),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
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
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekPreview() {
      // Mock preview since we don't have full week structure in the model utilized in the UI yet
      // In a real app, this would iterate over plan.weeks
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Week 1 Preview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
         const SizedBox(height: 16),
         if (plan.weeks.isNotEmpty && plan.weeks.first.workouts.isNotEmpty)
            ...plan.weeks.first.workouts.take(7).map((workout) => _buildDayItem(
                workout.dayName,
                workout.workoutType,
                '${workout.targetDurationMinutes} min',
                Icons.directions_run // enhance later based on type
            ))
         else
            const Text('No schedule details available.')
      ],
    );
  }

  Widget _buildDayItem(String day, String workout, String duration, IconData icon) {
    final isRest = workout == 'Rest';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRest 
                  ? Colors.grey.withOpacity(0.1) 
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isRest ? Colors.grey : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  workout,
                  style: TextStyle(
                    fontSize: 13,
                    color: isRest ? Colors.grey : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isRest ? Colors.grey : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
