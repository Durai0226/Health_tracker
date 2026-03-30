import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/gamification_service.dart';
import '../theme/habit_theme.dart';

/// Collections Screen - World famous buildings
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gamificationService = GamificationService();

    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HabitTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Collections', style: HabitTheme.h1),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: gamificationService,
        builder: (context, _) {
          final collections = gamificationService.collections;
          final unlockedCount = gamificationService.unlockedCollectionsCount;

          return Column(
            children: [
              // Progress header
              _buildProgressHeader(unlockedCount, collections.length),
              // Collections list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return _buildCollectionCard(
                      context,
                      collection,
                      gamificationService.totalPoints,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(int unlocked, int total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: HabitTheme.primaryGradient,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: HabitTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: HabitTheme.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: HabitTheme.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'World Famous Buildings',
                  style: HabitTheme.b1.copyWith(
                    color: HabitTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unlocked / $total collected',
                  style: HabitTheme.b3.copyWith(
                    color: HabitTheme.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: total > 0 ? unlocked / total : 0,
                  backgroundColor: HabitTheme.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(HabitTheme.white),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(
    BuildContext context,
    CollectionBuilding collection,
    int totalPoints,
  ) {
    final isUnlocked = collection.isUnlocked;
    final progress = totalPoints / collection.pointsRequired;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        children: [
          // Image area
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? HabitTheme.cream
                  : HabitTheme.grayLight.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Stack(
              children: [
                // Building illustration placeholder
                Center(
                  child: Icon(
                    isUnlocked ? Icons.location_city : Icons.lock_outline,
                    size: 64,
                    color: isUnlocked
                        ? HabitTheme.primary
                        : HabitTheme.gray.withOpacity(0.5),
                  ),
                ),
                // Unlocked badge
                if (isUnlocked)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: HabitTheme.success,
                        borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            color: HabitTheme.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Collected',
                            style: HabitTheme.caption.copyWith(
                              color: HabitTheme.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection.name,
                            style: HabitTheme.h2,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: HabitTheme.gray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                collection.location,
                                style: HabitTheme.b3,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Points required
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? HabitTheme.success.withOpacity(0.1)
                            : HabitTheme.primarySoft,
                        borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: isUnlocked
                                ? HabitTheme.success
                                : HabitTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${collection.pointsRequired}',
                            style: HabitTheme.b2.copyWith(
                              color: isUnlocked
                                  ? HabitTheme.success
                                  : HabitTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isUnlocked) ...[
                  const SizedBox(height: 12),
                  // Progress bar
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: HabitTheme.grayLight,
                    valueColor: const AlwaysStoppedAnimation(HabitTheme.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalPoints / ${collection.pointsRequired} points',
                    style: HabitTheme.caption,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  collection.description,
                  style: HabitTheme.b3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
