import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'milestone.dart';
import 'milestones_service.dart';

/// A calm, private shelf of earned + not-yet milestones. Optionally filtered to
/// one [feature] ('steps' | 'sleep'); null shows both. No points, no ranking —
/// just a quiet record of what you've done, kept on-device.
class MilestonesScreen extends StatelessWidget {
  final String? feature;
  final AccentSwatch Function(AppColorsExt) accentOf;

  const MilestonesScreen({super.key, this.feature, required this.accentOf});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = accentOf(ext);
    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Milestones',
            icon: Symbols.military_tech_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              tooltip: 'Back',
              accent: accent,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: FutureBuilder<({List<Milestone> all, List<Milestone> newlyEarned})>(
              future: MilestonesService.sync(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var items = snap.data!.all;
                if (feature != null) {
                  items = items.where((m) => m.feature == feature).toList();
                }
                final earnedCount = items.where((m) => m.earned).length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                      AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
                  children: [
                    Text(
                      '$earnedCount of ${items.length} reached',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: ext.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final m in items) ...[
                      _MilestoneTile(milestone: m, accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  final Milestone milestone;
  final AccentSwatch accent;
  const _MilestoneTile({required this.milestone, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final earned = milestone.earned;
    return AppCard(
      child: Opacity(
        opacity: earned ? 1 : 0.72,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: earned ? accent.container : ext.surfaceVariant,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(
                milestone.icon,
                size: 22,
                color: earned ? accent.onContainer : ext.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(milestone.title, style: tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    milestone.description,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              earned
                  ? Symbols.check_circle_rounded
                  : Symbols.lock_outline_rounded,
              size: 20,
              color: earned ? ext.mark(accent) : ext.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
