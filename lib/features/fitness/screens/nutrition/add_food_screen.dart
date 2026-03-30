import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/fitness_theme.dart';
import '../../models/meal.dart';
import '../../data/common_foods.dart';
import '../../services/nutrition_service.dart';

/// Screen for adding food to a meal
/// Supports search, category browsing, manual entry, and recent foods
class AddFoodScreen extends StatefulWidget {
  final MealType mealType;

  const AddFoodScreen({super.key, required this.mealType});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final NutritionService _nutritionService = NutritionService();
  final CommonFoodsDatabase _foodsDb = CommonFoodsDatabase();

  List<FoodItem> _searchResults = [];
  List<MealFoodItem> _selectedFoods = [];
  String? _selectedCategory;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _nutritionService.init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchResults = _foodsDb.search(query);
    });
  }

  void _addFood(FoodItem food, {double quantity = 1}) {
    HapticFeedback.lightImpact();
    setState(() {
      final existingIndex = _selectedFoods.indexWhere((f) => f.food.id == food.id);
      if (existingIndex >= 0) {
        final existing = _selectedFoods[existingIndex];
        _selectedFoods[existingIndex] = MealFoodItem(
          food: existing.food,
          quantity: existing.quantity + quantity,
        );
      } else {
        _selectedFoods.add(MealFoodItem(food: food, quantity: quantity));
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${food.name}'),
        backgroundColor: FitnessTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeFood(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedFoods.removeAt(index));
  }

  void _updateQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) {
      _removeFood(index);
      return;
    }
    setState(() {
      _selectedFoods[index] = MealFoodItem(
        food: _selectedFoods[index].food,
        quantity: newQuantity,
      );
    });
  }

  Future<void> _saveMeal() async {
    if (_selectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one food item'),
          backgroundColor: FitnessTheme.warning,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    await _nutritionService.addMealEntry(
      type: widget.mealType,
      foods: _selectedFoods,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.mealType.displayName} logged successfully!'),
          backgroundColor: FitnessTheme.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  double get _totalCalories => _selectedFoods.fold(0, (sum, f) => sum + f.totalCalories);
  double get _totalProtein => _selectedFoods.fold(0, (sum, f) => sum + f.totalProtein);
  double get _totalCarbs => _selectedFoods.fold(0, (sum, f) => sum + f.totalCarbs);
  double get _totalFat => _selectedFoods.fold(0, (sum, f) => sum + f.totalFat);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: Text('Add ${widget.mealType.displayName}', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_selectedFoods.isNotEmpty)
              TextButton(
                onPressed: _saveMeal,
                child: Text(
                  'Save',
                  style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.primary),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            if (_selectedFoods.isNotEmpty) _buildSelectedFoodsSummary(),
            if (!_isSearching) _buildTabs(),
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCategoryBrowser(),
                        _buildRecentFoods(),
                        _buildManualEntry(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Container(
        decoration: BoxDecoration(
          color: FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusMd,
        ),
        child: TextField(
          controller: _searchController,
          style: FitnessTheme.bodyMd,
          decoration: InputDecoration(
            hintText: 'Search foods...',
            hintStyle: FitnessTheme.bodySm,
            prefixIcon: const Icon(Icons.search, color: FitnessTheme.textMuted),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.clear, color: FitnessTheme.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: FitnessTheme.spacingMd,
              vertical: FitnessTheme.spacingMd,
            ),
          ),
          onChanged: _search,
        ),
      ),
    );
  }

  Widget _buildSelectedFoodsSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingMd),
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FitnessTheme.primary.withOpacity(0.2),
            FitnessTheme.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: FitnessTheme.borderRadiusMd,
        border: Border.all(color: FitnessTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${_selectedFoods.length} item${_selectedFoods.length > 1 ? 's' : ''}',
                style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.primary),
              ),
              const Spacer(),
              Text(
                '${_totalCalories.round()} kcal',
                style: FitnessTheme.headingSm.copyWith(color: FitnessTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroChip('P', _totalProtein, const Color(0xFFFF6B6B)),
              _buildMacroChip('C', _totalCarbs, const Color(0xFF4ECDC4)),
              _buildMacroChip('F', _totalFat, const Color(0xFFFFE66D)),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingSm),
          GestureDetector(
            onTap: () => _showSelectedFoodsSheet(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View & Edit Items',
                  style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.primary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, color: FitnessTheme.primary, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: FitnessTheme.borderRadiusRound,
      ),
      child: Text(
        '$label: ${value.round()}g',
        style: FitnessTheme.caption.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: FitnessTheme.spacingMd,
        vertical: FitnessTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: FitnessTheme.surface,
        borderRadius: FitnessTheme.borderRadiusMd,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: FitnessTheme.primary,
          borderRadius: FitnessTheme.borderRadiusMd,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: FitnessTheme.textOnPrimary,
        unselectedLabelColor: FitnessTheme.textSecondary,
        labelStyle: FitnessTheme.titleSm,
        tabs: const [
          Tab(text: 'Browse'),
          Tab(text: 'Recent'),
          Tab(text: 'Custom'),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: FitnessTheme.textMuted),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text(
              'No foods found',
              style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.textMuted),
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              'Try a different search or add manually',
              style: FitnessTheme.bodySm,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => _FoodListItem(
        food: _searchResults[index],
        onAdd: () => _addFood(_searchResults[index]),
        onTap: () => _showFoodDetails(_searchResults[index]),
      ),
    );
  }

  Widget _buildCategoryBrowser() {
    if (_selectedCategory != null) {
      final foods = _foodsDb.getByCategory(_selectedCategory!);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(FitnessTheme.spacingMd),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedCategory = null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FitnessTheme.surface,
                      borderRadius: FitnessTheme.borderRadiusSm,
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                const SizedBox(width: FitnessTheme.spacingMd),
                Text(_selectedCategory!, style: FitnessTheme.headingSm),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingMd),
              itemCount: foods.length,
              itemBuilder: (context, index) => _FoodListItem(
                food: foods[index],
                onAdd: () => _addFood(foods[index]),
                onTap: () => _showFoodDetails(foods[index]),
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: FitnessTheme.spacingMd,
        mainAxisSpacing: FitnessTheme.spacingMd,
        childAspectRatio: 1.3,
      ),
      itemCount: _foodsDb.categories.length,
      itemBuilder: (context, index) {
        final category = _foodsDb.categories[index];
        return _CategoryCard(
          category: category,
          onTap: () => setState(() => _selectedCategory = category),
        );
      },
    );
  }

  Widget _buildRecentFoods() {
    final recentFoods = _foodsDb.popularFoods; // TODO: Replace with actual recent foods

    return ListView(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      children: [
        Text('Popular Foods', style: FitnessTheme.titleMd),
        const SizedBox(height: FitnessTheme.spacingSm),
        ...recentFoods.map((food) => _FoodListItem(
          food: food,
          onAdd: () => _addFood(food),
          onTap: () => _showFoodDetails(food),
        )),
      ],
    );
  }

  Widget _buildManualEntry() {
    return _ManualFoodEntry(
      onAdd: (food) => _addFood(food),
    );
  }

  void _showFoodDetails(FoodItem food) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FitnessTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FoodDetailSheet(
        food: food,
        onAdd: (quantity) {
          _addFood(food, quantity: quantity);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSelectedFoodsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FitnessTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: FitnessTheme.spacingMd),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FitnessTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text('Selected Foods', style: FitnessTheme.headingSm),
            const SizedBox(height: FitnessTheme.spacingMd),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingMd),
                itemCount: _selectedFoods.length,
                itemBuilder: (context, index) {
                  final item = _selectedFoods[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
                    padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                    decoration: FitnessTheme.cardDecoration,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.food.name, style: FitnessTheme.titleSm),
                              Text(
                                '${item.totalCalories.round()} kcal',
                                style: FitnessTheme.bodySm,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: FitnessTheme.textMuted,
                              onPressed: () {
                                _updateQuantity(index, item.quantity - 0.5);
                                Navigator.pop(context);
                                _showSelectedFoodsSheet();
                              },
                            ),
                            Text(
                              item.quantity.toString(),
                              style: FitnessTheme.titleMd,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: FitnessTheme.primary,
                              onPressed: () {
                                _updateQuantity(index, item.quantity + 0.5);
                                Navigator.pop(context);
                                _showSelectedFoodsSheet();
                              },
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: FitnessTheme.error,
                          onPressed: () {
                            _removeFood(index);
                            Navigator.pop(context);
                            if (_selectedFoods.isNotEmpty) {
                              _showSelectedFoodsSheet();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodListItem extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  const _FoodListItem({
    required this.food,
    required this.onAdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: FitnessTheme.cardDecoration,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: FitnessTheme.titleSm),
                  const SizedBox(height: 2),
                  Text(
                    '${food.servingSize.round()} ${food.servingUnit}',
                    style: FitnessTheme.caption,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildMiniMacro('${food.calories.round()}', 'kcal', FitnessTheme.primary),
                      const SizedBox(width: 8),
                      _buildMiniMacro('${food.protein.round()}g', 'P', const Color(0xFFFF6B6B)),
                      const SizedBox(width: 8),
                      _buildMiniMacro('${food.carbs.round()}g', 'C', const Color(0xFF4ECDC4)),
                      const SizedBox(width: 8),
                      _buildMiniMacro('${food.fat.round()}g', 'F', const Color(0xFFFFE66D)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FitnessTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMacro(String value, String label, Color color) {
    return Text(
      '$value $label',
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  IconData get _icon {
    switch (category) {
      case 'Fruits':
        return Icons.apple;
      case 'Vegetables':
        return Icons.eco;
      case 'Proteins':
        return Icons.egg;
      case 'Grains':
        return Icons.grain;
      case 'Dairy':
        return Icons.water_drop;
      case 'Snacks':
        return Icons.cookie;
      case 'Beverages':
        return Icons.local_cafe;
      case 'Fast Food':
        return Icons.fastfood;
      default:
        return Icons.restaurant;
    }
  }

  Color get _color {
    switch (category) {
      case 'Fruits':
        return const Color(0xFFFF6B6B);
      case 'Vegetables':
        return const Color(0xFF4ECDC4);
      case 'Proteins':
        return const Color(0xFFFFE66D);
      case 'Grains':
        return const Color(0xFFF4A460);
      case 'Dairy':
        return const Color(0xFF87CEEB);
      case 'Snacks':
        return const Color(0xFFDDA0DD);
      case 'Beverages':
        return const Color(0xFF8B4513);
      case 'Fast Food':
        return const Color(0xFFFF8C00);
      default:
        return FitnessTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _color.withOpacity(0.3),
              _color.withOpacity(0.1),
            ],
          ),
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(color: _color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 36, color: _color),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              category,
              style: FitnessTheme.titleSm.copyWith(color: _color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodDetailSheet extends StatefulWidget {
  final FoodItem food;
  final Function(double) onAdd;

  const _FoodDetailSheet({
    required this.food,
    required this.onAdd,
  });

  @override
  State<_FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<_FoodDetailSheet> {
  double _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final totalCalories = food.calories * _quantity;
    final totalProtein = food.protein * _quantity;
    final totalCarbs = food.carbs * _quantity;
    final totalFat = food.fat * _quantity;

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
          Text(food.name, style: FitnessTheme.headingMd),
          Text(
            '${food.servingSize.round()} ${food.servingUnit}',
            style: FitnessTheme.bodySm,
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 32),
                color: FitnessTheme.textMuted,
                onPressed: _quantity > 0.5
                    ? () => setState(() => _quantity -= 0.5)
                    : null,
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              Text(
                _quantity.toString(),
                style: FitnessTheme.headingXl.copyWith(color: FitnessTheme.primary),
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 32),
                color: FitnessTheme.primary,
                onPressed: () => setState(() => _quantity += 0.5),
              ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          Container(
            padding: const EdgeInsets.all(FitnessTheme.spacingMd),
            decoration: FitnessTheme.cardDecoration,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrient('Calories', '${totalCalories.round()}', 'kcal', FitnessTheme.primary),
                _buildNutrient('Protein', '${totalProtein.round()}', 'g', const Color(0xFFFF6B6B)),
                _buildNutrient('Carbs', '${totalCarbs.round()}', 'g', const Color(0xFF4ECDC4)),
                _buildNutrient('Fat', '${totalFat.round()}', 'g', const Color(0xFFFFE66D)),
              ],
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onAdd(_quantity),
              style: ElevatedButton.styleFrom(
                backgroundColor: FitnessTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Add to Meal',
                style: FitnessTheme.button,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildNutrient(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: FitnessTheme.headingSm.copyWith(color: color),
        ),
        Text(unit, style: FitnessTheme.caption),
        Text(label, style: FitnessTheme.caption),
      ],
    );
  }
}

class _ManualFoodEntry extends StatefulWidget {
  final Function(FoodItem) onAdd;

  const _ManualFoodEntry({required this.onAdd});

  @override
  State<_ManualFoodEntry> createState() => _ManualFoodEntryState();
}

class _ManualFoodEntryState extends State<_ManualFoodEntry> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingSizeController = TextEditingController(text: '100');
  final _servingUnitController = TextEditingController(text: 'g');

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingSizeController.dispose();
    _servingUnitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final food = FoodItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        protein: double.tryParse(_proteinController.text) ?? 0,
        carbs: double.tryParse(_carbsController.text) ?? 0,
        fat: double.tryParse(_fatController.text) ?? 0,
        servingSize: double.tryParse(_servingSizeController.text) ?? 100,
        servingUnit: _servingUnitController.text,
        category: 'Custom',
      );
      widget.onAdd(food);
      
      _nameController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _carbsController.clear();
      _fatController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Custom Food', style: FitnessTheme.titleMd),
            const SizedBox(height: FitnessTheme.spacingMd),
            _buildTextField(
              controller: _nameController,
              label: 'Food Name',
              hint: 'e.g., Grilled Chicken Salad',
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _servingSizeController,
                    label: 'Serving Size',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: FitnessTheme.spacingSm),
                Expanded(
                  child: _buildTextField(
                    controller: _servingUnitController,
                    label: 'Unit',
                    hint: 'g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            _buildTextField(
              controller: _caloriesController,
              label: 'Calories',
              hint: '0',
              keyboardType: TextInputType.number,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _proteinController,
                    label: 'Protein (g)',
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: FitnessTheme.spacingSm),
                Expanded(
                  child: _buildTextField(
                    controller: _carbsController,
                    label: 'Carbs (g)',
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: FitnessTheme.spacingSm),
                Expanded(
                  child: _buildTextField(
                    controller: _fatController,
                    label: 'Fat (g)',
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FitnessTheme.spacingLg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitnessTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Add Food', style: FitnessTheme.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: FitnessTheme.bodyMd,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: FitnessTheme.bodySm,
        hintStyle: FitnessTheme.caption,
        filled: true,
        fillColor: FitnessTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingMd,
        ),
      ),
    );
  }
}
