import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/walking_trends.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/step_daily_data.dart';
import '../services/step_service.dart';
import '../services/walking_trend_service.dart';
import '../utils/walking_trend_words.dart';

/// "Up 12% on your 90-day average": the last four weeks of walking against the
/// last ninety days, and — when it is not up — what would turn it. Renders
/// nothing until there is enough walking on record to say.
class WalkingTrendCard extends StatefulWidget {
  const WalkingTrendCard({super.key, this.load = WalkingTrendService.load});

  /// Where the trend comes from; a test counts the reads.
  @visibleForTesting
  final Future<WalkingTrend?> Function() load;

  @override
  State<WalkingTrendCard> createState() => _WalkingTrendCardState();
}

class _WalkingTrendCardState extends State<WalkingTrendCard> {
  WalkingTrend? _trend;

  /// What the past days looked like when the trend was last read. The Steps
  /// screen rebuilds on every step the sensor counts; only a change to a day
  /// that is over is worth a trip to the database.
  int? _seen;
  int _generation = 0;
  ValueListenable<Map<String, StepDailyData>>? _daily;

  @override
  void initState() {
    super.initState();
    _daily = StepService.listenToDailyData()?..addListener(_onDays);
    _seen = _fingerprint();
    unawaited(_load());
  }

  @override
  void dispose() {
    _daily?.removeListener(_onDays);
    super.dispose();
  }

  /// The complete days the dashboard holds, as one number that changes when any
  /// of them does, and when the day rolls over and the window moves along.
  int _fingerprint() {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    return Object.hashAll([
      for (final d in StepService.getDataForRange(
          DateTime(today.year, today.month, today.day - 35),
          DateTime(today.year, today.month, today.day - 1)))
        Object.hash(d.date, d.effectiveSteps),
    ]);
  }

  void _onDays() {
    final now = _fingerprint();
    if (now == _seen) return;
    _seen = now;
    unawaited(_load());
  }

  Future<void> _load() async {
    final mine = ++_generation;
    final trend = await widget.load();
    // A newer read is on its way, or the screen has gone.
    if (!mounted || mine != _generation) return;
    setState(() => _trend = trend);
  }

  @override
  Widget build(BuildContext context) {
    final t = _trend;
    if (t == null) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final plan = t.plan;
    final icon = switch (t.direction) {
      WalkingDirection.up => Symbols.trending_up_rounded,
      WalkingDirection.down => Symbols.trending_down_rounded,
      WalkingDirection.steady => Symbols.trending_flat_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ext.steps.container,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(icon, size: 22, color: ext.steps.onContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppEyebrow('WALKING TREND'),
                      const SizedBox(height: 2),
                      Text(t.headline, style: tt.titleMedium),
                      const SizedBox(height: 2),
                      Text(t.detail,
                          style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            if (plan != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(plan, style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text('Whole days only. Rest and unwell days are left out.',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
          ],
        ),
      ),
    );
  }
}
