import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/fitness_profile.dart';
import '../data/workout_library.dart';
import '../services/fitness_storage_service.dart';
import 'fitness_workout_detail_screen.dart';

class FitnessDiscoverScreen extends StatefulWidget {
  final BodyPart? initialBodyPart;
  final ExerciseDifficulty? initialDifficulty;

  const FitnessDiscoverScreen({
    super.key,
    this.initialBodyPart,
    this.initialDifficulty,
  });

  @override
  State<FitnessDiscoverScreen> createState() => _FitnessDiscoverScreenState();
}

class _FitnessDiscoverScreenState extends State<FitnessDiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FitnessStorageService _storage = FitnessStorageService();
  
  BodyPart? _selectedBodyPart;
  ExerciseDifficulty? _selectedDifficulty;
  bool? _equipmentFilter; // null = all, true = equipment, false = bodyweight
  String _searchQuery = '';
  Set<String> _favoriteIds = {};

  List<Workout> _allWorkouts = [];
  List<Workout> _filteredWorkouts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedBodyPart = widget.initialBodyPart;
    _selectedDifficulty = widget.initialDifficulty;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final workouts = await _storage.getAllWorkouts();
    final favorites = await _storage.getFavoriteWorkoutIds();
    final profile = await _storage.getProfile();
    
    // Set initial equipment filter based on profile preference
    bool? equipmentPref;
    if (profile.equipmentPreference == EquipmentPreference.none) {
      equipmentPref = false; // Bodyweight only
    } else if (profile.equipmentPreference == EquipmentPreference.full) {
      equipmentPref = true; // With equipment
    }
    // For minimal, leave as null (show all)
    
    if (mounted) {
      setState(() {
        _allWorkouts = workouts;
        _favoriteIds = favorites;
        if (_equipmentFilter == null && equipmentPref != null) {
          _equipmentFilter = equipmentPref;
        }
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    var filtered = _allWorkouts.toList();

    // Filter by body part
    if (_selectedBodyPart != null) {
      filtered = filtered.where((w) => 
        w.primaryBodyPart == _selectedBodyPart
      ).toList();
    }

    // Filter by difficulty
    if (_selectedDifficulty != null) {
      filtered = filtered.where((w) => 
        w.difficulty == _selectedDifficulty
      ).toList();
    }

    // Filter by equipment requirement
    if (_equipmentFilter != null) {
      filtered = filtered.where((w) => 
        w.requiresEquipment == _equipmentFilter
      ).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((w) =>
        w.name.toLowerCase().contains(query) ||
        w.description.toLowerCase().contains(query)
      ).toList();
    }

    setState(() => _filteredWorkouts = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: const Text('Discover', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildFilters(),
            _buildTabs(),
            Expanded(child: _buildContent()),
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
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: TextField(
          style: FitnessTheme.bodyMd,
          decoration: InputDecoration(
            hintText: 'Search workouts...',
            hintStyle: FitnessTheme.bodySm,
            prefixIcon: const Icon(Icons.search, color: FitnessTheme.textMuted),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: FitnessTheme.spacingMd,
              vertical: FitnessTheme.spacingMd,
            ),
          ),
          onChanged: (value) {
            _searchQuery = value;
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingMd),
        children: [
          // Body part filter
          _buildFilterDropdown<BodyPart>(
            label: _selectedBodyPart?.displayName ?? 'Body Part',
            items: BodyPart.values,
            selectedItem: _selectedBodyPart,
            onSelected: (value) {
              setState(() => _selectedBodyPart = value);
              _applyFilters();
            },
            itemLabel: (item) => item.displayName,
          ),
          const SizedBox(width: FitnessTheme.spacingSm),
          // Difficulty filter
          _buildFilterDropdown<ExerciseDifficulty>(
            label: _selectedDifficulty?.displayName ?? 'Difficulty',
            items: ExerciseDifficulty.values,
            selectedItem: _selectedDifficulty,
            onSelected: (value) {
              setState(() => _selectedDifficulty = value);
              _applyFilters();
            },
            itemLabel: (item) => item.displayName,
          ),
          const SizedBox(width: FitnessTheme.spacingSm),
          // Equipment filter
          _buildEquipmentFilter(),
          const SizedBox(width: FitnessTheme.spacingSm),
          // Clear filters
          if (_selectedBodyPart != null || _selectedDifficulty != null || _equipmentFilter != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedBodyPart = null;
                  _selectedDifficulty = null;
                  _equipmentFilter = null;
                });
                _applyFilters();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitnessTheme.spacingMd,
                  vertical: FitnessTheme.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: FitnessTheme.error.withOpacity(0.2),
                  borderRadius: FitnessTheme.borderRadiusRound,
                  border: Border.all(color: FitnessTheme.error.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear, size: 16, color: FitnessTheme.error),
                    const SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.error),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required List<T> items,
    required T? selectedItem,
    required Function(T?) onSelected,
    required String Function(T) itemLabel,
  }) {
    final isSelected = selectedItem != null;

    return PopupMenuButton<T?>(
      onSelected: onSelected,
      color: FitnessTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusMd),
      itemBuilder: (context) => [
        PopupMenuItem<T?>(
          value: null,
          child: Text('All', style: FitnessTheme.bodyMd),
        ),
        ...items.map((item) => PopupMenuItem<T>(
          value: item,
          child: Text(itemLabel(item), style: FitnessTheme.bodyMd),
        )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? FitnessTheme.primary.withOpacity(0.2) : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusRound,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: FitnessTheme.titleSm.copyWith(
                color: isSelected ? FitnessTheme.primary : FitnessTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isSelected ? FitnessTheme.primary : FitnessTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentFilter() {
    String label;
    bool isSelected = _equipmentFilter != null;
    
    if (_equipmentFilter == null) {
      label = 'Equipment';
    } else if (_equipmentFilter == true) {
      label = 'With Equipment';
    } else {
      label = 'Bodyweight Only';
    }

    return PopupMenuButton<bool?>(
      onSelected: (value) {
        setState(() => _equipmentFilter = value);
        _applyFilters();
      },
      color: FitnessTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusMd),
      itemBuilder: (context) => [
        PopupMenuItem<bool?>(
          value: null,
          child: Row(
            children: [
              const Icon(Icons.all_inclusive, size: 18),
              const SizedBox(width: 8),
              Text('All Workouts', style: FitnessTheme.bodyMd),
            ],
          ),
        ),
        PopupMenuItem<bool?>(
          value: false,
          child: Row(
            children: [
              const Icon(Icons.accessibility_new, size: 18),
              const SizedBox(width: 8),
              Text('Bodyweight Only', style: FitnessTheme.bodyMd),
            ],
          ),
        ),
        PopupMenuItem<bool?>(
          value: true,
          child: Row(
            children: [
              const Icon(Icons.fitness_center, size: 18),
              const SizedBox(width: 8),
              Text('With Equipment', style: FitnessTheme.bodyMd),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? FitnessTheme.primary.withOpacity(0.2) : FitnessTheme.surface,
          borderRadius: FitnessTheme.borderRadiusRound,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _equipmentFilter == null 
                  ? Icons.tune 
                  : (_equipmentFilter! ? Icons.fitness_center : Icons.accessibility_new),
              size: 16,
              color: isSelected ? FitnessTheme.primary : FitnessTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: FitnessTheme.titleSm.copyWith(
                color: isSelected ? FitnessTheme.primary : FitnessTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isSelected ? FitnessTheme.primary : FitnessTheme.textMuted,
            ),
          ],
        ),
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
          Tab(text: 'All'),
          Tab(text: 'Quick'),
          Tab(text: 'Favorites'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildWorkoutList(_filteredWorkouts),
        _buildWorkoutList(_filteredWorkouts.where((w) => 
          w.estimatedDurationMinutes <= 10
        ).toList()),
        _buildWorkoutList(_filteredWorkouts.where((w) => 
          _favoriteIds.contains(w.id)
        ).toList()),
      ],
    );
  }

  Widget _buildWorkoutList(List<Workout> workouts) {
    if (workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: FitnessTheme.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text(
              'No workouts found',
              style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.textMuted),
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              'Try adjusting your filters',
              style: FitnessTheme.bodySm,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        final isFavorite = _favoriteIds.contains(workout.id);

        return Stack(
          children: [
            WorkoutCard(
              title: workout.name,
              subtitle: workout.description,
              duration: workout.formattedDuration,
              difficulty: workout.difficulty.displayName,
              bodyPart: workout.primaryBodyPart.displayName,
              exerciseCount: workout.exercises.length,
              onTap: () => _openWorkout(workout),
            ),
            Positioned(
              top: FitnessTheme.spacingMd,
              right: FitnessTheme.spacingMd,
              child: GestureDetector(
                onTap: () => _toggleFavorite(workout.id),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FitnessTheme.background.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? FitnessTheme.error : FitnessTheme.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openWorkout(Workout workout) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FitnessWorkoutDetailScreen(workout: workout),
      ),
    );
  }

  void _toggleFavorite(String workoutId) async {
    HapticFeedback.lightImpact();
    await _storage.toggleFavorite(workoutId);
    final favorites = await _storage.getFavoriteWorkoutIds();
    setState(() => _favoriteIds = favorites);
  }
}
