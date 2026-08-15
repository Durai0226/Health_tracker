import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/constants/app_colors.dart';
import '../models/focus_plant.dart';
import '../services/focus_service.dart';

class FocusGardenScreen extends StatelessWidget {
  const FocusGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusService = FocusService();
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
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
                  // hasScrollBody: false sizes the sliver to max(remaining
                  // space, the empty state's own height) instead of forcing it
                  // into the leftover viewport — at 200% text the illustration
                  // and copy are taller than what's left under the header, and
                  // the forced fit clipped them by 210px.
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
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

    // FlexibleSpaceBar always lays its background out at exactly `expandedHeight`,
    // so a flat 200 clipped the title block by 18px at 200% text. 104 of that
    // header is fixed chrome (60 + 24 padding and the 20 gap); the rest is text
    // and has to grow with the user's text size. At 1.0x this is still 200.
    final double expandedHeight =
        104 + MediaQuery.textScalerOf(context).scale(96);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.getBackground(context),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Symbols.arrow_back_rounded, size: 20),
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
                AppColors.getBackground(context),
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
                      // Flexible so the title block shares the row instead of
                      // pushing past the right edge on narrow phones.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Garden',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$alivePlants alive • $deadPlants withered',
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
      dateLabel = DateFormats.weekdayDayMonthLong.format(date);
    }
    
    final totalMinutes = plants.fold(0, (sum, p) => sum + p.durationMinutes);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 'Wednesday, September 10' is the widest label this can hold; at
            // large text sizes it has to share the row with the total instead
            // of pushing it off the right edge.
            Expanded(
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '$totalMinutes min',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: plants.map((plant) => _buildPlantCard(context, plant)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlantCard(BuildContext context, FocusPlant plant) {
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
          // The card is a fixed 100 wide, so the duration and timestamp use
          // scaleDown (never enlarges — default rendering is untouched) rather
          // than wrapping "12:30 PM" onto two lines at large text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${plant.durationMinutes}m',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: plant.isAlive ? plant.type.primaryColor : Colors.grey,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              DateFormats.time.format(plant.plantedAt),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        // Gutter + breathing room so the copy wraps inside the screen rather
        // than running to the very edge once it is twice the size.
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Your garden is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete focus sessions to grow plants!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
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
