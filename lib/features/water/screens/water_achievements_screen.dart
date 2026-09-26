import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import '../models/water_achievement.dart';
import '../services/water_service.dart';

/// Achievements Screen - Gamification with badges and streaks
class WaterAchievementsScreen extends StatefulWidget {
  const WaterAchievementsScreen({super.key});

  @override
  State<WaterAchievementsScreen> createState() => _WaterAchievementsScreenState();
}

class _WaterAchievementsScreenState extends State<WaterAchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserAchievements _userAchievements;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userAchievements = WaterService.getAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: CustomScrollView(
        slivers: [
          // This was the last chunky solid-colour `SliverAppBar` in the app: a
          // teal bar with its own gradient, a raw untooltipped `IconButton`, a
          // bold white title and an amber trophy on teal (3.29:1).
          //
          // The old bar was `pinned: true`, so this DOES change behaviour: the
          // title no longer sticks to the top on scroll. That is deliberate and
          // is the point of the conversion — `AppHeader`'s contract is that a
          // header belongs in the scroll body and scrolls away, which is how
          // the other 67 screens using it behave. A single screen keeping a
          // sticky title is the inconsistency, not the fix.
          SliverToBoxAdapter(
            child: AppHeader(
              title: 'Achievements',
              leading: AppHeader.backButton(context),
            ),
          ),
          SliverToBoxAdapter(child: _buildStatsHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyTabBarDelegate(
              tabBar: CommonTabBar(
                tabs: const ['All', 'Unlocked', 'Locked'],
                controller: _tabController,
              ),
            ),
          ),
          SliverFillRemaining(
            child: CommonTabView(
              controller: _tabController,
              children: [
                _buildAllAchievements(),
                _buildUnlockedAchievements(),
                _buildLockedAchievements(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    // DS-01. What was here: an amber-400 -> orange-400 gradient (#FFCA28 ->
    // #FFA726) with an amber glow, white 18pt values on it (1.53:1 and
    // 1.94:1 against those two stops), white-at-80% 11pt labels (worse still)
    // and a white progress bar. `fillBg`/`fillFg` is the palette's AA-verified filled-
    // control pair — the same one every primary button uses — so the card can
    // stay amber and the text on it can be read.
    final fill = ext.fillBg(ext.reminders);
    final onFill = ext.fillFg(ext.reminders);
    return AppCard(
      margin: const EdgeInsets.all(AppSpacing.lg),
      color: fill,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Symbols.emoji_events_rounded,
                  value: '${_userAchievements.unlockedAchievements.length}'
                      '/${_userAchievements.achievements.length}',
                  label: 'Unlocked',
                  onFill: onFill,
                ),
              ),
              _StatDivider(color: onFill),
              Expanded(
                child: _buildStatItem(
                  icon: Symbols.stars_rounded,
                  value: '${_userAchievements.totalPoints}',
                  label: 'Total Points',
                  onFill: onFill,
                ),
              ),
              _StatDivider(color: onFill),
              Expanded(
                child: _buildStatItem(
                  icon: Symbols.local_fire_department_rounded,
                  value: '${_userAchievements.currentStreak}',
                  label: 'Day Streak',
                  onFill: onFill,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // The level line the trophy count used to sit in the app bar for.
          Text(
            'Level ${_userAchievements.level} · '
            '${_userAchievements.pointsToNextLevel} to next',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: onFill),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.brSm,
            child: LinearProgressIndicator(
              value: (_userAchievements.totalPoints % 100) / 100,
              // A track derived from the foreground, so it reads on the fill in
              // both themes rather than being a hardcoded `Colors.white24`.
              backgroundColor: onFill.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation(onFill),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color onFill,
  }) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: onFill, size: 28),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: tt.headlineSmall?.copyWith(color: onFill),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          // bodySmall (12) rather than the old 11-at-80%-alpha: the label is
          // the half of the pair that was hardest to read.
          style: tt.bodySmall?.copyWith(color: onFill),
        ),
      ],
    );
  }

  Widget _buildAllAchievements() {
    return _buildAchievementList(_userAchievements.achievements);
  }

  Widget _buildUnlockedAchievements() {
    return _buildAchievementList(_userAchievements.unlockedAchievements);
  }

  Widget _buildLockedAchievements() {
    return _buildAchievementList(_userAchievements.lockedAchievements);
  }

  Widget _buildAchievementList(List<WaterAchievement> achievements) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    if (achievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.emoji_events_rounded,
                size: 64, color: ext.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No achievements yet',
              style: tt.bodyLarge?.copyWith(color: ext.textSecondary),
            ),
          ],
        ),
      );
    }

    // Group by type
    final groupedAchievements = <AchievementType, List<WaterAchievement>>{};
    for (final a in achievements) {
      groupedAchievements.putIfAbsent(a.type, () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedAchievements.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: _getTypeLabel(entry.key),
              icon: _typeIcon(entry.key),
              accent: ext.reminders,
            ),
            ...entry.value.map((a) => _buildAchievementCard(a)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  String _getTypeLabel(AchievementType type) {
    switch (type) {
      case AchievementType.streak:
        return 'Streaks';
      case AchievementType.totalVolume:
        return 'Total Volume';
      case AchievementType.variety:
        return 'Variety';
      case AchievementType.earlyBird:
        return 'Early Bird';
      case AchievementType.perfectWeek:
        return 'Perfect Week';
      case AchievementType.perfectMonth:
        return 'Perfect Month';
      case AchievementType.overachiever:
        return 'Overachiever';
      case AchievementType.caffeineControl:
        return 'Caffeine Control';
      case AchievementType.socialDrinker:
        return 'Alcohol-Free';
      default:
        return 'Achievements';
    }
  }

  /// DS-17: the group heading's leading glyph. These labels used to carry the
  /// emoji INSIDE the string ('🔥 Streaks', '☯️ Caffeine Control'), which put
  /// decoration in the accessibility label as well as on screen — a screen
  /// reader announced the codepoint's name before the heading. [SectionHeader]
  /// takes an `IconData` and paints it in the accent chip every other section
  /// heading in the app uses.
  IconData _typeIcon(AchievementType type) {
    switch (type) {
      case AchievementType.streak:
        return Symbols.local_fire_department_rounded;
      case AchievementType.totalVolume:
        return Symbols.water_drop_rounded;
      case AchievementType.variety:
        return Symbols.palette_rounded;
      case AchievementType.earlyBird:
        return Symbols.wb_twilight_rounded;
      case AchievementType.perfectWeek:
      case AchievementType.perfectMonth:
        return Symbols.star_rounded;
      case AchievementType.overachiever:
        return Symbols.rocket_launch_rounded;
      case AchievementType.caffeineControl:
        return Symbols.coffee_rounded;
      case AchievementType.socialDrinker:
        return Symbols.no_drinks_rounded;
      case AchievementType.consistency:
        return Symbols.event_repeat_rounded;
      case AchievementType.nightOwl:
        return Symbols.bedtime_rounded;
    }
  }

  /// The badge art for one achievement.
  ///
  /// The model carries an `emoji` per achievement, rendered at 28pt inside a
  /// 56pt tinted tile and at 40pt in the detail sheet — badge-sized chrome in a
  /// decorated container, which is the definition DS-17 draws the line at. It
  /// is derived from the achievement's TYPE, so a Symbol keyed off the same
  /// enum carries exactly the same information in the app's own icon font.
  IconData _achievementIcon(WaterAchievement a) => _typeIcon(a.type);

  Widget _buildAchievementCard(WaterAchievement achievement) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final isUnlocked = achievement.isUnlocked;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showAchievementDetails(achievement);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isUnlocked ? ext.surface : ext.surfaceVariant,
          borderRadius: AppRadius.brCard,
          // An amber hairline still marks "unlocked", but the amber GLOW is
          // gone: the card now casts the same shadow as every AppCard.
          border: isUnlocked
              ? Border.all(color: ext.mark(ext.warning), width: 2)
              : null,
          boxShadow: isUnlocked ? AppShadows.card(context) : null,
        ),
        child: Row(
          // The details column is taller than the 56pt icon tile, so the default
          // centre alignment floated the 🔒 / emoji tile mid-row with a big gap
          // above it while the title sat at the top. Top-align them.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? ext.reminders.container
                    : ext.surfaceVariant,
                borderRadius: AppRadius.brMd,
              ),
              child: Center(
                child: Icon(
                  isUnlocked
                      ? _achievementIcon(achievement)
                      : Symbols.lock_rounded,
                  size: 28,
                  color: isUnlocked
                      ? ext.reminders.onContainer
                      : ext.textTertiary,
                  applyTextScaling: false,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: tt.titleMedium?.copyWith(
                            color: isUnlocked
                                ? ext.textPrimary
                                : ext.textSecondary,
                          ),
                        ),
                      ),
                      // emoji-content-ok: the tier medal (🥉/🥈/🥇/💎) is the
                      // rank itself, rendered inline at body size rather than
                      // as a badge in a decorated container — and unlike the
                      // achievement art it is not derivable from an enum the
                      // icon font has a glyph for.
                      Text(achievement.tierEmoji, style: tt.bodyLarge),
                      const SizedBox(width: AppSpacing.sm),
                      // Points badge. It lives INSIDE the details column rather
                      // than beside it so that it shares a right edge with the
                      // progress counter two rows below — as a sibling of the
                      // column the two right-hand values sat ~19pt apart. Moving
                      // it in also gives the title/description/progress row the
                      // badge's width back.
                      _buildPointsBadge(achievement, isUnlocked),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    achievement.description,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: AppRadius.brSm,
                          child: LinearProgressIndicator(
                            value: achievement.progress,
                            backgroundColor: ext.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation(
                              isUnlocked
                                  ? ext.chartMark(ext.warning)
                                  : ext.chartMark(ext.water),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // "0/1000000" at large text sizes is wider than the whole
                      // column on a 320pt phone, so the counter is flexible and
                      // scales down rather than shoving the bar out of the row.
                      Flexible(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${achievement.currentValue}/${achievement.targetValue}',
                            maxLines: 1,
                            softWrap: false,
                            style: tt.labelMedium?.copyWith(
                              color: isUnlocked
                                  ? ext.mark(ext.warning)
                                  : ext.textSecondary,
                            ),
                          ),
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

  Widget _buildPointsBadge(WaterAchievement achievement, bool isUnlocked) {
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUnlocked ? ext.reminders.container : ext.surfaceVariant,
        borderRadius: AppRadius.brSm,
      ),
      child: Text(
        '+${achievement.points}',
        maxLines: 1,
        softWrap: false,
        // `onContainer` on `container`, not `amber.shade700` on the raw
        // surface — that pairing measured 2.04:1 on light.
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isUnlocked
                  ? ext.reminders.onContainer
                  : ext.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  void _showAchievementDetails(WaterAchievement achievement) {
    AppBottomSheet.show(
      context,
      title: achievement.title,
      icon: _achievementIcon(achievement),
      accent: AppColorsExt.of(context).reminders,
      builder: (ctx) {
        final ext = AppColorsExt.of(ctx);
        final tt = Theme.of(ctx).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // emoji-content-ok: the tier medal, as in the row above.
                Text(achievement.tierEmoji, style: tt.bodyLarge),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  achievement.tierName,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              achievement.description,
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: ext.water.container,
                borderRadius: AppRadius.brLg,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _sheetStat(ctx, '${achievement.currentValue}', 'Current',
                      ext.water.onContainer),
                  _sheetDivider(ext.water.onContainer),
                  _sheetStat(ctx, '${achievement.targetValue}', 'Target',
                      ext.water.onContainer),
                  _sheetDivider(ext.water.onContainer),
                  // Points was raw amber (#FFC107) as 24pt bold text on
                  // the surface: 1.79:1 on white. On this water container it
                  // reads in the container's own AA-verified foreground, and
                  // the amber lives in the badge on the row instead.
                  _sheetStat(ctx, '+${achievement.points}', 'Points',
                      ext.water.onContainer),
                ],
              ),
            ),
            if (achievement.isUnlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Unlocked on ${_formatDate(achievement.unlockedAt!)}',
                style: tt.labelLarge?.copyWith(color: ext.mark(ext.warning)),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sheetStat(
      BuildContext context, String value, String label, Color color) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: tt.displaySmall?.copyWith(color: color)),
        Text(label, style: tt.bodySmall?.copyWith(color: color)),
      ],
    );
  }

  Widget _sheetDivider(Color color) => Container(
        width: 1,
        height: 40,
        color: color.withOpacity(0.3),
      );

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// The hairline between two stats on the amber fill. Derived from the fill's
/// own foreground so it is visible in both themes — it used to be a hardcoded
/// `Colors.white24`, which is invisible on the light-mode amber.
class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 50,
        color: color.withOpacity(0.35),
      );
}
