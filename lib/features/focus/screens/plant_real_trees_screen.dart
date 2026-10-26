import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/focus_coins.dart';
import '../services/coins_service.dart';

/// Height a shop tile needs at 1.0x text: 32 padding + 48pt emoji line +
/// 12 + name + 4 + THREE description lines + the price chip.
///
/// 208 with a 2-line cap truncated every one of the eight blurbs — "Strong and
/// long-lasting, absorbs tons of CO2 o…" — while a bare `Spacer` below them
/// held 34.33pt of dead tile, about 2.4 unused `labelSmall` lines. The third
/// line costs one 14pt line box, so this is 208 + 14. Above ~376dp the tile is
/// already taller than this (the 0.75 ratio wins) and the constant does not
/// bind; below it, the extra line has to be paid for here or the tile overflows.
const double _treeTileMinExtent = 222;

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

  /// The coin balance, on the `success` CONTAINER pair.
  ///
  /// Green, not the Focus violet: this header is green because the reward is a
  /// tree, and violet on a green card was what produced the previous mismatch
  /// (violet coin icons on a hardcoded #4CAF50).
  ///
  /// `success` rather than `steps`, which this screen used to reach for. Green
  /// here means "a good outcome", which is what the semantic token is for;
  /// `steps` is the Steps FEATURE's identity colour, and `FeatureAccent` exists
  /// precisely so two features do not share one. The card the user taps to get
  /// here is already `accent: ext.success` (`focus_screen.dart`), so the
  /// destination now matches the door. The two swatches are both green and
  /// measure comparably (6.78:1 for the success pair), so this costs nothing
  /// visually and stops the screen claiming to be part of Steps.
  ///
  /// The pair is `container`/`onContainer`, not `fillBg`/`fillFg`. `fillBg` is
  /// documented as the ground for a FILLED CONTROL, and `mark()` returns the
  /// identical expression (`isDark ? s.base : s.strong`) — it is a colour sized
  /// for a button or a 20pt glyph. At 363x241pt it made this card #4ADE80,
  /// measuring 10.69:1 against the page where every other card on the screen
  /// measures 1.08:1: the header was an order of magnitude brighter than
  /// anything else on it. `app_palette.dart` had already measured that exact
  /// band and rejected it — "dark ALL SEVEN sit at L 0.68–0.80, outside the
  /// dark band 0.48–0.67" — but scoped the finding to chart marks, so no gate
  /// caught a surface. The container pair is the accent's large-area token:
  /// 1.05:1 (light) / 2.42:1 (dark) against the page, labels at 6.78:1.
  ///
  /// The two outlined inner panels are gone, and with them a hand-rolled
  /// `_buildImpactStat`. They were a re-implementation of `StatTile` /
  /// `StatTileRow`, which already give equal-width cells, a token divider and
  /// shrink-to-fit on both lines — and the outline they used, `fg@0.4`,
  /// measured 2.04:1 (light) / 2.10:1 (dark) against its own ground, under the
  /// 3:1 WCAG 1.4.11 asks of a component boundary. The row sits OUTSIDE the
  /// tinted card because `StatTile`'s label is `textSecondary`, measured
  /// against `ext.surface`.
  ///
  /// "Lifetime Coins" is gone because it was never independent:
  /// `lifetimeCoins == totalCoins + coinsSpentOnTrees` is an exact invariant of
  /// `CoinsService` — every credit adds to both, and the single debit
  /// subtracts from `totalCoins`, adds to `coinsSpentOnTrees` and never touches
  /// `lifetimeCoins`. Before any tree is bought that makes it equal to the
  /// balance, so the header printed the same number twice under two labels.
  Widget _buildCoinsHeader() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final fg = ext.success.onContainer;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: ext.success.container,
              borderRadius: AppRadius.brCard,
              // Matches AppCard: on dark, a hairline carries the edge that a
              // shadow cannot against a near-black page.
              border:
                  ext.isDark ? Border.all(color: ext.outline, width: 1) : null,
              boxShadow: AppShadows.card(context),
            ),
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
          const SizedBox(height: AppSpacing.md),
          // Outside the tinted card on purpose: StatTile draws its label in
          // `textSecondary`, which is measured against `ext.surface` and falls
          // below AA on a coloured fill.
          StatTileRow(
            tiles: [
              StatTile(
                icon: Symbols.park_rounded,
                value: '${_coinsService.treesPlanted}',
                label: 'Trees planted',
                accent: ext.success,
              ),
              StatTile(
                icon: Symbols.toll_rounded,
                value: '${_coinsService.coins.coinsSpentOnTrees}',
                label: 'Coins spent',
                accent: ext.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The shared toggle, on the screen's own accent.
  ///
  /// Was a hand-rolled 3-up `Row` of `GestureDetector`s. Two defects came with
  /// it. The labels had no `maxLines`, no `softWrap: false` and no `Flexible`,
  /// so at 411dp "My Forest" wrapped to two lines and the strip measured a
  /// ragged 46/62/46 — the exact bug `SegmentedToggle` documents having already
  /// fixed for its own segments. And the selected fill was `fillBg(ext.focus)`,
  /// the Focus violet, sitting directly beneath a green header on a screen
  /// whose header comment says violet-on-green was the mismatch it removed:
  /// the rule was applied to the card and not to the control under it.
  ///
  /// `accent: ext.success` keeps the one accent this screen commits to. The
  /// toggle also brings the selection haptic the hand-rolled version had not.
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: SegmentedToggle(
        accent: AppColorsExt.of(context).success,
        index: _selectedTab,
        onChanged: (i) => setState(() => _selectedTab = i),
        items: const [
          SegmentItem(icon: Symbols.storefront_rounded, label: 'Shop'),
          SegmentItem(icon: Symbols.park_rounded, label: 'My Forest'),
          SegmentItem(icon: Symbols.receipt_long_rounded, label: 'History'),
        ],
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
          // One token border for every species, affordable or not.
          //
          // Was `treeType.color.withOpacity(0.3)`, eight raw literals from the
          // model. Composited on the card they measured 1.16:1 (oak) to 2.13:1
          // (cherry) — an 84% spread carrying no meaning. With enough coins
          // every tile is in the SAME state, yet Maple drew a visible warm
          // border while Oak drew almost nothing, so the grid read as though
          // some tiles were selected. Affordability is already carried twice:
          // the 0.4 opacity below and the price chip.
          border: Border.all(color: ext.outline),
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                // Was `treeType.color.withOpacity(0.1)`: measured against the
                // card that is 1.05:1 (oak) to 1.24:1 (cherry) — Oak's chip
                // resolved to #1E1F24, three units of lift over the #171B22
                // card, i.e. no chip at all. The 0.1 alpha came from a
                // light-mode reading where a pale tint is legible; on dark it
                // vanishes. The accent's container token is the fill that is
                // meant to be seen at this size (1.90:1 dark / 1.10:1 light
                // against the card) and it pairs with `onContainer` below.
                color: canAfford ? ext.success.container : ext.surfaceVariant,
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
                    // measures 1.31:1 as text on the card surface — so the
                    // species never reaches the number. Now that the chip is
                    // filled with `container`, the number takes its documented
                    // partner `onContainer` (6.49:1 light / 7.52:1 dark on that
                    // fill) rather than `mark`, which is measured against the
                    // card surface and not against a chip sitting on it.
                    Icon(Symbols.toll_rounded,
                        size: 14,
                        color: canAfford
                            ? ext.success.onContainer
                            : ext.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${treeType.coinCost}',
                      maxLines: 1,
                      softWrap: false,
                      style: tt.labelLarge?.copyWith(
                        color: canAfford
                            ? ext.success.onContainer
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
                        size: 14, color: ext.mark(ext.success)),
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
                  color: ext.success.container,
                  borderRadius: AppRadius.brSm,
                ),
                // Was a hardcoded '🌱 Growing' badge on every row — a live
                // status for a tree that does not exist anywhere.
                child: Text(
                  'In your garden',
                  style: tt.labelSmall?.copyWith(color: ext.success.onContainer),
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
    final swatch = isEarned ? ext.success : ext.info;

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
      accent: AppColorsExt.of(context).success,
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
                Icon(Symbols.toll_rounded, size: 22, color: ext.mark(ext.success)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${treeType.coinCost} coins',
                  style: tt.headlineSmall?.copyWith(color: ext.mark(ext.success)),
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
                    accent: ext.success,
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
