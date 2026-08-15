import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import '../../design/app_colors_ext.dart';
import '../../health/insight.dart';
import '../../health/safety_guard.dart';
import 'app_card.dart';
import 'progress_ring.dart';
import 'vitals_theme.dart';

/// Shared kit for the data surfaces: insight cards, KPI cells, week strips, the
/// "Why this?" explainer and the medical disclaimer bar.
///
/// Everything here renders **deterministic** output — statistics computed from
/// the user's own logs. The generative tier and its sparkle hallmark are gone, so
/// nothing in this file claims or implies AI. [WhyThisChip] stays precisely
/// because the output is rule-based: the rule can be shown.
///
/// Design language: tabular figures on every numeral, small-caps overlines, and
/// 1px hairlines on a strict 4pt grid.

/// Tabular figures — the identity cue and the fix for numeral misalignment.
/// Applied to every number rendered by the AI surfaces.
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];
class WeekDotStrip extends StatelessWidget {
  final int filled;
  final int total;
  final AccentSwatch accent;
  const WeekDotStrip(
      {super.key, required this.filled, this.total = 7, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : AppSpacing.xs),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: i < filled ? ext.mark(accent) : ext.outline,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// A ring-backed KPI cell — a [ProgressRing] wrapping a tabular numeral over a
/// small-caps label. Empty state → track-only ring + muted numeral so a zero
/// reads as "nothing yet", not broken.
class KpiCell extends StatelessWidget {
  final double progress;
  final String value;
  final String label;
  final AccentSwatch accent;
  final bool muted;
  const KpiCell({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
    required this.accent,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          progress: progress,
          size: 60,
          stroke: 6,
          accent: accent,
          animate: !MediaQuery.of(context).disableAnimations,
          center: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: kTabular,
                color: muted ? ext.textTertiary : ext.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Shrink-to-fit, never wrap. These sit in a 4-up row, so on a 320pt
        // screen each cell is ~70pt — and unclamped, "REMINDERS" broke across
        // two lines as "REMINDE / RS", which is worse than any amount of
        // shrinking. scaleDown never enlarges, so the wider labels (MEDS,
        // WATER, FOCUS) render exactly as before.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: tt.labelSmall
                ?.copyWith(color: ext.textSecondary, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Resolve a feature's accent + icon.
class InsightVisuals {
  const InsightVisuals._();

  static AccentSwatch accent(BuildContext context, InsightFeature f) {
    final ext = AppColorsExt.of(context);
    switch (f) {
      case InsightFeature.medicine:
        return ext.medicine;
      case InsightFeature.water:
        return ext.water;
      case InsightFeature.focus:
        return ext.focus;
      case InsightFeature.reminders:
        return ext.reminders;
      case InsightFeature.bloodPressure:
        return VitalsColors.bpAccent(ext.isDark);
      case InsightFeature.bloodSugar:
        return VitalsColors.glucoseAccent(ext.isDark);
      case InsightFeature.period:
        return ext.period;
      case InsightFeature.steps:
        return ext.steps;
      case InsightFeature.sleep:
        return ext.sleep;
      case InsightFeature.crossCutting:
        return ext.brand;
    }
  }

  static IconData icon(InsightFeature f) {
    switch (f) {
      case InsightFeature.medicine:
        return Symbols.medication_rounded;
      case InsightFeature.water:
        return Symbols.water_drop_rounded;
      case InsightFeature.focus:
        return Symbols.self_improvement_rounded;
      case InsightFeature.reminders:
        return Symbols.notifications_rounded;
      case InsightFeature.bloodPressure:
        return Symbols.favorite_rounded;
      case InsightFeature.bloodSugar:
        return Symbols.bloodtype_rounded;
      case InsightFeature.period:
        return Symbols.calendar_month_rounded;
      case InsightFeature.steps:
        return Symbols.directions_walk_rounded;
      case InsightFeature.sleep:
        return Symbols.bedtime_rounded;
      case InsightFeature.crossCutting:
        return Symbols.insights_rounded;
    }
  }

  static Color severityColor(AppColorsExt ext, InsightSeverity s) {
    switch (s) {
      case InsightSeverity.good:
        return ext.mark(ext.success);
      case InsightSeverity.info:
        return ext.mark(ext.info);
      case InsightSeverity.attention:
        return ext.mark(ext.warning);
      case InsightSeverity.urgent:
        return ext.mark(ext.error);
    }
  }
}
class WhyThisChip extends StatelessWidget {
  final String why;
  const WhyThisChip({super.key, required this.why});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: AppRadius.brFull,
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColorsExt.of(ctx).surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
          title: Row(children: [
            Icon(Symbols.info_rounded, size: 20, color: ext.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            // Flexible so the title wraps instead of overflowing. Unflexed, an
            // AlertDialog on a narrow screen (or at larger Dynamic Type) had
            // nowhere to put it and painted the 24px overflow stripe over the
            // dialog edge.
            const Flexible(child: Text('Why you\'re seeing this')),
          ]),
          content: Text(why,
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColorsExt.of(ctx).textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Symbols.help_rounded, size: 13, color: ext.textTertiary),
          const SizedBox(width: 4),
          Text('Why this?',
              style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
        ]),
      ),
    );
  }
}

/// Persistent medical-information footnote — a quiet print-footnote: a top
/// hairline + shield + tertiary text. Shown on every screen that interprets
/// health data (period, vitals, weekly recap).
class SafetyDisclaimerBar extends StatelessWidget {
  const SafetyDisclaimerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: ext.outline),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Symbols.shield_rounded, size: 14, color: ext.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(SafetyGuard.disclaimer,
                  style: tt.bodySmall
                      ?.copyWith(color: ext.textTertiary, height: 1.3)),
            ),
          ],
        ),
      ],
    );
  }
}

