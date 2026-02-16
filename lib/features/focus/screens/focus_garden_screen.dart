import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/focus_plant.dart';
import '../services/focus_service.dart';

class FocusGardenScreen extends StatelessWidget {
  const FocusGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusService = FocusService();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: focusService,
          builder: (context, _) {
            final garden = focusService.garden;
            final groupedByDate = _groupPlantsByDate(garden);
            
            return CustomScrollView(
              slivers: [
                _buildAppBar(context, garden),
                if (garden.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final date = groupedByDate.keys.toList()[index];
                          final plants = groupedByDate[date]!;
                          return _buildDateSection(context, date, plants);
                        },
                        childCount: groupedByDate.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, List<FocusPlant> garden) {
    final alivePlants = garden.where((p) => p.isAlive).length;
    final deadPlants = garden.where((p) => !p.isAlive).length;
    
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🌳', style: TextStyle(fontSize: 40)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Garden',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$alivePlants alive • $deadPlants withered',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildGardenStats(garden),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGardenStats(List<FocusPlant> garden) {
    final plantCounts = <PlantType, int>{};
    for (final plant in garden.where((p) => p.isAlive)) {
      plantCounts[plant.type] = (plantCounts[plant.type] ?? 0) + 1;
    }
    
    if (plantCounts.isEmpty) return const SizedBox();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: plantCounts.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: entry.key.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.key.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: entry.key.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<DateTime, List<FocusPlant>> _groupPlantsByDate(List<FocusPlant> plants) {
    final Map<DateTime, List<FocusPlant>> grouped = {};
    for (final plant in plants.reversed) {
      final date = DateTime(
        plant.plantedAt.year,
        plant.plantedAt.month,
        plant.plantedAt.day,
      );
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(plant);
    }
    
    // Sort by date descending
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  Widget _buildDateSection(BuildContext context, DateTime date, List<FocusPlant> plants) {
    final isToday = _isToday(date);
    final isYesterday = _isYesterday(date);
    
    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isYesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE, MMMM d').format(date);
    }
    
    final totalMinutes = plants.fold(0, (sum, p) => sum + p.durationMinutes);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$totalMinutes min',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: plants.map((plant) => _buildPlantCard(plant)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlantCard(FocusPlant plant) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: plant.isAlive
            ? plant.type.primaryColor.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plant.isAlive
              ? plant.type.primaryColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            plant.isAlive ? plant.type.emoji : '🥀',
            style: TextStyle(
              fontSize: 32,
              color: plant.isAlive ? null : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${plant.durationMinutes}m',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: plant.isAlive ? plant.type.primaryColor : Colors.grey,
            ),
          ),
          Text(
            DateFormat('h:mm a').format(plant.plantedAt),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌱', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'Your garden is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Complete focus sessions to grow plants!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
