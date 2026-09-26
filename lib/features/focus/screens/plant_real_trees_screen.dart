import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
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
      backgroundColor: AppColorsExt.of(context).background,
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
                  padding: const EdgeInsets.all(AppSpacing.xl),
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
      backgroundColor: AppColorsExt.of(context).background,
      leading: IconButton(
        // Announced as just "button" by TalkBack and VoiceOver without this.
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColorsExt.of(context).surface,
            borderRadius: AppRadius.brMd,
          ),
          child: const Icon(Symbols.arrow_back_rounded, size: 20),
        ),
      ),
      title: Text(
        'Garden Shop',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  /// The coin balance, on the AA-verified `steps` fill pair.
  ///
  /// `steps` rather than `focus`: this header is green because the reward is a
  /// tree, and the Focus violet on a green card was what produced the previous
  /// mismatch (violet coin icons on a hardcoded #4CAF50). The two inner panels
  /// are OUTLINED rather than filled with translucent white on purpose — a
  /// white@0.15 wash lifts the ground under its own labels to 3.82:1, where the
  /// solid fill leaves every label at the pair's measured 5.02:1 (light) /
  /// 8.55:1 (dark).
  Widget _buildCoinsHeader() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final fg = ext.fillFg(ext.steps);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: ext.fillBg(ext.steps),
        borderRadius: AppRadius.brCard,
        boxShadow: AppShadows.card(context),
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
                        Icon(Symbols.toll_rounded, size: 30, color: fg),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_coinsService.totalCoins}',
                              maxLines: 1,
                              softWrap: false,
                              style: tt.displayMedium?.copyWith(color: fg),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Available Coins',
                        maxLines: 1,
                        softWrap: false,
                        style: tt.bodyMedium?.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.brLg,
                    border: Border.all(color: fg.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Icon(Symbols.park_rounded, size: 22, color: fg),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_coinsService.treesPlanted}',
                          maxLines: 1,
                          softWrap: false,
                          style: tt.headlineMedium?.copyWith(color: fg),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Trees Planted',
                          maxLines: 1,
                          softWrap: false,
                          style: tt.labelSmall?.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brLg,
              border: Border.all(color: fg.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildImpactStat(
                      '${_coinsService.coins.coinsSpentOnTrees}', 'Coins Spent'),
                ),
                Container(width: 1, height: 30, color: fg.withOpacity(0.4)),
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final fg = ext.fillFg(ext.steps);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: tt.headlineSmall?.copyWith(color: fg),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: tt.bodySmall?.copyWith(color: fg),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          _buildTab('Shop', 0),
          const SizedBox(width: AppSpacing.md),
          _buildTab('My Forest', 1),
          const SizedBox(width: AppSpacing.md),
          _buildTab('History', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          // 14 + 16 (labelLarge line box) + 14 = 44. At AppSpacing.md this
          // measured 42x42 — under the Apple HIG comfort minimum, on the
          // control that switches the whole screen.
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? ext.fillBg(ext.focus) : ext.surface,
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: isSelected ? ext.fillBg(ext.focus) : ext.outline,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: tt.labelLarge?.copyWith(
                color: isSelected ? ext.fillFg(ext.focus) : ext.textPrimary,
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final canAfford = _coinsService.canAfford(treeType);

    return GestureDetector(
      onTap: canAfford
          ? () => _showPlantConfirmation(treeType)
          // Was a null onTap: a tile the user can see, wants, and taps, that
          // does nothing at all. Say what it costs instead.
          : () => context.toastInfo(
                '${treeType.name} costs ${treeType.coinCost} coins — you have '
                '${_coinsService.totalCoins}. Finish a focus session to earn more.',
              ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: AppRadius.brCard,
          border: Border.all(
            color: canAfford ? treeType.color.withOpacity(0.3) : ext.outline,
          ),
          boxShadow: AppShadows.resting(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Opacity(
                opacity: canAfford ? 1 : 0.4,
                // emoji-content-ok: the species IS the product being bought
                child: Text(treeType.emoji, style: const TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              treeType.name,
              style: tt.titleSmall?.copyWith(
                color: canAfford ? ext.textPrimary : ext.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              treeType.description,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: canAfford ? ext.textSecondary : ext.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: canAfford
                    ? treeType.color.withOpacity(0.1)
                    : ext.surfaceVariant,
                borderRadius: AppRadius.brSm,
              ),
              // The chip is only ~72pt wide inside a 320pt-phone tile, so the
              // coin + price pair scales down together rather than spilling.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The price reads in a TOKEN colour, not the species tint.
                    // `RealTreeType.color` is decoration — Cherry's #F8BBD9
                    // measures 1.31:1 as text on the card surface — so the tint
                    // stays on the chip fill and the number takes `mark(steps)`
                    // (5.02:1 light / 8.03:1 dark).
                    Icon(Symbols.toll_rounded,
                        size: 14,
                        color: canAfford
                            ? ext.mark(ext.steps)
                            : ext.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${treeType.coinCost}',
                      maxLines: 1,
                      softWrap: false,
                      style: tt.labelLarge?.copyWith(
                        color: canAfford
                            ? ext.mark(ext.steps)
                            : ext.textSecondary,
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
              Icon(Symbols.park_rounded, size: 56, color: AppColorsExt.of(context).textTertiary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Your forest is empty',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Redeem coins to grow your garden',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColorsExt.of(context).textSecondary,
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brCard,
        boxShadow: AppShadows.resting(context),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tree.treeType.color.withOpacity(0.1),
              borderRadius: AppRadius.brLg,
            ),
            child: Center(
              // emoji-content-ok: the species the user redeemed
              child: Text(tree.treeType.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tree.treeType.name, style: tt.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                // The two lines that used to sit here rendered
                // `tree.location` and `tree.partnerOrganization` as fact. Both
                // were fabricated at redemption time — the location by
                // `Random()` from eight countries, the partner hardcoded to a
                // real charity with no agreement in place. Replaced with the one
                // thing the app actually knows about this record.
                Row(
                  children: [
                    Icon(Symbols.toll_rounded,
                        size: 14, color: ext.mark(ext.steps)),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '${tree.coinsCost} coins',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(tree.plantedAt),
                style: tt.bodySmall?.copyWith(color: ext.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: ext.steps.container,
                  borderRadius: AppRadius.brSm,
                ),
                // Was a hardcoded '🌱 Growing' badge on every row — a live
                // status for a tree that does not exist anywhere.
                child: Text(
                  'In your garden',
                  style: tt.labelSmall?.copyWith(color: ext.steps.onContainer),
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
              Icon(Symbols.receipt_long_rounded, size: 56, color: AppColorsExt.of(context).textTertiary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Complete focus sessions to earn coins',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColorsExt.of(context).textSecondary,
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

  /// A Material Symbol per transaction kind.
  ///
  /// The badge used `CoinTransactionType.emoji` at 20pt inside a tinted
  /// container — chrome by the emoji guard's own definition, so it could not
  /// take the badge colour and rendered differently on every OS. The mapping
  /// lives here rather than on the enum because `focus_coins.dart` is a model
  /// and has no business importing an icon set.
  IconData _transactionIcon(CoinTransactionType type) {
    switch (type) {
      case CoinTransactionType.earned:
        return Symbols.savings_rounded;
      case CoinTransactionType.spent:
        return Symbols.park_rounded;
      case CoinTransactionType.bonus:
        return Symbols.redeem_rounded;
      case CoinTransactionType.streakBonus:
        return Symbols.local_fire_department_rounded;
      case CoinTransactionType.achievementBonus:
        return Symbols.trophy_rounded;
      case CoinTransactionType.referralBonus:
        return Symbols.group_rounded;
    }
  }

  Widget _buildTransactionCard(CoinTransaction transaction) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final isEarned = transaction.type != CoinTransactionType.spent;
    // Earned/spent is the only distinction this row makes, so it takes the two
    // semantic swatches rather than a hardcoded green/blue pair.
    final swatch = isEarned ? ext.steps : ext.info;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brLg,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: swatch.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Center(
              child: Icon(_transactionIcon(transaction.type),
                  size: 22, color: swatch.onContainer),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.type.name, style: tt.titleSmall),
                Text(
                  transaction.description,
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${isEarned ? '+' : '-'}${transaction.amount}',
            style: tt.titleLarge?.copyWith(color: ext.mark(swatch)),
          ),
        ],
      ),
    );
  }

  /// Confirm a redemption.
  ///
  /// Routed through [AppBottomSheet] rather than a hand-drawn sheet: the sheet
  /// used `backgroundColor: transparent` with its own 28pt corners and its own
  /// grab handle, so it carried neither the theme's `topSheet` radius (24) nor
  /// its `dragHandleColor`.
  void _showPlantConfirmation(RealTreeType treeType) {
    AppBottomSheet.show(
      context,
      accent: AppColorsExt.of(context).steps,
      builder: (sheetContext) {
        final ext = AppColorsExt.of(sheetContext);
        final tt = Theme.of(sheetContext).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // emoji-content-ok: the species being redeemed, shown at hero size
            Text(treeType.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.lg),
            Text('Add a ${treeType.name}?',
                textAlign: TextAlign.center, style: tt.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              treeType.description,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.toll_rounded, size: 22, color: ext.mark(ext.steps)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${treeType.coinCost} coins',
                  style: tt.headlineSmall?.copyWith(color: ext.mark(ext.steps)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: AppButton(
                    label: 'Add to garden',
                    accent: ext.steps,
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final success =
                          await _coinsService.redeemGardenTree(treeType);
                      if (success && mounted) {
                        context.toastSuccess(
                            '${treeType.name} added to your garden');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
