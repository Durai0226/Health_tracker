import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/utils/percent_format.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/focus_achievement.dart';
import '../services/focus_service.dart';

/// Every focus achievement: what is earned, and how far along the rest are.
///
/// They were reachable only inside Statistics, and there only as the six most
/// recent and the three nearest — so most of the twenty-four were never shown, and
/// "what is there to earn?" had no answer.
class FocusAchievementsScreen extends StatelessWidget {
  const FocusAchievementsScreen({super.key});

  /// Earned ones, newest first.
  static List<FocusAchievement> earned(Iterable<FocusAchievement> all) => [
        for (final a in all)
          if (a.isUnlocked) a
      ]..sort((a, b) =>
          (b.unlockedAt ?? DateTime(0)).compareTo(a.unlockedAt ?? DateTime(0)));

  /// The rest, nearest first — and a tie in the order the list is declared, so
  /// the order does not shuffle from one visit to the next.
  static List<FocusAchievement> inProgress(Iterable<FocusAchievement> all) {
    final order = {for (final t in AchievementType.values) t: t.index};
    return [
      for (final a in all)
        if (!a.isUnlocked) a
    ]..sort((a, b) {
        final byProgress = b.progressPercent.compareTo(a.progressPercent);
        return byProgress != 0 ? byProgress : order[a.type]!.compareTo(order[b.type]!);
      });
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final service = FocusService();

    return AccentScope(
      feature: FeatureAccent.focus,
      child: AppScaffold(
        body: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final all = service.achievements.values.toList();
            final done = earned(all);
            final rest = inProgress(all);
            return Column(
              children: [
                AppHeader(
                  title: 'Achievements',
                  leading: AppHeader.backButton(context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                    children: [
                      Text(
                        '${done.length} of ${all.length} earned',
                        style: tt.titleMedium?.copyWith(color: ext.textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (done.isNotEmpty) ...[
                        SectionHeader(
                          title: 'Earned',
                          icon: Symbols.workspace_premium_rounded,
                          accent: ext.focus,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          child: Column(
                            children: [
                              for (final a in done) _Row(achievement: a),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (rest.isNotEmpty) ...[
                        SectionHeader(
                          title: 'Still to earn',
                          icon: Symbols.flag_rounded,
                          accent: ext.focus,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          child: Column(
                            children: [
                              for (final a in rest) _Row(achievement: a),
                            ],
                          ),
                        ),
                      ],
                      if (all.isEmpty)
                        EmptyState(
                          icon: Symbols.workspace_premium_rounded,
                          title: 'Nothing here yet',
                          message: 'Finish a focus session and your first '
                              'achievement is a short way off.',
                          accent: ext.focus,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.achievement});

  final FocusAchievement achievement;

  /// "Gold · 50 coins".
  static String reward(AchievementType t) {
    final tier = t.tier.name;
    return '${tier[0].toUpperCase()}${tier.substring(1)} · ${t.coinReward} coins';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final a = achievement;
    final when = a.unlockedAt == null
        ? null
        : DateFormats.dayLabel(a.unlockedAt!, reference: clock.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          // A fixed box, so a wide emoji cannot move the text column between rows.
          SizedBox(
            width: 32,
            child: Text(
              a.type.emoji, // emoji-content-ok: the achievement's own badge
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.type.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: a.isUnlocked ? ext.textPrimary : ext.textSecondary,
                  ),
                ),
                Text(
                  a.type.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
                Text(
                  a.isUnlocked && when != null
                      ? 'Earned $when · ${reward(a.type)}'
                      : reward(a.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (a.isUnlocked)
            Icon(Symbols.check_circle_rounded,
                size: 20, color: ext.mark(ext.success))
          else
            Text(
              Pct.text(a.progressPercent),
              style: tt.labelSmall?.copyWith(
                color: ext.textSecondary,
                fontWeight: FontWeight.w700,
                fontFeatures: kTabular,
              ),
            ),
        ],
      ),
    );
  }
}
