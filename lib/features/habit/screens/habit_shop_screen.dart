import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/gamification_service.dart';
import '../theme/habit_theme.dart';

/// Shop Screen - Purchase items for house decoration
class HabitShopScreen extends StatefulWidget {
  const HabitShopScreen({super.key});

  @override
  State<HabitShopScreen> createState() => _HabitShopScreenState();
}

class _HabitShopScreenState extends State<HabitShopScreen> {
  final GamificationService _gamificationService = GamificationService();
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Furniture', 'Decoration'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HabitTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Shop', style: HabitTheme.h1),
        centerTitle: true,
        actions: [
          // Coins display
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: HabitTheme.cream,
              borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.orange, size: 18),
                const SizedBox(width: 4),
                ListenableBuilder(
                  listenable: _gamificationService,
                  builder: (context, _) {
                    return Text(
                      '${_gamificationService.coins}',
                      style: HabitTheme.b2.copyWith(fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category tabs
          _buildCategoryTabs(),
          // Items grid
          Expanded(child: _buildItemsGrid()),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCategory = category);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? HabitTheme.primary : HabitTheme.white,
                borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                boxShadow: HabitTheme.subtleShadow,
              ),
              child: Text(
                category,
                style: HabitTheme.b2.copyWith(
                  color: isSelected ? HabitTheme.white : HabitTheme.gray,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemsGrid() {
    final items = _gamificationService.getShopItems();
    final filteredItems = _selectedCategory == 'All'
        ? items
        : items.where((i) => 
            i.category.toLowerCase() == _selectedCategory.toLowerCase()
          ).toList();

    return ListenableBuilder(
      listenable: _gamificationService,
      builder: (context, _) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final isOwned = _gamificationService.isItemOwned(item.id);
            
            return _buildShopItem(item, isOwned);
          },
        );
      },
    );
  }

  Widget _buildShopItem(ShopItem item, bool isOwned) {
    return GestureDetector(
      onTap: isOwned ? null : () => _showPurchaseDialog(item),
      child: Container(
        decoration: BoxDecoration(
          color: HabitTheme.white,
          borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
          boxShadow: HabitTheme.subtleShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item image
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HabitTheme.grayLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(HabitTheme.radiusL),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getItemIcon(item.category),
                        size: 48,
                        color: HabitTheme.primary.withOpacity(0.5),
                      ),
                    ),
                    if (isOwned)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HabitTheme.success,
                            borderRadius: BorderRadius.circular(HabitTheme.radiusS),
                          ),
                          child: Text(
                            'Owned',
                            style: HabitTheme.caption.copyWith(
                              color: HabitTheme.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Item info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: HabitTheme.b2.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOwned ? 'Purchased' : '${item.price}',
                        style: HabitTheme.b3.copyWith(
                          color: isOwned ? HabitTheme.success : HabitTheme.dark,
                          fontWeight: FontWeight.w600,
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

  IconData _getItemIcon(String category) {
    return switch (category.toLowerCase()) {
      'furniture' => Icons.chair,
      'decoration' => Icons.emoji_objects,
      _ => Icons.category,
    };
  }

  void _showPurchaseDialog(ShopItem item) {
    final canAfford = _gamificationService.coins >= item.price;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        ),
        title: Text(item.name, style: HabitTheme.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: HabitTheme.grayLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(HabitTheme.radiusL),
              ),
              child: Icon(
                _getItemIcon(item.category),
                size: 48,
                color: HabitTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.description,
              style: HabitTheme.b2.copyWith(color: HabitTheme.gray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '${item.price} coins',
                  style: HabitTheme.h2.copyWith(
                    color: canAfford ? HabitTheme.dark : HabitTheme.error,
                  ),
                ),
              ],
            ),
            if (!canAfford) ...[
              const SizedBox(height: 8),
              Text(
                'Not enough coins!',
                style: HabitTheme.b3.copyWith(color: HabitTheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: canAfford
                ? () async {
                    final success = await _gamificationService.purchaseItem(item.id);
                    if (mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Purchased ${item.name}!'),
                            backgroundColor: HabitTheme.success,
                          ),
                        );
                      }
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: HabitTheme.primary,
              foregroundColor: HabitTheme.white,
            ),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }
}
