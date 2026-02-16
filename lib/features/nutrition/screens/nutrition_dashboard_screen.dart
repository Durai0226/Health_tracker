import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

class NutritionDashboardScreen extends StatefulWidget {
  const NutritionDashboardScreen({super.key});

  @override
  State<NutritionDashboardScreen> createState() => _NutritionDashboardScreenState();
}

class _NutritionDashboardScreenState extends State<NutritionDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Daily goals
  final int _calorieGoal = 2000;
  final double _proteinGoal = 150;
  final double _carbsGoal = 200;
  final double _fatGoal = 65;
  
  // Current intake
  final int _currentCalories = 1450;
  final double _currentProtein = 95;
  final double _currentCarbs = 145;
  final double _currentFat = 48;

  final List<Map<String, dynamic>> _todayMeals = [
    {
      'meal': 'Breakfast',
      'time': '8:00 AM',
      'calories': 420,
      'items': ['Oatmeal with berries', 'Greek yogurt', 'Coffee'],
      'emoji': '🌅',
    },
    {
      'meal': 'Lunch',
      'time': '12:30 PM',
      'calories': 580,
      'items': ['Grilled chicken salad', 'Whole grain bread', 'Apple'],
      'emoji': '☀️',
    },
    {
      'meal': 'Snack',
      'time': '3:00 PM',
      'calories': 180,
      'items': ['Almonds', 'Banana'],
      'emoji': '🍎',
    },
    {
      'meal': 'Dinner',
      'time': 'Planned',
      'calories': 0,
      'items': ['Not logged yet'],
      'emoji': '🌙',
      'isPlanned': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          SliverToBoxAdapter(child: _buildCalorieRing()),
          SliverToBoxAdapter(child: _buildMacroCards()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                tabs: const [
                  Tab(text: 'Diary'),
                  Tab(text: 'Recipes'),
                  Tab(text: 'Fasting'),
                  Tab(text: 'Insights'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDiaryTab(),
            _buildRecipesTab(),
            _buildFastingTab(),
            _buildInsightsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFoodOptions,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Food', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.green.shade600,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white), onPressed: _scanBarcode, tooltip: 'Scan Barcode'),
        IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: () {}),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Nutrition', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade600, Colors.green.shade400],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -30, top: -30, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)))),
              Positioned(right: 20, bottom: 60, child: Icon(Icons.restaurant_rounded, size: 50, color: Colors.white.withOpacity(0.15))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieRing() {
    final remaining = _calorieGoal - _currentCalories;
    final progress = (_currentCalories / _calorieGoal).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CustomPaint(painter: _CalorieRingPainter(progress: progress)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$remaining', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: remaining >= 0 ? AppColors.textPrimary : Colors.red)),
                    Text(remaining >= 0 ? 'remaining' : 'over', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalorieRow('Base Goal', '$_calorieGoal', Colors.grey),
                const SizedBox(height: 12),
                _buildCalorieRow('Food', '+$_currentCalories', Colors.green),
                const SizedBox(height: 12),
                _buildCalorieRow('Exercise', '-120', Colors.orange),
                const Divider(height: 24),
                _buildCalorieRow('Remaining', '$remaining', remaining >= 0 ? AppColors.primary : Colors.red, bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieRow(String label, String value, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _buildMacroCards() {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildMacroCard('Protein', _currentProtein, _proteinGoal, 'g', Colors.red.shade400)),
          const SizedBox(width: 10),
          Expanded(child: _buildMacroCard('Carbs', _currentCarbs, _carbsGoal, 'g', Colors.blue.shade400)),
          const SizedBox(width: 10),
          Expanded(child: _buildMacroCard('Fat', _currentFat, _fatGoal, 'g', Colors.amber.shade600)),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String name, double current, double goal, String unit, Color color) {
    final progress = (current / goal).clamp(0.0, 1.0);
    final remaining = goal - current;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          Text('${current.round()}$unit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text('${remaining.round()}$unit left', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: color.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildQuickAction(Icons.qr_code_scanner, 'Scan', Colors.purple, _scanBarcode)),
          const SizedBox(width: 10),
          Expanded(child: _buildQuickAction(Icons.mic, 'Voice', Colors.blue, _voiceLog)),
          const SizedBox(width: 10),
          Expanded(child: _buildQuickAction(Icons.camera_alt, 'Photo', Colors.orange, _mealScan)),
          const SizedBox(width: 10),
          Expanded(child: _buildQuickAction(Icons.bolt, 'Quick Add', Colors.green, _quickAdd)),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._todayMeals.map((meal) => _buildMealCard(meal)),
        const SizedBox(height: 16),
        _buildWaterSection(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final isPlanned = meal['isPlanned'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPlanned ? Border.all(color: AppColors.border, style: BorderStyle.solid) : null,
        boxShadow: isPlanned ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isPlanned ? AppColors.background : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(meal['emoji'], style: const TextStyle(fontSize: 24))),
          ),
          title: Row(
            children: [
              Text(meal['meal'], style: TextStyle(fontWeight: FontWeight.w600, color: isPlanned ? AppColors.textSecondary : AppColors.textPrimary)),
              if (isPlanned) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Planned', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          subtitle: Text(meal['time'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          trailing: Text(
            isPlanned ? '+ Add' : '${meal['calories']} kcal',
            style: TextStyle(fontWeight: FontWeight.bold, color: isPlanned ? AppColors.primary : AppColors.textPrimary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...(meal['items'] as List).map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(item, style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )),
                  if (!isPlanned) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMiniMacro('P', '25g', Colors.red),
                        const SizedBox(width: 16),
                        _buildMiniMacro('C', '45g', Colors.blue),
                        const SizedBox(width: 16),
                        _buildMiniMacro('F', '12g', Colors.amber),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMacro(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
          child: Center(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
        ),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildWaterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water Intake', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('1.5L / 2.5L goal', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Text('+ 250ml', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRecipeCard('Healthy Chicken Bowl', '450 kcal', '30 min', 4.8),
        _buildRecipeCard('Quinoa Salad', '320 kcal', '15 min', 4.5),
        _buildRecipeCard('Protein Smoothie', '280 kcal', '5 min', 4.9),
        _buildRecipeCard('Grilled Salmon', '380 kcal', '25 min', 4.7),
      ],
    );
  }

  Widget _buildRecipeCard(String name, String calories, String time, double rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.restaurant, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(calories, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(children: [const Icon(Icons.star, size: 14, color: Colors.amber), const SizedBox(width: 4), Text('$rating', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
              ],
            ),
          ),
          const Icon(Icons.bookmark_border, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildFastingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFastingTimer(),
        const SizedBox(height: 16),
        _buildFastingHistory(),
      ],
    );
  }

  Widget _buildFastingTimer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade600]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('16:8 Intermittent Fasting', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          const SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: CircularProgressIndicator(value: 0.65, strokeWidth: 12, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(Colors.white)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('10:24', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                    Text('elapsed', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [Text('Started', style: TextStyle(color: Colors.white70, fontSize: 12)), SizedBox(height: 4), Text('8:00 PM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
              Column(children: [Text('Goal', style: TextStyle(color: Colors.white70, fontSize: 12)), SizedBox(height: 4), Text('12:00 PM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
              Column(children: [Text('Remaining', style: TextStyle(color: Colors.white70, fontSize: 12)), SizedBox(height: 4), Text('5:36', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('End Fast'),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingHistory() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildFastingDay('Mon', 16.5, true),
          _buildFastingDay('Tue', 17.0, true),
          _buildFastingDay('Wed', 14.5, false),
          _buildFastingDay('Thu', 16.2, true),
          _buildFastingDay('Fri', 0, false, isCurrent: true),
        ],
      ),
    );
  }

  Widget _buildFastingDay(String day, double hours, bool completed, {bool isCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(day, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: hours / 16, minHeight: 8, backgroundColor: Colors.purple.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(completed ? Colors.purple : Colors.purple.withOpacity(0.5))),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(isCurrent ? 'In Progress' : '${hours}h', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isCurrent ? Colors.orange : (completed ? Colors.purple : AppColors.textSecondary))),
          ),
          if (completed) const Icon(Icons.check_circle, color: Colors.purple, size: 18),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWeeklyDigest(),
        const SizedBox(height: 16),
        _buildNutrientScore(),
        const SizedBox(height: 16),
        _buildFoodAnalysis(),
      ],
    );
  }

  Widget _buildWeeklyDigest() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.insights, color: Colors.green)),
              const SizedBox(width: 12),
              const Text('Weekly Digest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDigestStat('Avg Calories', '1,850', '↓ 5%', Colors.green),
              _buildDigestStat('Protein Goal', '92%', '↑ 8%', Colors.green),
              _buildDigestStat('Days Logged', '6/7', '', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigestStat(String label, String value, String change, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        if (change.isNotEmpty) Text(change, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildNutrientScore() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal, Colors.teal.shade700]), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.white),
              const SizedBox(width: 10),
              const Text('Nutrient Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Text('78/100', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Your diet is well-balanced with good protein intake. Consider adding more fiber-rich foods.', style: TextStyle(color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildFoodAnalysis() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Food Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildFoodItem('Best Foods', ['Chicken Breast', 'Greek Yogurt', 'Broccoli'], Colors.green),
          const SizedBox(height: 12),
          _buildFoodItem('Limit These', ['White Bread', 'Soda'], Colors.orange),
        ],
      ),
    );
  }

  Widget _buildFoodItem(String title, List<String> foods, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: foods.map((food) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(food, style: TextStyle(fontSize: 12, color: color)),
          )).toList(),
        ),
      ],
    );
  }

  void _showAddFoodOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Log Food', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildAddOption(Icons.search, 'Search Foods', 'Find from database'),
            _buildAddOption(Icons.qr_code_scanner, 'Scan Barcode', 'Quick add packaged foods'),
            _buildAddOption(Icons.camera_alt, 'Meal Scan', 'AI-powered food recognition'),
            _buildAddOption(Icons.mic, 'Voice Log', 'Speak what you ate'),
            _buildAddOption(Icons.add_circle_outline, 'Quick Add', 'Add macros directly'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(context),
    );
  }

  void _scanBarcode() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening barcode scanner...')));
  void _voiceLog() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listening for voice input...')));
  void _mealScan() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening camera for meal scan...')));
  void _quickAdd() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quick add macros...')));
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  _CalorieRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    
    final bgPaint = Paint()..color = Colors.grey.shade200..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    
    final progressPaint = Paint()..color = progress > 1 ? Colors.red : Colors.green..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress.clamp(0, 1), false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: AppColors.background, child: tabBar);
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
