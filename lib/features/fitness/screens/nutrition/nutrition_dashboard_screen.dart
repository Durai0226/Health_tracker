import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/fitness_theme.dart';
import '../../models/meal.dart';
import '../../services/nutrition_service.dart';
import 'add_food_screen.dart';

/// Nutrition tracking dashboard with macros overview and meal logging
class NutritionDashboardScreen extends StatefulWidget {
  const NutritionDashboardScreen({super.key});

  @override
  State<NutritionDashboardScreen> createState() => _NutritionDashboardScreenState();
}

class _NutritionDashboardScreenState extends State<NutritionDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final NutritionService _nutritionService = NutritionService();
  
  DailyNutrition _todayNutrition = DailyNutrition(
    date: DateTime.now(),
    targetCalories: 2000,
    targetProtein: 150,
    targetCarbs: 250,
    targetFat: 65,
    meals: [],
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadNutritionData();
  }

  Future<void> _loadNutritionData() async {
    await _nutritionService.init();
    if (mounted) {
      setState(() {
        _todayNutrition = _nutritionService.getDailyNutrition(DateTime.now());
        _isLoading = false;
      });
      _animController.forward();
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadNutritionData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFCDFF00),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: FitnessTheme.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildCalorieRing(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          _buildMacrosRow(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          _buildMealsSection(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          _buildQuickAddSection(),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddMealSheet,
          backgroundColor: FitnessTheme.primary,
          icon: Icon(Icons.add, color: FitnessTheme.textOnPrimary),
          label: Text(
            'Log Meal',
            style: FitnessTheme.button,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: FitnessTheme.background,
      title: Text('Nutrition', style: FitnessTheme.headingMd),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildCalorieRing() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final progress = _animController.value;
        return Container(
          padding: const EdgeInsets.all(FitnessTheme.spacingLg),
          decoration: FitnessTheme.cardDecoration,
          child: Column(
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background ring
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 12,
                        backgroundColor: FitnessTheme.surface,
                        valueColor: AlwaysStoppedAnimation(
                          FitnessTheme.surface,
                        ),
                      ),
                    ),
                    // Progress ring
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _todayNutrition.caloriesProgress * progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(
                          FitnessTheme.primary,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    // Center content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_todayNutrition.consumedCalories * progress).round()}',
                          style: FitnessTheme.headingXl.copyWith(
                            color: FitnessTheme.primary,
                          ),
                        ),
                        Text(
                          'of ${_todayNutrition.targetCalories} kcal',
                          style: FitnessTheme.bodySm,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FitnessTheme.spacingMd),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitnessTheme.spacingMd,
                  vertical: FitnessTheme.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: _todayNutrition.remainingCalories > 0
                      ? FitnessTheme.success.withValues(alpha: 0.2)
                      : FitnessTheme.warning.withValues(alpha: 0.2),
                  borderRadius: FitnessTheme.borderRadiusRound,
                ),
                child: Text(
                  _todayNutrition.remainingCalories > 0
                      ? '${_todayNutrition.remainingCalories} kcal remaining'
                      : '${-_todayNutrition.remainingCalories} kcal over',
                  style: FitnessTheme.titleSm.copyWith(
                    color: _todayNutrition.remainingCalories > 0
                        ? FitnessTheme.success
                        : FitnessTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacrosRow() {
    return Row(
      children: [
        Expanded(
          child: _MacroCard(
            label: 'Protein',
            value: _todayNutrition.consumedProtein.round(),
            target: _todayNutrition.targetProtein,
            progress: _todayNutrition.proteinProgress,
            color: const Color(0xFFFF6B6B),
            animController: _animController,
          ),
        ),
        const SizedBox(width: FitnessTheme.spacingSm),
        Expanded(
          child: _MacroCard(
            label: 'Carbs',
            value: _todayNutrition.consumedCarbs.round(),
            target: _todayNutrition.targetCarbs,
            progress: _todayNutrition.carbsProgress,
            color: const Color(0xFF4ECDC4),
            animController: _animController,
          ),
        ),
        const SizedBox(width: FitnessTheme.spacingSm),
        Expanded(
          child: _MacroCard(
            label: 'Fat',
            value: _todayNutrition.consumedFat.round(),
            target: _todayNutrition.targetFat,
            progress: _todayNutrition.fatProgress,
            color: const Color(0xFFFFE66D),
            animController: _animController,
          ),
        ),
      ],
    );
  }

  Widget _buildMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today\'s Meals', style: FitnessTheme.headingSm),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
                style: FitnessTheme.titleSm.copyWith(
                  color: FitnessTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        ..._todayNutrition.meals.map((meal) => _MealCard(meal: meal)),
        if (_todayNutrition.meals.isEmpty)
          Container(
            padding: const EdgeInsets.all(FitnessTheme.spacingLg),
            decoration: FitnessTheme.cardDecoration,
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu_outlined,
                    size: 48,
                    color: FitnessTheme.textMuted,
                  ),
                  const SizedBox(height: FitnessTheme.spacingMd),
                  Text(
                    'No meals logged yet',
                    style: FitnessTheme.titleMd.copyWith(
                      color: FitnessTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: FitnessTheme.spacingSm),
                  Text(
                    'Tap the button below to log your first meal',
                    style: FitnessTheme.bodySm,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickAddSection() {
    final quickFoods = [
      ('🍎', 'Apple', 95),
      ('🍌', 'Banana', 105),
      ('🥚', 'Egg', 78),
      ('🥛', 'Milk', 149),
      ('🍞', 'Bread', 79),
      ('🥗', 'Salad', 120),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Add', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingSm),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: quickFoods.length,
            itemBuilder: (context, index) {
              final food = quickFoods[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: FitnessTheme.spacingSm,
                ),
                child: _QuickAddCard(
                  emoji: food.$1,
                  name: food.$2,
                  calories: food.$3,
                  onTap: () => _quickAddFood(food.$2, food.$3.toDouble()),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _quickAddFood(String name, double calories) async {
    HapticFeedback.lightImpact();
    
    // Determine meal type based on current time
    final hour = DateTime.now().hour;
    MealType mealType;
    if (hour < 10) {
      mealType = MealType.breakfast;
    } else if (hour < 14) {
      mealType = MealType.lunch;
    } else if (hour < 21) {
      mealType = MealType.dinner;
    } else {
      mealType = MealType.snack;
    }

    await _nutritionService.quickAddCalories(
      type: mealType,
      calories: calories,
      name: name,
    );

    await _refreshData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $name'),
          backgroundColor: FitnessTheme.success,
        ),
      );
    }
  }

  void _showAddMealSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: FitnessTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddMealSheet(
        onMealAdded: () => _refreshData(),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final int value;
  final int target;
  final double progress;
  final Color color;
  final AnimationController animController;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.target,
    required this.progress,
    required this.color,
    required this.animController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(FitnessTheme.spacingMd),
          decoration: FitnessTheme.cardDecoration,
          child: Column(
            children: [
              Text(
                label,
                style: FitnessTheme.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: FitnessTheme.spacingSm),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1) * animController.value,
                      strokeWidth: 4,
                      backgroundColor: FitnessTheme.surface,
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '${(value * animController.value).round()}',
                    style: FitnessTheme.titleSm.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FitnessTheme.spacingXs),
              Text(
                '/ ${target}g',
                style: FitnessTheme.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealEntry meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: FitnessTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: FitnessTheme.primary.withValues(alpha: 0.15),
              borderRadius: FitnessTheme.borderRadiusSm,
            ),
            child: Center(
              child: Text(
                meal.type.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: FitnessTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.type.displayName,
                  style: FitnessTheme.titleMd,
                ),
                Text(
                  meal.foods.map((f) => f.food.name).join(', '),
                  style: FitnessTheme.bodySm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${meal.totalCalories.round()}',
                style: FitnessTheme.titleMd.copyWith(
                  color: FitnessTheme.primary,
                ),
              ),
              Text(
                'kcal',
                style: FitnessTheme.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAddCard extends StatelessWidget {
  final String emoji;
  final String name;
  final int calories;
  final VoidCallback onTap;

  const _QuickAddCard({
    required this.emoji,
    required this.name,
    required this.calories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(FitnessTheme.spacingSm),
        decoration: FitnessTheme.cardDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              name,
              style: FitnessTheme.caption.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$calories kcal',
              style: FitnessTheme.caption.copyWith(
                fontSize: 10,
                color: FitnessTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMealSheet extends StatelessWidget {
  final Function() onMealAdded;

  const _AddMealSheet({required this.onMealAdded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FitnessTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          Text('Log a Meal', style: FitnessTheme.headingMd),
          const SizedBox(height: FitnessTheme.spacingLg),
          ...MealType.values.map((type) => _MealTypeOption(
            type: type,
            onMealAdded: (_) => onMealAdded(),
          )),
          const SizedBox(height: FitnessTheme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _MealTypeOption extends StatelessWidget {
  final MealType type;
  final Function(bool) onMealAdded;

  const _MealTypeOption({required this.type, required this.onMealAdded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AddFoodScreen(mealType: type),
          ),
        );
        if (result == true) {
          onMealAdded(true);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: FitnessTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FitnessTheme.primary.withValues(alpha: 0.15),
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Center(
                child: Text(
                  type.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.displayName, style: FitnessTheme.titleMd),
                  Text(
                    type.timeRange,
                    style: FitnessTheme.bodySm,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: FitnessTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