/// A dismissible proactive nudge banner (frequency-capped by the caller). Shows
/// the single most important insight with a "Why this?" and a dismiss.
class ProactiveNudgeBanner extends StatelessWidget {
  final Insight insight;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;
  const ProactiveNudgeBanner(
      {super.key, required this.insight, required this.onDismiss, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = InsightVisuals.accent(context, insight.feature);
    final sev = InsightVisuals.severityColor(ext, insight.severity);
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.container, borderRadius: AppRadius.brSm),
            child: Icon(InsightVisuals.icon(insight.feature), size: 18, color: accent.onContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(insight.title,
                        style: tt.titleSmall?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: sev, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 2),
                Text(insight.detail,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary, height: 1.35)),
                const SizedBox(height: 4),
                Row(children: [
                  WhyThisChip(why: insight.why),
                  const Spacer(),
                  TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                        foregroundColor: ext.textTertiary,
                        visualDensity: VisualDensity.compact),
                    child: const Text('Dismiss'),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The structured deterministic insight card, in the "Briefing" grammar:
/// a small-caps overline (feature glyph + feature word + severity word + dot),
/// an editorial title, the metric set large as a tabular-figure hero on its own
/// line, the detail, a footer hairline, then engine badge + why-this + action.
/// The glanceable "one big thing" surface.
class InsightCard extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  const InsightCard({super.key, required this.insight, this.onAction, this.onTap});

  static String _featureName(InsightFeature f) {
    switch (f) {
      case InsightFeature.medicine:
        return 'Medicine';
      case InsightFeature.water:
        return 'Water';
      case InsightFeature.focus:
        return 'Focus';
      case InsightFeature.reminders:
        return 'Reminders';
      case InsightFeature.bloodPressure:
        return 'Blood pressure';
      case InsightFeature.bloodSugar:
        return 'Blood sugar';
      case InsightFeature.period:
        return 'Cycle';
      case InsightFeature.steps:
        return 'Steps';
      case InsightFeature.sleep:
        return 'Sleep';
      case InsightFeature.crossCutting:
        return 'Across features';
    }
  }

  static String _severityWord(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.good:
        return 'On track';
      case InsightSeverity.info:
        return 'Note';
      case InsightSeverity.attention:
        return 'Needs attention';
      case InsightSeverity.urgent:
        return 'Act now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = InsightVisuals.accent(context, insight.feature);
    final sev = InsightVisuals.severityColor(ext, insight.severity);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — OVERLINE: feature glyph + feature · severity + severity dot.
          Row(
            children: [
              Icon(InsightVisuals.icon(insight.feature),
                  size: 14, color: ext.mark(accent)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_featureName(insight.feature).toUpperCase()} · ${_severityWord(insight.severity).toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall
                      ?.copyWith(color: ext.textTertiary, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              // Severity dot (colour + shape redundancy; never colour alone).
              Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: sev, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Row 2 — editorial title.
          Text(insight.title,
              style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
          // Row 3 — METRIC HERO on its own left-aligned line.
          if (insight.metric != null) ...[
            const SizedBox(height: 6),
            Text(insight.metric!,
                style: tt.headlineMedium?.copyWith(
                    color: sev,
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabular,
                    letterSpacing: -0.5)),
          ],
          const SizedBox(height: 6),
          Text(insight.detail,
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: ext.outline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              WhyThisChip(why: insight.why),
              const Spacer(),
              // actionLabel is engine-generated, so its length is unbounded.
              // Flexible + ellipsis stops it overflowing the card at 320px.
              if (insight.actionLabel != null && onAction != null)
                Flexible(
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                        foregroundColor: ext.mark(accent),
                        visualDensity: VisualDensity.compact),
                    child: Text(
                      insight.actionLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
