import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/constants/app_colors.dart';
import '../models/focus_coins.dart';
import '../services/coins_service.dart';

/// Height a shop tile needs at 1.0x text: 32 padding + 48pt emoji line +
/// 12 + name + 4 + two description lines + the price chip.
const double _treeTileMinExtent = 208;

class PlantRealTreesScreen extends StatefulWidget {
  const PlantRealTreesScreen({super.key});

  @override
  State<PlantRealTreesScreen> createState() => _PlantRealTreesScreenState();
}

class _PlantRealTreesScreenState extends State<PlantRealTreesScreen> {
  final CoinsService _coinsService = CoinsService();
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _coinsService.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _coinsService,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildCoinsHeader()),
                SliverToBoxAdapter(child: _buildTabBar()),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: _selectedTab == 0
                      ? _buildTreeShop()
                      : _selectedTab == 1
                          ? _buildMyForest()
                          : _buildTransactions(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
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
      title: const Text(
        'Plant Real Trees',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCoinsHeader() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The coin balance takes the leftover width; the trees badge
              // keeps its natural size but may shrink its label.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_coinsService.totalCoins}',
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Available Coins',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('🌍', style: TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_coinsService.treesPlanted}',
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Trees Planted',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildImpactStat(
                      '${_coinsService.totalCO2Offset} kg', 'CO₂ Offset'),
                ),
                Container(width: 1, height: 30, color: Colors.white24),
                Expanded(
                  child: _buildImpactStat(
                      '${_coinsService.lifetimeCoins}', 'Lifetime Coins'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStat(String value, String label) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildTab('Shop', 0),
          const SizedBox(width: 12),
          _buildTab('My Forest', 1),
          const SizedBox(width: 12),
          _buildTab('History', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.getGrey200(context),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreeShop() {
    // The tile is text-driven (emoji + name + 2-line blurb + price chip), so a
    // pure aspect ratio clips it on narrow phones — 0.75 of a 320pt phone's
    // 128pt column is only 171pt for ~202pt of content. Keep the designed
    // ratio wherever it is already tall enough and grow it otherwise.
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    // Column width inside the sliver's 24pt padding, 2 columns, 16pt gap.
    final columnWidth = (MediaQuery.sizeOf(context).width - 48 - 16) / 2;
    final tileExtent =
        math.max(columnWidth / 0.75, _treeTileMinExtent * textScale);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: tileExtent,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final treeType = RealTreeType.values[index];
          return _buildTreeCard(treeType);
        },
        childCount: RealTreeType.values.length,
      ),
    );
  }

  Widget _buildTreeCard(RealTreeType treeType) {
    final canAfford = _coinsService.canAfford(treeType);
    
    return GestureDetector(
      onTap: canAfford ? () => _showPlantConfirmation(treeType) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canAfford ? treeType.color.withOpacity(0.3) : AppColors.getGrey200(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                treeType.emoji,
                style: TextStyle(
                  fontSize: 48,
                  color: canAfford ? null : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              treeType.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: canAfford
                    ? AppColors.getTextPrimary(context)
                    : AppColors.getTextSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              treeType.description,
              style: TextStyle(
                fontSize: 10,
                color: canAfford
                    ? AppColors.getTextSecondary(context)
                    : AppColors.getTextLight(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: canAfford ? treeType.color.withOpacity(0.1) : AppColors.getGrey100(context),
                borderRadius: BorderRadius.circular(10),
              ),
              // The chip is only ~72pt wide inside a 320pt-phone tile, so the
              // coin + price pair scales down together rather than spilling.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${treeType.coinCost}',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: canAfford
                            ? treeType.color
                            : AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyForest() {
    final trees = _coinsService.plantedTrees;
    
    if (trees.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🌍', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                'Your forest is empty',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Plant your first real tree!',
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

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildPlantedTreeCard(trees[index]),
        childCount: trees.length,
      ),
    );
  }

  Widget _buildPlantedTreeCard(RealTreePlanting tree) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tree.treeType.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(tree.treeType.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tree.treeType.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '📍 ${tree.location ?? "Unknown location"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                Text(
                  '🏢 ${tree.partnerOrganization ?? "Partner organization"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(tree.plantedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🌱 Growing',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactions() {
    final transactions = _coinsService.transactions;
    
    if (transactions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📜', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete focus sessions to earn coins!',
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

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildTransactionCard(transactions[index]),
        childCount: transactions.length,
      ),
    );
  }

  Widget _buildTransactionCard(CoinTransaction transaction) {
    final isEarned = transaction.type != CoinTransactionType.spent;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEarned 
                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                  : const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                transaction.type.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  transaction.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isEarned ? '+' : '-'}${transaction.amount}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isEarned ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlantConfirmation(RealTreeType treeType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getGrey300(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(treeType.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Plant a ${treeType.name}?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              treeType.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  '${treeType.coinCost} coins',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: treeType.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final success = await _coinsService.plantRealTree(treeType);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🌱 ${treeType.name} planted!'),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: treeType.color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Plant Tree 🌱',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
