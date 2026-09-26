import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'milestone.dart';
import 'milestones_service.dart';

/// A calm, private shelf of earned + not-yet milestones. Optionally filtered to
/// one [feature] ('steps' | 'sleep'); null shows both. No points, no ranking —
/// just a quiet record of what you've done, kept on-device.
class MilestonesScreen extends StatefulWidget {
  final String? feature;
  final AccentSwatch Function(AppColorsExt) accentOf;

  const MilestonesScreen({super.key, this.feature, required this.accentOf});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  /// Evaluated once per visit, not once per build.
  ///
  /// `MilestonesService.sync()` was called inline in `build`, so every rebuild
  /// the route saw — a theme change, a parent `setState` — handed the
  /// `FutureBuilder` a brand-new future and started the whole evaluation
  /// again: the full catalog, `StepService.getBestDay()`, `getStreakResult()`,
  /// every sleep session, the regularity index, and a persisted write whenever
  /// something is freshly earned.
  ///
  /// It did NOT flash a spinner — `FutureBuilder` keeps the previous snapshot's
  /// data across a future swap — which is precisely why this went unnoticed:
  /// the shelf looked fine and did the work anyway.
  ///
  /// [MilestonesScreen.feature] only filters the awaited list, so changing it
  /// needs no refetch.
  late Future<({List<Milestone> all, List<Milestone> newlyEarned})> _future;

  @override
  void initState() {
    super.initState();
    _future = MilestonesService.sync();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = widget.accentOf(ext);
    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Milestones',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: FutureBuilder<({List<Milestone> all, List<Milestone> newlyEarned})>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var items = snap.data!.all;
                if (widget.feature != null) {
                  items = items.where((m) => m.feature == widget.feature).toList();
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
